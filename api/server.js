const mongoose = require('mongoose');
const { OpenAI } = require('openai');
require('dotenv').config();

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const MONGODB_URI = process.env.MONGODB_URI;

console.log('Server script started');

mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('MongoDB connected successfully'))
.catch(err => console.error('MongoDB connection error:', err));

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
  console.log(`Received ${req.method} request`);
  
  if (req.method === 'POST') {
    console.log('Processing POST request');
    const { inputEmail } = req.body;
    const userId = req.query.userid;

    if (!userId) {
      console.error('User ID is missing');
      return res.status(400).json({ error: 'User ID is required' });
    }

    try {
      const newEmail = new Email({
        userId,
        inputEmail,
        rewrittenEmail: '',
        status: 'processing'
      });

      await newEmail.save();
      console.log('New email document created:', newEmail._id);

      // Start the email rewriting process
      rewriteEmailInBackground(newEmail._id, inputEmail);

      return res.status(202).json({ id: newEmail._id, message: 'Email rewriting started' });
    } catch (error) {
      console.error('Error in POST request:', error);
      return res.status(500).json({ error: 'Internal server error' });
    }
  } else if (req.method === 'GET') {
    console.log('Processing GET request');
    const { id } = req.query;

    if (!id) {
      console.error('Email ID is missing');
      return res.status(400).json({ error: 'Email ID is required' });
    }

    try {
      const email = await Email.findById(id);

      if (!email) {
        console.error('Email not found:', id);
        return res.status(404).json({ error: 'Email not found' });
      }

      console.log('Returning email status:', email.status);
      return res.status(200).json({
        status: email.status,
        rewrittenEmail: email.rewrittenEmail
      });
    } catch (error) {
      console.error('Error in GET request:', error);
      return res.status(500).json({ error: 'Internal server error' });
    }
  } else {
    console.error('Method not allowed:', req.method);
    res.setHeader('Allow', ['POST', 'GET']);
    res.status(405).end(`Method ${req.method} Not Allowed`);
  }
}

async function rewriteEmailInBackground(emailId, inputEmail) {
  console.log('Starting background email rewriting for:', emailId);
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
    console.log('Email rewriting completed for:', emailId);

  } catch (error) {
    console.error('Error in rewriteEmailInBackground:', error);
    await Email.findByIdAndUpdate(emailId, { status: 'error' });
  }
}

console.log('Server script finished loading');