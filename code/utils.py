# function to count words
def count_words(text):
    words = text.split()
    return len(words)

# function to get fleish-kincaid score
from readability import Readability
text = "I am writing this letter to express my profound interest in the Executive Assistant position that I recently discovered on your companys website. As a highly motivated and exceptionally organized individual with a proven track record of success in administrative roles, I believe that I possess the necessary qualifications and skills to excel in this position and make a significant contribution to your organization. My extensive experience in managing complex schedules, coordinating high-level meetings, and providing comprehensive support to senior executives has equipped me with the tools required to thrive in a fast-paced and dynamic environment such as yours. Furthermore, I am confident that my exceptional communication skills, both written and verbal, coupled with my proficiency in various office software applications, including but not limited to Microsoft Office Suite, Google Workspace, and project management tools, will allow me to seamlessly integrate into your team and hit the ground running from day one. I am excited about the prospect of bringing my expertise and enthusiasm to your esteemed organization and contributing to its continued growth and success. I would be thrilled to have the opportunity to discuss my qualifications further and learn more about how I can add value to your team in an interview setting. Sincerely, Diane"

r = Readability(text)

print(r.statistics())
r.flesch_kincaid()
r.flesch()
r.gunning_fog()
r.coleman_liau()
r.dale_chall()
r.ari()
r.linsear_write()
r.spache()

r.statistics()
count_words(text)

print(r.flesch())
print(r.gunning_fog())
print(r.coleman_liau())
print(r.dale_chall())
print(r.ari())
print(r.linsear_write())
print(r.spache())

# Rate the text using api
r.statistics()['num_words']
data
