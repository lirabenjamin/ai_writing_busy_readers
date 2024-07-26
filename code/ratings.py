from edsl.questions import QuestionLinearScale
from edsl import Scenario, Survey, Model
import pandas as pd
import dotenv

dotenv.load_dotenv()

# read text
data = pd.read_parquet("data/long_texts.parquet")

# remove nones
data = data.dropna(subset=['text'])

data['id_stage'] = data['id'] + "_" + data['stage']

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
data = data.reset_index()
texts = data["text"]
# scenarios = [Scenario({"text": t}) for t in texts]
scenarios = [Scenario({"text": t, "id_stage": id_stage}) for t, id_stage in zip(texts, data['id_stage'])]


# Combine questions in a survey
survey = Survey(questions = [q1])
questions.append(q1)
survey = Survey(questions = questions)

# Select language models
models = [Model(m) for m in ["gpt-4o"]]

results = survey.by(scenarios).by(models).run()
results.show_exceptions()

results = results.to_pandas()

results.to_parquet("data/ratings_raw.parquet")

cols = ["answer." + name for name in prompts["name"]]
cols.append("answer.clarity")
cols.append("scenario.text")
cols.append("scenario.id_stage")
results = results[cols]

data_merge = data.merge(results, left_on="id_stage", right_on="scenario.id_stage")

# strip html tags
import html2text
# drop empty texts
data_merge = data_merge.dropna(subset=['text'])

data_merge['raw_text'] = data_merge['text'].apply(lambda x: html2text.html2text(x))

from readability import Readability
data_merge["flesch_kincaid"] = data_merge["text"].apply(lambda x: Readability(x).flesch_kincaid().score)
data_merge["n_words"] = data_merge["text"].apply(lambda x: len(x.split()))
data_merge["avg_words_per_sentence"] = data_merge['text'].apply(lambda x: Readability(x).statistics()['num_sentences'])

data_merge.columns


data_merge[['id','condition','stage','text','raw_text','flesch_kincaid','answer.clarity', 'answer.less_is_more', 'answer.easy_reading', 'answer.easy_navigation', 'answer.formatting', 'answer.value_emphasis', 'answer.easy_responding',"n_words", 'avg_words_per_sentence']].to_parquet("data/long_texts_with_ratings.parquet")
