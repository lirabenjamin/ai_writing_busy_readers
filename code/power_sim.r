library(stargazer)
library(arrow)

add_color = function(plot){
  plot + 
  scale_color_manual(values = c("Control" = "#2967b7", "AI-as-usual" = "#c01515", "AI-optimized" = "#4f9108")) +
  scale_fill_manual(values = c("Control" = "#2967b7", "AI-as-usual" = "#c01515", "AI-optimized" = "#4f9108"))
}


data = arrow::read_parquet("data/long_texts_with_ratings_cleaned.parquet")

data = data %>%
  pivot_longer(clarity:five_principles, names_to = "metric", values_to = "value") %>%
  mutate(condition = case_match(condition, 
                                1 ~ "Control",
                                2 ~ "AI-as-usual",
                                3 ~ "AI-optimized")) %>%
  mutate(stage = case_match(stage, 
                            "pretest_rewritten" ~ "Pretest",
                            "practice_rewritten" ~ "Practice",
                            "test_rewritten" ~ "Test")) %>%
  mutate(stage = factor(stage, levels = c("Pretest", "Practice", "Test")))

clean = arrow::read_parquet("data/clean.parquet")
data = clean %>% select(id,sample) %>% 
  right_join(data)

lm_results = data %>% 
  filter(metric == "five_principles" & sample == 2) %>%
  select(id, condition, stage, metric, value, sample) %>%
  # make control the reference group
  mutate(condition = relevel(factor(condition), ref = "Control")) %>%
  pivot_wider(names_from = stage, values_from = value) %>% 
  pivot_longer(Practice:Test, names_to = "stage", values_to = "value") %>% 
  group_by(stage,metric) %>%
  mutate(
    value = scale(value),
    Pretest = scale(Pretest, center = TRUE, scale = TRUE)
    ) %>%
  nest() %>%
  arrange(stage) %>%
  mutate(lm = map(data, ~lm(value ~ condition + Pretest + sample, data = .x)))


params = lm_results %>% 
  mutate(
    pretest_mean = map_dbl(data, ~mean(.x$Pretest, na.rm= T)),
    pretest_sd = map_dbl(data, ~sd(.x$Pretest, na.rm= T)),
    beta_pretest = map_dbl(lm, ~coef(.x)["Pretest"]),
    beta_AI_as_usual = map_dbl(lm, ~coef(.x)["conditionAI-as-usual"]),
    beta_AI_optimized = map_dbl(lm, ~coef(.x)["conditionAI-optimized"]),
    residual_variance = map_dbl(lm, ~summary(.x)$sigma), 
  )  %>% 
  select(metric,stage, pretest_mean, pretest_sd, beta_pretest, beta_AI_as_usual, beta_AI_optimized, residual_variance) 

sim_data = function(n, pretest_mean, pretest_sd, beta_pretest, beta_AI_as_usual, beta_AI_optimized, residual_variance){
  pretest = rnorm(n, pretest_mean, pretest_sd)
  condition = sample(c("AI-as-usual", "AI-optimized", "Control"), n, replace = T)
  condition_effect = case_when(
    condition == "AI-as-usual" ~ beta_AI_as_usual,
    condition == "AI-optimized" ~ beta_AI_optimized,
    TRUE ~ 0
  )
  score = condition_effect + beta_pretest * pretest + rnorm(n, 0, residual_variance)
  data.frame(condition, pretest, score)
}

sims = params %>% 
  filter(metric %in% c("six_principles","clarity","five_principles")) %>%
  expand_grid(n = c(30,60,90,150), sim = 1:500) %>% 
  mutate(sim_data = pmap(list(n, pretest_mean, pretest_sd, beta_pretest, beta_AI_as_usual, beta_AI_optimized, residual_variance), sim_data)) %>% 
  # make control the reference group
  mutate(sim_data = map(sim_data, ~mutate(.x, condition = relevel(factor(condition), ref = "Control"))) ) %>%
  mutate(lm = map(sim_data, ~lm(score ~ condition + pretest, data = .x))) 

sims

power = sims  %>% 
  mutate(tidy = map(lm, broom::tidy)) %>%
  unnest(tidy) %>% 
  group_by(n, metric, stage, term) %>%
  filter(term %in% c("conditionAI-as-usual", "conditionAI-optimized")) %>%
  summarise(power = mean(p.value < .05)) 

power %>% 
  # what is the first place where power > .8
  filter(power>.8) %>% 
  arrange(n) %>% 
  slice(1) %>% 


power %>% 
  filter(stage == "Test") %>%
  mutate(condition = case_match(term, 
                                "conditionAI-as-usual" ~ "AI-as-usual",
                                "conditionAI-optimized" ~ "AI-optimized")) %>%
  ungroup() %>% 
  ggplot(aes(n, power, color = condition)) +
  geom_line() +
  facet_grid(stage~metric, scales = "free_x") +
  # scale_x_continuous(breaks = unique(sims$n)) +
  scale_x_continuous(breaks = c(30,60,90,150)) +
  coord_cartesian(xlim = c(30,150)) +
  geom_vline(xintercept = 900, linetype = 2) +
  geom_point()+
  geom_hline(yintercept = c(.8,.9), linetype = 2) +
  labs(
    x = "Sample Size",
    y = "Power",
    color = NULL
  )
ggsave("plots/power_sim.png", width = 12, height = 4, dpi = 300)
ggsave("plots/power_sim2.png", width = 7, height = 3, dpi = 300)
ggsave("plots/power_sim3.png", width = 7, height = 3, dpi = 300)
