data = arrow::read_parquet("data/clean.parquet")

(data %>% 
  select(condition, Q120, Q121) %>% 
  rename_condition() %>%
  rename(Practice = Q120,
         Test = Q121
         ) %>%
  pivot_longer(cols = c(Practice, Test), names_to = "stage", values_to = "effort") %>% 
  ggplot(aes(condition,effort, color = condition, fill = condition))+
  stat_summary(fun = mean, geom = "col", alpha= .4)+
  ggpubr::stat_anova_test(vjust = 2.5, hjust = -.5)+
  ggpubr::stat_compare_means(comparisons = list(c(2,1), c(3,1), c(3,2)), vjust = .2, size = 3)+
  stat_summary(fun.data = mean_se, geom = "errorbar", width = .1)+
  geom_jitter(alpha = .3)+
  facet_wrap(~stage)+
  labs(
       x = "Condition",
       fill = NULL, 
       color= NULL,
       y = "Perceived effort")+
  scale_y_continuous(breaks = 0:10)+
  theme(legend.position = "none")) %>% 
  add_color()
ggsave("plots/effort.png", width = 6, height = 3, dpi = 300)


data %>% 
  select(condition, Q120, Q121) %>% 
  rename_condition() %>%
  rename(Practice = Q120,
         Test = Q121
         ) %>% 
  pivot_longer(cols = c(Practice, Test), names_to = "stage", values_to = "effort") %>%
  group_by(stage) %>%
rstatix::cohens_d(effort~condition)
