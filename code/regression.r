library(stargazer)
library(arrow)

add_color = function(plot){
  plot + 
  scale_color_manual(values = c("Control" = "#2967b7", "AI-as-usual" = "#c01515", "AI-optimized" = "#4f9108")) +
  scale_fill_manual(values = c("Control" = "#2967b7", "AI-as-usual" = "#c01515", "AI-optimized" = "#4f9108"))
}

data = arrow::read_parquet("data/long_texts_with_ratings.parquet") 

data = data %>% 
  select(id:answer.clarity, flesch_kincaid, avg_words_per_sentence, n_words, condition, stage)

# show non-unique records
data %>% 
  group_by(id,stage) %>% 
  filter(n() > 1) %>% 
  select(id, stage, condition) %>% 
  distinct()

data %>% filter(id == "R_1iU8Naqdssdja93")

data = data %>% unique()

data = data %>%
  mutate(
    answer.clarity = 8-answer.clarity,
    avg_words_per_sentence = avg_words_per_sentence * -1,
    n_words = n_words * -1
    ) %>%
  rename(
    `Clarity` = answer.clarity, 
    `WPS` = avg_words_per_sentence,
    `Readability Score` = flesch_kincaid,
    `Word Count` = n_words
  ) %>%
  pivot_longer(`Readability Score`:`Word Count`, names_to = "metric", values_to = "value") %>%
  mutate(condition = case_match(condition, 
                                1 ~ "Control",
                                2 ~ "AI-as-usual",
                                3 ~ "AI-optimized")) %>%
  mutate(stage = case_match(stage, 
                            "pretest_rewritten" ~ "Pretest",
                            "practice_rewritten" ~ "Practice",
                            "test_rewritten" ~ "Test")) %>%
  mutate(stage = factor(stage, levels = c("Pretest", "Practice", "Test")))

read_parquet("data/clean.parquet") %>% count(nochange,condition)

data = data %>% 
  left_join(read_parquet("data/clean.parquet") %>% select(id, nochange, sample))

data %>% 
  # make control the reference group
  mutate(condition = relevel(factor(condition), ref = "Control")) %>%
  group_by(metric, stage) %>% 
  mutate(value = scale(value)) %>%
  # add the pretest values to the right of practice and test to
  nest() %>% 
  mutate(lm = map(data, ~lm(value ~ condition, data = .x))) %>% 
  pull(lm) %>% 
  stargazer(star.cutoffs = c(0.05, 0.01, 0.001), type = "text")

lm_results = data %>% 
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

lm_results

get_beta_dif = function(lm){
tidy = lm %>% broom::tidy() %>% select(term, estimate)
tidy %>% filter(term == "conditionAI-optimized") %>% pull(estimate) - tidy %>% filter(term == "conditionAI-as-usual") %>% pull(estimate)
}
get_wald_p = function(lm) {
  (car::linearHypothesis(lm, "conditionAI-as-usual = conditionAI-optimized"))$`Pr(>F)`[2]
}

lm_results = lm_results %>% mutate(
  wald_p = map_dbl(lm, get_wald_p),
  beta_dif = map_dbl(lm, get_beta_dif)
)

lm_results %>%
  pull(lm) %>%
  stargazer(
    star.cutoffs = c(0.05, 0.01, 0.001), 
    type = "text", 
    column.labels = lm_results$metric,
    add.lines = list(c("Wald test", paste0("p = ", round(lm_results$wald_p, 3))),
                     c("Beta difference", round(lm_results$beta_dif, 3))),
    dep.var.caption  = "Practice and test scores regressed on condition and pretest scores",
    omit.stat = c("adj.rsq", "ser"),   # Example of omitting certain statistics
          # omit.table.layout = "d",           # Omits dependent variable row
    dep.var.labels.include = FALSE)



lm_results_noz = data %>% 
  select(id, condition, stage, metric, value) %>%
  # make control the reference group
  mutate(condition = relevel(factor(condition), ref = "Control")) %>%
  pivot_wider(names_from = stage, values_from = value) %>% 
  pivot_longer(Practice:Test, names_to = "stage", values_to = "value") %>% 
  group_by(stage,metric) %>%
  nest() %>%
  arrange(stage) %>%
  mutate(lm = map(data, ~lm(value ~ condition + Pretest, data = .x)))

lm_to_tibble = function(lm) {
  lm %>% emmeans::emmeans(., "condition") %>% summary() %>% as_tibble()
}

emmeans_base = data %>% 
  filter(stage == "Pretest") %>%
  group_by(metric) %>%
  nest() %>%
  mutate(lm = map(data, ~lm(value ~ 1, data = .x))) %>%
  mutate(emmeans = map(lm, lm_to_tibble)) %>%
  unnest(emmeans) %>%
  select(-lm)

emmeans_base = data %>% 
  filter(stage == "Pretest") %>%
  group_by(metric,stage) %>%
  summarise(emmean = mean(value), SE = sd(value)/sqrt(n())) %>% 
  expand_grid(condition = c("Control", "AI-as-usual", "AI-optimized"))

emmeans_post= lm_results_noz %>%  
  mutate(emmeans = map(lm, lm_to_tibble)) %>% 
  unnest(emmeans) %>%
  select(-lm)

emmeans = bind_rows(emmeans_base, emmeans_post)


(emmeans %>% 
  mutate(stage = factor(stage, levels = c("Pretest", "Practice", "Test"))) %>%
  ggplot(aes(stage, emmean, color = condition)) +
  geom_point(
    # position = position_dodge(width = .3)
    ) +
  geom_line(data = data, aes(group = id, y = value),
  alpha = .1, 
  # position = position_dodge(width = .3)
  ) +
  geom_line(aes(group = condition)) +
  geom_errorbar(aes(ymin = emmean-SE, ymax = emmean + SE), width = .1,
  # position = position_dodge(width = .3)
  ) +
  facet_grid(metric~condition, scales = "free") +
  labs(
       x = NULL,
       color = NULL,
       y = "Estimated marginal mean") +
  theme(legend.position = "bottom") ) %>% 
  add_color()
  ggsave("plots/emmeans_noz.png", width = 4, height = 8, dpi = 300)
