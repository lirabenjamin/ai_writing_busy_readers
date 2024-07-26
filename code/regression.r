library(stargazer)

data = arrow::read_parquet("data/long_texts_with_ratings_cleaned.parquet")

data = data %>%
  pivot_longer(clarity:five_principles, names_to = "metric", values_to = "value")

data %>%
  group_by(metric, stage) %>% 
  mutate(value = scale(value)) %>%
  # add the pretest values to the right of practice and test to
  nest() %>% 
  mutate(lm = map(data, ~lm(value ~ condition, data = .x))) %>% 
  pull(lm) %>% 
  stargazer(star.cutoffs = c(0.05, 0.01, 0.001), type = "text")

data = data  %>% 
  left_join(read_parquet("data/clean.parquet") %>% select(id,sample))

lm_results = data %>% 
  select(id, condition, stage, metric, value, sample) %>%
  factor_condition() %>%
  factor_stage() %>%
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

data %>% 
  pivot_wider(names_from = metric, values_from = value) %>% 
  bind_rows(
    data %>% 
      pivot_wider(names_from = metric, values_from = value) %>% 
      mutate(stage = "all")
      ) %>% 
      group_by(stage) %>%
      select(clarity:five_principles) %>%
      nest() %>%
      mutate(
        cors = map(data, corrr::correlate),
        cors = map(cors, corrr::stretch)
        ) %>% 
        unnest(cors) %>% 
        mutate(x = fct_inorder(x), y = fct_inorder(y)) %>%
        filter(x != y) %>%
        ggplot(aes(x,y, fill = r)) +
        geom_tile() +
        geom_text(aes(label = Ben::numformat(r)), color = "white") +
        facet_wrap(~stage) +
        scale_fill_viridis_c() +
        theme(
          legend.position = "none",
          axis.text.x = element_text(angle = 45, hjust = 1))+ 
        labs(
          x = NULL,
          y = NULL,
          fill = "Correlation"
        )
ggsave("plots/correlation_matrix.png", width = 8, height = 8, dpi = 300)

lm_results$wald_p
lm_results$beta_dif

lm1 = lm_results %>% filter(stage == "Practice")
lm2 = lm_results %>% filter(stage == "Test") 

st1 = lm1 %>%
  pull(lm) %>%
  stargazer(
    star.cutoffs = c(0.05, 0.01, 0.001), 
    column.labels = lm1$metric,
    add.lines = list(c("Wald test", paste0("p = ", round(lm1$wald_p, 3))),
                     c("Beta difference", round(lm1$beta_dif, 3))),
    dep.var.caption  = "Practice and test scores regressed on condition and pretest scores",
    omit.stat = c("adj.rsq", "ser"),   # Example of omitting certain statistics
    #       # omit.table.layout = "d",           # Omits dependent variable row
    dep.var.labels.include = FALSE,
    out = "tables/lm_results1.tex"
    )

st2 = lm2 %>%
  pull(lm) %>%
  stargazer(
    star.cutoffs = c(0.05, 0.01, 0.001), 
    column.labels = lm2$metric,
    add.lines = list(c("Wald test", paste0("p = ", round(lm2$wald_p, 3))),
                     c("Beta difference", round(lm2$beta_dif, 3))),
    dep.var.caption  = "Practice and test scores regressed on condition and pretest scores",
    omit.stat = c("adj.rsq", "ser"),   # Example of omitting certain statistics
    #       # omit.table.layout = "d",           # Omits dependent variable row
    dep.var.labels.include = FALSE
    # save
    # out = "tables/lm_results2.tex"
    )

table = starpolishr::star_panel(st1, st2, panel.names = c("Practice", "Test"), same.summary.stats = F)

cat(table, file = "tables/lm_results.tex",sep = "\n")
cat(st2, file = "tables/lm_results2.tex",sep = "\n")

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
