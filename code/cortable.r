clean = arrow::read_parquet("data/clean.parquet")
long = arrow::read_parquet("data/long_texts_with_ratings.parquet")
rename_condition = function(data){
  data %>% 
    mutate(condition = case_match(condition, 
                                  1 ~ "Control",
                                  2 ~ "AI-as-usual",
                                  3 ~ "AI-optimized")) %>% 
    # make control the reference group
    mutate(condition = relevel(factor(condition), ref = "Control"))
}

long = long %>%
  unique() %>%
  select(id, stage, flesch_kincaid:avg_words_per_sentence) %>% 
  mutate(
    n_words = n_words * -1,
    avg_words_per_sentence = avg_words_per_sentence * -1,
    answer.clarity = 8 - answer.clarity,
    ) %>%
  pivot_wider(names_from = stage, values_from = flesch_kincaid:avg_words_per_sentence, names_glue = "{stage}_{.value}")

clean = clean %>% 
  left_join(long) %>%
  select(
    condition, year_of_birth, gender, ethnicity_1:ethnicity_8, primary_language, education_level, writing_importance:writing_aireliance,
    # times
    # ratings
    preference = `3_practice_preference`,
    ai_helpfulness, 
    practice_effort = Q120,
    test_effort = Q121,
    pretest_rewritten_flesch_kincaid:test_rewritten_avg_words_per_sentence
    ) %>% 
    # no variation in primary language
    select(-primary_language) %>%
    select(-wrt) %>%
    mutate(white = case_when(
      ethnicity_1 == "White" & is.na(ethnicity_2) & is.na(ethnicity_3) & is.na(ethnicity_4) & is.na(ethnicity_5) & is.na(ethnicity_6) & is.na(ethnicity_7) & is.na(ethnicity_8) ~ 1,
      T ~ 0
      )) %>% 
      select(-matches("ethnicity")) %>% 
      mutate(
        education_level = as.numeric(education_level),
        writing_class = ifelse(writing_class == "Yes", 1, 0),
        preference_ai = ifelse(preference == "Your Email", 0, 1),

        ) %>% 
        select(-preference) %>% 
        rename_condition() %>%
        fastDummies::dummy_cols(select_columns = c("condition","gender", "primary_language"), remove_selected_columns = TRUE) %>% 
        select(
          starts_with("condition"),
          pretest_rewritten_flesch_kincaid:test_rewritten_avg_words_per_sentence,
          starts_with("effort"),
          starts_with("ai_helpfulness"),
          starts_with("writing"),
          everything()
          ) 

clean %>% select(matches("Page"))
# diferences in time between samples
clean %>% select(condition, sample, time = `3_time_practice_c2_Page Submit`) %>% 
  filter(condition == 2) %>%
  ggplot(aes(sample, time))+ stat_summary(fun = mean, geom = "bar") + geom_point() +
  ggpubr::stat_compare_means() 
  # rstatix::cohens_d(time ~ sample, paired = FALSE, var.equal = TRUE)

clean %>%
        Ben::harcor() %>% 
   mutate_all(~ifelse(. == "  NaNNA", NA, .)) %>%
        gt::gt() %>% 
        gt::fmt_missing(columns = everything()) %>%
        gt::gtsave("tables/cors.tex")


clean %>%
        Ben::harcor() %>% 
        as_tibble() %>%
        # remove any NaNNA values
        mutate_all(~ifelse(. == "  NaNNA", NA, .)) %>%
        gt::gt() %>% 
        # center all cols except the first
        gt::cols_align(align = "center", columns = 2:35) %>%
        gt::fmt_missing(columns = everything()) %>%
        gt::gtsave("tables/cors.html")


clean  %>% count(primary_language) 
