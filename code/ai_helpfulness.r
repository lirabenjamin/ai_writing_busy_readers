data = arrow::read_parquet("data/clean.parquet")

(data %>% 
  select(condition, ai_helpfulness, sample) %>% 
  filter(condition != 1) %>%
  rename_condition() %>%
  ggplot(aes(condition,ai_helpfulness, color = condition, fill = condition))+
  stat_summary(fun = mean, geom = "col", alpha= .4)+
  ggpubr::stat_compare_means(comparisons = list(c(2,1), c(3,1), c(3,2)), vjust = .2, size = 3)+
  stat_summary(fun.data = mean_se, geom = "errorbar", width = .1)+
  geom_jitter(alpha = .3)+
  labs(
       x = "Condition",
       fill = NULL, 
       color= NULL,
       y = "Perceived Helpfulness of AI")+
  scale_y_continuous(breaks = 0:10)+
  theme(legend.position = "none")) %>% 
  add_color()

rstatix::t_test(ai_helpfulness~condition, data = data %>% filter(condition != 1))
rstatix::cohens_d(ai_helpfulness~condition, data = data %>% filter(condition != 1))

data %>% group_by(condition) %>% summarise(mean = mean(ai_helpfulness), se = sd(ai_helpfulness)/sqrt(n()))

ggsave("plots/ai_helpfulness.png", width = 4, height = 3, dpi = 300)
