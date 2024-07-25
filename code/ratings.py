from edsl.questions import QuestionLinearScale
from edsl import Scenario, Survey, Model
import pandas as pd
import dotenv

dotenv.load_dotenv()

# read text
data = pd.read_parquet("data/long_texts.parquet")

# remove nones
data = data.dropna(subset=['text'])

# Construct questions
q1 = QuestionLinearScale(
    question_name = "clarity",
    question_text = "On a scale from 1 to 7, how much load does this text put into the reader? Good text should be concise, use simple words, short sentences, easy to read and navigate, tell readers why they should care, and make responding easy: {{ text }}?",
    question_options = [1, 2, 3, 4, 5, 6, 7],
    option_labels = {1:"Little load, Very easy to read, follows all guidelines perfectly", 7:"A lot of cognitive load, Very hard to read, does not follow guidelines"}
)

prompts = pd.read_csv("code/prompts.csv")
prompts = prompts[0:6]

questions = [
    QuestionLinearScale(
    question_name = name,
    question_text = text,
    question_options = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    option_labels = {0:label_low, 10:label_high}
) for name, text, label_low, label_high in zip(prompts["name"], prompts["text"], prompts["label_low"], prompts["label_high"])
]

# Add data to questions using scenarios
texts = data["text"]
scenarios = [Scenario({"text": t}) for t in texts]

# Combine questions in a survey
survey = Survey(questions = [q1])
questions.append(q1)
survey = Survey(questions = questions)

# Select language models
models = [Model(m) for m in ["gpt-4o"]]

results = survey.by(scenarios).by(models).run()
results.show_exceptions()

cols = ["answer." + name for name in prompts["name"]]
cols.append("answer.clarity")
cols.append("scenario.text")
results = results.to_pandas()[cols]

data = data.merge(results, left_on="text", right_on="scenario.text")

# strip html tags
import html2text
# drop empty texts
data = data.dropna(subset=['text'])


data['raw_text'] = data['text'].apply(lambda x: html2text.html2text(x))

from readability import Readability
data["flesch_kincaid"] = data["text"].apply(lambda x: Readability(x).flesch_kincaid().score)
data["n_words"] = data["text"].apply(lambda x: len(x.split()))
data["avg_words_per_sentence"] = data['text'].apply(lambda x: Readability(x).statistics()['num_sentences'])


data[['id','condition','stage','text','raw_text','flesch_kincaid','answer.clarity', 'answer.less_is_more', 'answer.easy_reading', 'answer.easy_navigation', 'answer.formatting', 'answer.value_emphasis', 'answer.easy_responding',"n_words", 'avg_words_per_sentence']].to_parquet("data/long_texts_with_ratings.parquet")
