data = arrow::read_parquet("data/clean.parquet")

a = (data  %>%
  select(condition, matches("Page"), sample) %>%
  select(-c(2:8)) %>%
  select(-`2_time_test_Page Submit`) %>% 
  mutate(total_time_practice = rowSums(select(., matches("Page")), na.rm = T) / 60) %>% 
  rename_condition() %>%
  filter(sample == 2) %>%
  ggplot(aes(x = condition, y = total_time_practice, color = condition, fill = condition)) +
  stat_summary(fun = mean, geom = "col", alpha = .4)+
  stat_summary(fun.data = mean_se, geom = "errorbar", width = .1) +
  # add mean values to plot with geom text
  stat_summary(fun = mean, geom = "text", aes(label = round(..y.., 2)), vjust = -1.5)+
  geom_point(size = 3, alpha = .3)+
  ggpubr::stat_anova_test(vjust = 3, hjust = .75)+
  ggpubr::stat_compare_means(comparisons = list(c(2,1), c(3,1), c(3,2)), vjust = .2, size = 3)+
  labs(
       x = NULL,
       y = "Total time (minutes)",
       caption = "n = 15, sample 2")+
  theme(legend.position = "none")) %>% 
  add_color()
  a
ggsave("plots/practice_time.png", width = 4, height = 3, dpi = 300)

data %>% 
  filter(sample == 2) %>%
  select(condition, matches("Page")) %>% 
  select(1, 9:ncol(.)) %>% 
  select(-`2_time_test_Page Submit`) %>% 
  rename_condition() %>%
  mutate_if(is.numeric, ~./60)  %>% 
  pivot_longer(-condition, names_to = "page", values_to = "time") %>%
  mutate(page = fct_rev(fct_inorder(page))) %>%
  group_by(condition, page) %>%
  summarise(mean = mean(time),
            se = sd(time)/sqrt(n())) %>%
  ggplot(aes(x = condition, y = mean, fill = page)) +
  geom_col(position = "stack")+
  labs(title = "Time spent on each page by condition",
       x = "Condition",
       y = "Time (minutes)")+
  theme(legend.position = "none")+
  scale_fill_brewer(palette = "Set1")+ 
  annotate("text", x = 2, y = 1.5, label = "Initial Rewrite", size = 3)+
  annotate("text", x = 2, y = 10, label = "View AI", size = 3)+
  annotate("text", x = 2, y = 11, label = "Compare", size = 3)+
  annotate("text", x = 2, y = 13, label = "Add changes", size = 3)+
  annotate("text", x = 1, y = 1.5, label = "Single Page", size = 3)+
  annotate("text", x = 3, y = 1.5, label = "Initial Rewrite", size = 3)
  
ggsave("plots/page_time.png", width = 4, height = 2.5, dpi = 300)

# TEST
b = (data  %>%
  filter(sample == 2) %>%
  select(condition, test_time = `2_time_test_Page Submit`, sample) %>%
  mutate(test_time = test_time / 60) %>%
  rename_condition() %>%
  ggplot(aes(x = condition, y = test_time, color = condition, fill = condition)) +
  stat_summary(fun = mean, geom = "col", alpha = .4)+
  stat_summary(fun.data = mean_se, geom = "errorbar", width = .1) +
  # add mean values to plot with geom text
  stat_summary(fun = mean, geom = "text", aes(label = round(..y.., 2)), vjust = -1.5)+
  geom_point(size = 3, alpha = .3)+
  ggpubr::stat_anova_test(vjust = 3, hjust = .75)+
  ggpubr::stat_compare_means(comparisons = list(c(2,1), c(3,1), c(3,2)), vjust = .2, size = 3)+
  labs(
       x = NULL,
       y = "Total time (minutes)",
       caption = "n = 15, sample 2")+
  theme(legend.position = "none")) %>% 
  add_color()
b
ggsave("plots/test_time.png", width = 4, height = 3, dpi = 300)

# Learning time
c = (data  %>%
  select(condition, matches("Page"), sample) %>%
  select(1:8, sample) %>%
  mutate(total_time_learning = rowSums(select(., matches("Page")), na.rm = T) / 60) %>% 
  rename_condition() %>%
  filter(sample == 2) %>%
  ggplot(aes(x = condition, y = total_time_learning, color = condition, fill = condition)) +
  stat_summary(fun = mean, geom = "col", alpha = .4)+
  stat_summary(fun.data = mean_se, geom = "errorbar", width = .1) +
  # add mean values to plot with geom text
  stat_summary(fun = mean, geom = "text", aes(label = round(..y.., 2)), vjust = -1.5)+
  geom_point(size = 3, alpha = .3)+
  ggpubr::stat_anova_test(vjust = 3, hjust = .75)+
  ggpubr::stat_compare_means(comparisons = list(c(2,1), c(3,1), c(3,2)), vjust = .2, size = 3)+
  labs(
       x = NULL,
       y = "Total time (minutes)",
       caption = "n = 15, sample 2")+
  theme(legend.position = "none")) %>% 
  add_color()
c
ggsave("plots/learning_time.png", width = 4, height = 3, dpi = 300)
  
ggpubr::ggarrange(c,a,b, nrow = 1, labels = c("Learning", "Practice", "Test"))
ggsave("plots/time.png", width = 8, height = 3, dpi = 300)
 
data %>% 
  select(condition, matches("Page")) %>% 
  mutate(
    learning = (`time_p1_Page Submit` + `time_p2_Page Submit`+ `time_p3_Page Submit`+ `time_p4_Page Submit`+ `time_p5_Page Submit`+ `time_p6_Page Submit`+ `time_pcompare_Page Submit`)/60,
    test = `2_time_test_Page Submit`/60
    ) %>% 
    rowwise() %>%
    mutate(practice = sum(c(`3_time_practice_c2_Page Submit`, `3_time_try1_Page Submit`, `3_time_ai_Page Submit`, `3_time_compare_Page Submit`,`3_time_try2_Page Submit` ),na.rm = T)/60) %>%
    ungroup() %>%
    select(condition, learning, practice, test) %>%
  rename_condition() %>%
  pivot_longer(-condition, names_to = "stage", values_to = "time") %>%
  group_by(stage) %>%
  rstatix::cohens_d(time~condition)
