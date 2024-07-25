library(gt)
library(mongolite)
library(arrow)
library(dotenv)

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

data = data %>% filter(Progress == 100)


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
load_dot_env()
# Get the MongoDB URI from the environment variable
mongo_uri <- Sys.getenv("MONGODB_URI")
mongo_conn <- mongo(db = "myFirstDatabase", collection = "emails", url = mongo_uri)
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

data  %>% select(id,pretest_rewritten,practice_rewritten,test_rewritten) %>% 
  pivot_longer(cols = -id, names_to = "stage", values_to = "text")  %>% 
  unique() %>% 
  drop_na() %>% 
  # assign a number id to each unique text
  mutate(text_id = as.integer(factor(text)))  %>% 
  arrow::write_parquet("data/texts_to_rate.parquet")

# timing variables
timing = data %>% 
    filter(sample == 2) %>%
  select(id,condition,sample, matches("Page")) %>% 
  mutate(
    learning_time = (`time_p1_Page Submit` + `time_p2_Page Submit`+ `time_p3_Page Submit`+ `time_p4_Page Submit`+ `time_p5_Page Submit`+ `time_p6_Page Submit`+ `time_pcompare_Page Submit`)/60,
    test_time = `2_time_test_Page Submit`/60
    ) %>% 
    rowwise() %>%
    mutate(practice_time = sum(c(`3_time_practice_c2_Page Submit`, `3_time_try1_Page Submit`, `3_time_ai_Page Submit`, `3_time_compare_Page Submit`,`3_time_try2_Page Submit` ),na.rm = T)/60) %>% 
    select(id,condition, learning_time, practice_time, test_time) %>% 
    ungroup()

data = data %>% left_join(timing)

data %>% colnames()

# important variables
clean = data %>% select(id,condition, sample, year_of_birth:writing_aireliance, learning_time, practice_time, test_time,ai_preference = `3_practice_preference`, ai_why = `3_practice_why`, cheat_1:cheat_5_TEXT, ai_helpfulness, effort_practice = Q120, effort_test = Q121, comments, practice_rewritten:pretest_rewritten)

data %>% write_parquet("data/clean.parquet")

long_texts = data %>%
  select(id, condition, pretest_rewritten, practice_rewritten,practice_rewritten2, test_rewritten, sample) %>% 
  pivot_longer(cols = -c(id, condition, sample), names_to = "stage", values_to = "text")

data %>% 
  filter(condition == 3) %>%
  select(practice_rewritten, practice_rewritten2)

long_texts %>% 
  filter(condition == 2, stage == "practice_rewritten") %>%
  gt::gt() %>% 
  fmt_markdown(columns = vars(text))

arrow::write_parquet(long_texts, "data/long_texts.parquet")


data$practice_rewritten2
