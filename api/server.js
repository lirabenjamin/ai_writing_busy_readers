const mongoose = require('mongoose');
const { OpenAI } = require('openai');
require('dotenv').config();

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const MONGODB_URI = process.env.MONGODB_URI;

mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
});

const emailSchema = new mongoose.Schema({
  userId: String,
  inputEmail: String,
  rewrittenEmail: String,
  status: String,
  createdAt: { type: Date, default: Date.now }
});

const Email = mongoose.model('Email', emailSchema);

const openai = new OpenAI({ apiKey: OPENAI_API_KEY });

export default async function handler(req, res) {
  if (req.method === 'POST') {
    const { inputEmail } = req.body;
    const userId = req.query.userid;

    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    const newEmail = new Email({
      userId,
      inputEmail,
      rewrittenEmail: '',
      status: 'processing'
    });

    await newEmail.save();

    // Start the email rewriting process
    rewriteEmailInBackground(newEmail._id, inputEmail);

    return res.status(202).json({ id: newEmail._id, message: 'Email rewriting started' });
  } else if (req.method === 'GET') {
    const { id } = req.query;

    if (!id) {
      return res.status(400).json({ error: 'Email ID is required' });
    }

    const email = await Email.findById(id);

    if (!email) {
      return res.status(404).json({ error: 'Email not found' });
    }

    return res.status(200).json({
      status: email.status,
      rewrittenEmail: email.rewrittenEmail
    });
  } else {
    res.setHeader('Allow', ['POST', 'GET']);
    res.status(405).end(`Method ${req.method} Not Allowed`);
  }
}

async function rewriteEmailInBackground(emailId, inputEmail) {
  const prompt = `Rewrite the following email to make it more professional and concise:\n\n${inputEmail}\n\nRewritten email:`;

  try {
    const stream = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        {"role": "system", "content": "You are a professional email editor."},
        {"role": "user", "content": prompt}
      ],
      stream: true,
    });

    let rewrittenEmail = '';

    for await (const chunk of stream) {
      rewrittenEmail += chunk.choices[0]?.delta?.content || '';
      
      // Update the database with the current progress
      await Email.findByIdAndUpdate(emailId, {
        rewrittenEmail: rewrittenEmail,
        status: 'processing'
      });
    }

    // Update the database with the final result
    await Email.findByIdAndUpdate(emailId, {
      rewrittenEmail: rewrittenEmail,
      status: 'completed'
    });

  } catch (error) {
    console.error('Error:', error);
    await Email.findByIdAndUpdate(emailId, { status: 'error' });
  }
}