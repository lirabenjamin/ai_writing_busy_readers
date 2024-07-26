  library(gt)
  library(mongolite)
  library(arrow)
  library(dotenv)

  # dowload chatbot data
  load_dot_env()
  # Get the MongoDB URI from the environment variable
  mongo_uri <- Sys.getenv("MONGODB_URI")
  mongo_conn <- mongo(db = "email-rewriter", collection = "responses", url = mongo_uri)
  rated_data <- mongo_conn$find() %>% as_tibble()

  # read json for emails
  ids = read_parquet("data/texts_to_rate.parquet") %>% as_tibble()

  # read_computer rated
  computer_rated = read_parquet("data/long_texts_with_ratings_cleaned.parquet") %>% as_tibble()

  # merge
  rated_data = rated_data %>% 
    select(-ra_name, -timestamp) %>%
    left_join(ids %>% select(-text), by = c("email_id" = "text_id")) %>% 
    left_join(computer_rated) %>% 
    mutate(across(starts_with("q"), as.numeric)) %>%
    rowwise() %>%
    mutate(manual_6 = mean(c(q1, q2,q3, q4, q5, q6)))

  rated_data %>% 
    bind_rows(rated_data  %>% mutate(stage = "all"))  %>%
    ggplot(aes(x = manual_6, y = six_principles)) +
    facet_wrap(~stage, nrow = 1, scales = "free") +
    geom_jitter()+ 
    # add identity line
    geom_abline(intercept = 0, slope = 1, color = "red", alpha = .4) +
    ggpubr::stat_cor(method = "pearson") +
    geom_smooth(method = "lm")+
    scale_x_continuous(breaks = 0:10) +
    scale_y_continuous(breaks = 0:10) +
    labs(x = "Manual rating", y = "Computer rating")
ggsave("figures/manual_vs_computer_rating.png", width = 7, height = 3)

# individual ratings
rated_data %>% 
  select(id, stage, q1:q6 , less_is_more:easy_responding) %>% 
  pivot_longer(cols = c(q1:easy_responding), names_to = "question", values_to = "rating")  %>% 
  mutate(rater = ifelse(str_detect(question, "q"), "manual", "computer")) %>%
  mutate(question = case_match(question,
  "q1" ~ "less_is_more",
  "q2" ~ "easy_reading",
  "q3" ~ "easy_navigation",
  "q4" ~ "formatting",
  "q5" ~ "value_emphasis",
  "q6" ~ "easy_responding",
  # keep the others as is
  .default  = question
  ))  %>% 
  mutate(question = fct_inorder(question)) %>%
  pivot_wider(names_from = rater, values_from = rating) %>%
  ggplot(aes(x = manual, y = computer)) +
  geom_jitter() +
  geom_abline(intercept = 0, slope = 1, color = "red", alpha = .4) +
  ggpubr::stat_cor(method = "pearson") +
  geom_smooth(method = "lm")+
  scale_x_continuous(breaks = 0:10) +
  scale_y_continuous(breaks = 0:10) +
  labs(x = "Manual rating", y = "Computer rating") +
  facet_wrap(~question, scales = "free")
ggsave("figures/manual_vs_computer_rating_individual.png", width = 7, height = 4)
