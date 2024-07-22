data = arrow::read_parquet("data/long_texts_with_ratings.parquet") 

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


overall = data %>% 
  select(id, metric, value,stage) %>% 
  pivot_wider(names_from = metric, values_from = value) %>% 
  unnest() %>% 
  select_if(is.numeric) %>% 
  Ben::harcor()

pre = data %>% 
  filter(stage == "Pretest") %>%
  select(id, metric, value,stage) %>% 
  pivot_wider(names_from = metric, values_from = value) %>% 
  unnest() %>% 
  select_if(is.numeric) %>% 
  Ben::harcor()

practice = data %>% 
  filter(stage == "Practice") %>%
  select(id, metric, value,stage) %>% 
  pivot_wider(names_from = metric, values_from = value) %>% 
  unnest() %>% 
  select_if(is.numeric) %>% 
  Ben::harcor()

test = data %>% 
  filter(stage == "Test") %>%
  select(id, metric, value,stage) %>% 
  pivot_wider(names_from = metric, values_from = value) %>% 
  unnest() %>% 
  select_if(is.numeric) %>% 
  Ben::harcor()

overall %>% 
  cbind(pre %>% select(-1)) %>% 
  cbind(practice %>% select(-1)) %>% 
  cbind(test %>% select(-1)) %>% 
  repair_names() %>%
  gt::gt() %>% 
  gt::gtsave("tables/correlations.tex")

overall %>% 
  rbind(pre ) %>% 
  rbind(practice ) %>% 
  rbind(test) %>% 
  gt::gt() %>% 
  gt::gtsave("tables/correlations.tex")