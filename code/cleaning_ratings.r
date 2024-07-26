library(arrow)

data = arrow::read_parquet("data/long_texts_with_ratings.parquet") 

data = data %>% 
  select(
    id, condition, stage,
    clarity = answer.clarity, 
    answer.less_is_more:answer.easy_responding,
    flesch_kincaid, avg_words_per_sentence, n_words) %>% 
    # remove answer.
    rename_all(~str_remove(., "answer."))

data = data %>%
  mutate(
    clarity = 8-clarity,
    wps = avg_words_per_sentence * -1,
    wc = n_words * -1
    ) %>%
    select(-n_words, -avg_words_per_sentence) %>% 
    rowwise() %>%
    mutate(
      six_principles = mean(c(less_is_more, easy_reading, easy_navigation, formatting, value_emphasis, easy_responding)),
      five_principles = mean(c(less_is_more, easy_reading, easy_navigation, formatting, easy_responding)),
      clarity = ((clarity-1)/6)*10
      )


data %>% 
  write_parquet("data/long_texts_with_ratings_cleaned.parquet")
