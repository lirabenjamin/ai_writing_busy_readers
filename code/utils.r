factor_condition = function(data) { 
  data %>% 
  mutate(condition = case_match(condition, 
                            1 ~ "Control",
                            2 ~ "AI-as-usual",
                            3 ~ "AI-optimized")) %>%
  # make control the reference group
  mutate(condition = factor(condition, levels = c("Control", "AI-as-usual", "AI-optimized"))) %>%
  mutate(condition = relevel(factor(condition), ref = "Control"))
}

add_color = function(plot){
  plot + 
  scale_color_manual(values = c("Control" = "#2967b7", "AI-as-usual" = "#c01515", "AI-optimized" = "#4f9108")) +
  scale_fill_manual(values = c("Control" = "#2967b7", "AI-as-usual" = "#c01515", "AI-optimized" = "#4f9108"))
}


factor_stage = function(data) {
  data %>%
   mutate(stage = case_match(stage, 
                            "pretest_rewritten" ~ "Pretest",
                            "practice_rewritten" ~ "Practice",
                            "test_rewritten" ~ "Test")) %>%
  mutate(stage = factor(stage, levels = c("Pretest", "Practice", "Test")))
}