from edsl.questions import QuestionLinearScale
from edsl import Scenario, Survey, Model
import pandas as pd

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

# Add data to questions using scenarios
texts = data["text"]
scenarios = [Scenario({"text": t}) for t in texts]

# Combine questions in a survey
survey = Survey(questions = [q1])

# Select language models
models = [Model(m) for m in ["gpt-4o"]]

results = survey.by(scenarios).by(models).run()

data = data.merge(results.to_pandas()[["answer.clarity", "scenario.text"]], left_on="text", right_on="scenario.text")

# strip html tags
import html2text
# drop empty texts
data = data.dropna(subset=['text'])


data['raw_text'] = data['text'].apply(lambda x: html2text.html2text(x))

from readability import Readability
data["flesch_kincaid"] = data["text"].apply(lambda x: Readability(x).flesch_kincaid().score)
data["n_words"] = data["text"].apply(lambda x: len(x.split()))
data["avg_words_per_sentence"] = data['text'].apply(lambda x: Readability(x).statistics()['num_sentences'])


data[['id','condition','stage','text','raw_text','flesch_kincaid','answer.clarity',"n_words", 'avg_words_per_sentence']].to_parquet("data/long_texts_with_ratings.parquet")
