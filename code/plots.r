library(arrow)
data = arrow::read_parquet("data/long_texts_with_ratings.parquet") 

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
  pivot_longer(`Readability Score`:WPS, names_to = "metric", values_to = "value") %>%
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

  
(data %>%
  ggplot(aes(x = stage, y = value, color = condition)) +
  geom_point(aes(shape = nochange), alpha = .3) +
  geom_line(aes(group = id), alpha = .3) +
  # stat_summary(fun = mean, geom = "point", shape = 95, size = 3) +
  stat_summary(fun = mean, geom = "line", shape = 95, size = 1, group = 1) +
  # add error bars to means
  stat_summary(fun.data = mean_se, geom = "errorbar", width = .1) +
  facet_grid(metric~condition, scales = "free") +
  labs(title = "Ratings of text quality by stage",
       x = "Stage",
       y = "Rating") +
  theme(legend.position = "none")) %>%
  add_color()
ggsave("plots/ratings_by_stage2.png", width = 8, height = 6, dpi = 300)

(data %>%
  mutate(sample = ifelse(sample == 2, "Sample 2", "Sample 1")) %>%
  rbind(data %>% mutate(sample = "All")) %>%
  group_by(condition, metric, stage,sample) %>%
  summarise(mean = mean(value),
            se = sd(value)/sqrt(n())) %>%
  ggplot(aes(x = stage, y = mean, color = condition)) +
  # geom_point(alpha = .3) +
  geom_line(aes(group = condition))+
  geom_errorbar(aes(ymin = mean-se, ymax = mean+se), width = .1) +
  facet_grid(metric~sample, scales = "free") +
  labs(
       x = NULL,
       color = NULL,
       y = "Score (higher is better)") +
  theme(legend.position = "bottom")) %>% 
  add_color()
ggsave("plots/ratings_by_stage_means2.png", width = 6, height = 6, dpi = 300)

agg2 = data %>%
  filter(condition == "AI-as-usual") %>%
  group_by(metric, stage, nochange,condition) %>%
  summarise(mean = mean(value),
            se = sd(value)/sqrt(n()))


# Aggregate data for the learning phase
learn_agg <- data %>% 
  filter(condition == "Control" & stage != "Test") %>%
  select(id,stage, metric, value, condition) %>%
  pivot_wider(names_from = stage, values_from = value) %>% 
  mutate(hasna = is.na(Practice) | is.na(Pretest)) %>% 
  filter(!hasna) %>% 
  pivot_longer(Pretest:Practice, names_to = "stage", values_to = "value") %>%
  group_by(stage, metric, condition) %>%
  summarise(mean = mean(value),
            se = sd(value) / sqrt(n())
            value = mean(value)
            )

paired_data = data %>% 
  filter(condition == "Control" & stage != "Test") %>%
  select(id,stage, metric, value, condition) %>%
  pivot_wider(names_from = stage, values_from = value) %>% 
  mutate(hasna = is.na(Practice) | is.na(Pretest)) %>% 
  filter(!hasna) %>% 
  pivot_longer(Pretest:Practice, names_to = "stage", values_to = "value") %>%
  # make pretest the reference group
  mutate(stage = relevel(factor(stage), ref = "Pretest")) %>%
  group_by(metric)
  
t = paired_data %>% rstatix::t_test(value ~ stage, paired = TRUE, p.adjust.method = "bonferroni")
d = paired_data %>% rstatix::cohens_d(value ~ stage)
mean_diff = paired_data %>% pivot_wider(names_from = stage, values_from = value) %>% 
  mutate(diff = Practice - Pretest) %>% 
  summarise(mean = mean(diff), se = sd(diff)/sqrt(n()), n = n())
diff_data = left_join(t,d) %>% left_join(mean_diff) %>% mutate(d = glue::glue("{Ben::numformat(effsize)}{Ben::codeps(p)}"), condition = "Control")


# Create the plot
plot <- data %>% 
  filter(condition == "Control" & stage != "Test") %>%
  ggplot(aes(x = stage, y = value, color = condition)) +
  facet_wrap(. ~ metric, scales = "free") +
  geom_line(aes(group = id), alpha = .3) +
  geom_line(data = learn_agg, aes(x = stage, y = mean, color = condition, group = condition),linewidth = 2) +
  geom_errorbar(data = learn_agg, aes(x = stage, ymin = mean - se, ymax = mean + se, color = condition, group = condition), width  = .3) +
  geom_text(data = diff_data, aes(x = 2, y = Inf, label = d), hjust = 0, vjust = 1) +
  labs(
    x = NULL,
    y = "Score (Higher = Better)",
  ) +
  theme(legend.position = "none")

# Apply the add_color function and print the plot
plot <- add_color(plot)
print(plot)
ggsave("plots/learning_phase.png", width = 4, height = 3, dpi = 300)



(data %>% 
  filter(condition == "AI-as-usual") %>%
ggplot(aes(x = stage, y = value, color = condition, lty = nochange)) +
  # geom_point(aes(shape = nochange), alpha = .3) +
  # geom_line(aes(group = id), alpha = .3) +
  geom_line(data = agg2, aes(x = stage, y = mean, color = condition, group = nochange)) +
  geom_errorbar(data = agg2, aes(x = stage, y = mean, ymin = mean-se, ymax = mean+se, color = condition), width = .1) +
  facet_grid(metric~condition, scales = "free") +
  labs(title = "Ratings of text quality by stage",
       x = "Stage",
       y = "Rating",
       color = "Just used the AI output?") +
  theme(legend.position = "bottom")) %>% 
  add_color()
ggsave("plots/ratings_by_stage_nochange2.png", width = 4, height = 8, dpi = 300)


