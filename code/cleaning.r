library(gt)
library(mongolite)
library(arrow)

rename_condition = function(data){
  data %>% 
    mutate(condition = case_match(condition, 
                                  1 ~ "Control",
                                  2 ~ "AI-as-usual",
                                  3 ~ "AI-optimized"))
}
# data = qualtRics::read_survey("raw.csv")

data = qualtRics::fetch_survey("SV_0Ne3P4pCkbltjBs") %>% 
  filter(StartDate > "2024-07-16 09:32:41")

data = data %>% filter(day(StartDate) != 18) # Remove one testing day

data = data %>% mutate(sample = ifelse(StartDate > "2024-07-19 07:32:41", 2,1))

# data = data %>% filter(StartDate > "2024-07-19 07:32:41") # just round 2

data %>% 
  select(condition, pretest_rewritten, practice_rewritten, test_rewritten, sample) %>% 
  gt::gt() %>% 
  fmt_markdown()

data = data %>% 
  filter(StartDate > "2024-07-16 07:32:41") %>% 
  select(-matches("NPS_GROUP")) %>% 
  rename(id = ResponseId)

data %>% select(comments)

data %>% 
  select(starts_with("cheat")) %>% 
  pivot_longer(everything(), names_to = "page", values_to = "cheat") %>% 
  group_by(page) %>%
  filter(!is.na(cheat)) %>%
  # cheat 6 is I didnt cheat
  count()

data %>% count(condition)

# dowload chatbot data
mongo_conn <- mongo(db = "myFirstDatabase", collection = "emails", url = "mongodb+srv://vercel-admin-user:jAE3mmTRCLERUveC@ai-rewriter.3ysvfv2.mongodb.net/myFirstDatabase?retryWrites=true&w=majority")
ai_rewrites <- mongo_conn$find() %>% as_tibble()

# get the base
practice_base = "<p>Subject: Sales Representative Position <br>Dear Hiring Manager, <br>I am writing to express my strong interest in the Sales Representative position at your company. As a results-driven professional with a passion for building relationships and exceeding targets, I am excited about the opportunity to contribute to your teams success. Throughout my career, I have consistently demonstrated my ability to identify and capitalize on new business opportunities, develop and maintain strong client relationships, and achieve outstanding sales results. <br>My track record of success includes consistently exceeding sales quotas, implementing effective sales strategies, and collaborating with cross-functional teams to drive revenue growth. I am confident that my strong communication skills, persuasive abilities, and deep understanding of sales techniques would make me a valuable asset to your organization. I am particularly drawn to your company's innovative products/services and reputation for excellence in the industry. I would welcome the opportunity to bring my expertise and enthusiasm to your team and help drive your company's continued growth and success.<br>Sincerely<br>Jalen</p>"

# if someone in cond 2 didnt change the email, i am assuming they wanted to put in what the ai did unchanged
data = data %>% 
  mutate(nochange = practice_rewritten == practice_base) %>%
  left_join(ai_rewrites %>% select(id = userId, rewrittenEmail)) %>%
  mutate(practice_rewritten = if_else(nochange, rewrittenEmail, practice_rewritten))

data %>% 
  filter(condition==2) %>% 
  select(practice_rewritten,rewrittenEmail) %>% 
  mutate(same = practice_rewritten == rewrittenEmail) %>%
  bind_rows(tibble(practice_rewritten = practice_base, rewrittenEmail = practice_base)) %>% 
  gt::gt() %>%
  fmt_markdown(columns = vars(practice_rewritten,rewrittenEmail))

data %>% select(condition,nochange,rewrittenEmail) %>% filter(condition != 1)

data %>% write_parquet("data/clean.parquet")

long_texts = data %>%
  select(id, condition, pretest_rewritten, practice_rewritten, test_rewritten, sample) %>% 
  pivot_longer(cols = -c(id, condition, sample), names_to = "stage", values_to = "text")

long_texts %>% 
  filter(condition == 2, stage == "practice_rewritten") %>%
  gt::gt() %>% 
  fmt_markdown(columns = vars(text))

arrow::write_parquet(long_texts, "data/long_texts.parquet")


data
