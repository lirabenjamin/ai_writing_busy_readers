data = arrow::read_parquet("data/long_texts_with_ratings.parquet")
data = data %>% 
  rename(
    less_is_more = answer.less_is_more,
    easy_reading = answer.easy_reading,
    easy_navigation = answer.easy_navigation,
    formatting = answer.formatting,
    value_emphasis = answer.value_emphasis,
    easy_responding = answer.easy_responding
    )

data %>% 
  unique() %>% 
  pivot_longer(less_is_more:easy_responding, names_to = "metric", values_to = "score") %>% 
  unique() %>% 
  select(id, condition, stage, metric, score) %>%
  group_by(id, condition, stage,metric) %>%
  filter(n() > 1) %>% 
  arrange(metric)

# average if there are multiple ratings
data = data %>% 
  unique() %>% 
  pivot_longer(less_is_more:easy_responding, names_to = "metric", values_to = "score") %>% 
  unique() %>% 
  select(id, condition, stage, metric, score) %>%
  group_by(id, condition, stage,metric) %>%
  summarise(score = mean(score)) %>% 
  ungroup() %>%
  group_by(stage) %>% 
  pivot_wider(names_from = metric, values_from = score)  %>%
  select(1:3, less_is_more, easy_reading, easy_navigation, formatting, value_emphasis, easy_responding)  %>% 
  ungroup()
  
data %>%   
  group_by(stage) %>%
  select(-condition,-id) %>%
  nest() %>% 
  ungroup() %>%
  add_row(stage = "all", data = list(data %>% select(-id, -condition, -stage))) %>%
  mutate(stage = factor(stage, levels = c("pretest_rewritten", "practice_rewritten", "test_rewritten", "all"))) %>%
  mutate(cor = map(data,
   ~corrr::correlate(.x)  %>% corrr::stretch() %>% mutate(x = fct_inorder(x), y = fct_inorder(y))
   )
   ) %>%
  unnest(cor) %>% 
  filter(x != y) %>%
  ggplot(aes(x = x, y = y, fill = r)) +
  geom_tile()+ 
  facet_wrap(~stage, scales = "free", ncol = 4)+ 
  scale_fill_viridis_c()+
  labs(x = NULL, y = NULL)+
  theme(
    legend.position = "none",
    axis.text.x = element_text(angle = 45, hjust = 1)
    )+
    geom_text(aes(label = Ben::numformat(r,2)), color = "white")
ggsave("plots/correlation_matrix.png", width = 14, height = 4) 
# parallel analysis
library(psych)

# histogram
data %>% 
  select(-id, -condition, -stage) %>% 
  gather() %>% 
  ggplot(aes(value))+
  geom_histogram(bins = 30)+
  scale_x_continuous(breaks = seq(0,10,1))+
  facet_wrap(~key, scales = "free", nrow = 1)+ 
  labs(x = NULL, y = NULL)
ggsave("plots/histograms.png", width = 10, height = 2)

fa.parallel(data %>% select(-id, -condition, -stage), fa = "both", n.iter = 1000)

fa_output = fa(data %>% select(-id, -condition, -stage), nfactors = 2, rotate = "varimax")
  print(sort = TRUE) 

library(kableExtra)
create_fa_table <- function(fa_output) {
  # Extract loadings and convert to a data frame
  loadings_df <- as.data.frame(unclass(fa_output$loadings)) %>% rownames_to_column(var = "Item")
  
  # Get factor names
  factor_names <- colnames(loadings_df %>% select(-Item))
  
  
  # Sort by absolute value of loadings
  loadings_df_sorted <- loadings_df %>%
    select(-Item) %>%
    rowwise() %>%
    mutate(max_loading = max(across(all_of(factor_names)), na.rm = TRUE)) %>%
    arrange(desc(max_loading)) %>%
    select(-max_loading) %>% 
    ungroup()

  loadings_df <- loadings_df_sorted %>% left_join(loadings_df) %>% select(Item, everything())

  # Bold loadings greater than 0.3
  loadings_df <- loadings_df %>%
    mutate(across(where(is.numeric), ~ifelse(abs(.) > 0.3, paste0("**", round(., 2), "**"), round(., 2))))
  

  # Calculate eigenvalues and variance explained
  eigenvalues <- fa_output$values
  variance_explained <- eigenvalues / sum(eigenvalues) * 100
  
  # Create summary row for eigenvalues and variance explained
  summary_row <- c(
    "Eigenvalues", 
    Ben::numformat(eigenvalues, 2)
  )
  variance_row <- c(
    "% Variance Explained", 
    paste0(Ben::numformat(variance_explained, 2), "%")
  )

  nfactors = fa_output$factors
  # Combine loadings and summary rows
  combined_df <- rbind(loadings_df, summary_row[0:nfactors+1], variance_row[0:nfactors+1])
  
  table = gt(combined_df) %>% 
  fmt_markdown(columns = everything()) 
  
  return(table)
}

data %>% 
  select(-id, -condition, -stage) %>% 
  fa(nfactors = 2, rotate = "varimax") %>%
  create_fa_table() %>% 
  gtsave("tables/factor_analysis_table.tex")
# Example usage with a factor analysis output
# fa_output <- fa(your_data, nfactors = 3, rotate = "varimax")
# print(create_fa_table(fa_output))



fa.parallel(data %>% select(-id, -condition, -stage, -value_emphasis), fa = "both", n.iter = 1000)
data %>% select(-id, -condition, -stage, -value_emphasis) %>% 
fa()

scores = data %>% 
  select(-id, -condition, -stage, -value_emphasis) %>% 
  alpha() %>% 
  `$`(scores)

data %>% 
  mutate(total = scores) %>% 
  pivot_longer(less_is_more:easy_responding, names_to = "metric", values_to = "score") %>% 
  group_by(metric,stage) %>%
  summarise(cor = cor(score, total)) %>% 
  arrange(stage)
