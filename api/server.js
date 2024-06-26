const express = require('express');
const fetch = require('node-fetch');
const cors = require('cors');
const mongoose = require('mongoose');
require('dotenv').config();
const fs = require('fs').promises;
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const MONGODB_URI = process.env.MONGODB_URI;

app.use(cors());
app.use(express.json());

// Connect to MongoDB
mongoose.connect(MONGODB_URI, { 
    useNewUrlParser: true, 
    useUnifiedTopology: true,
    useCreateIndex: true,
    useFindAndModify: false
})
    .then(() => console.log('MongoDB connected'))
    .catch(err => console.error('MongoDB connection error:', err));

// Define a schema and model for emails
const emailSchema = new mongoose.Schema({
    userId: String,
    inputEmail: String,
    rewrittenEmail: String,
    createdAt: { type: Date, default: Date.now }
});

const Email = mongoose.model('Email', emailSchema);

async function readPromptFromFile(filename) {
    try {
      const filePath = path.join(__dirname, filename);
      const data = await fs.readFile(filePath, 'utf8');
      return data.trim();
    } catch (error) {
      console.error('Error reading prompt file:', error);
      return null;
    }
  }

app.post('/api/rewrite-email', async (req, res) => {
    console.log('Received request to rewrite email');
    const { inputEmail } = req.body;
    const userId = req.query.userid;
    if (!userId) {
        return res.status(400).json({ error: 'User ID is required' });
    }

    const prompt = `Rewrite the following email to make it more professional and concise:\n\n${inputEmail}\n\nRewritten email:`;

    try {
        const basePrompt = await readPromptFromFile('prompt.txt');
        if (!basePrompt) {
            throw new Error('Failed to read prompt from file');
        }

        const response = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${OPENAI_API_KEY}`
            },
            body: JSON.stringify({
                model: "gpt-3.5-turbo",
                stream: true,
                messages: [
                    {"role": "system", "content": basePrompt},
                    {"role": "user", "content": prompt}
                ]
            })
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`OpenAI API error: ${response.status} ${response.statusText} - ${errorText}`);
        }

        res.setHeader('Content-Type', 'text/plain');

        let rewrittenEmail = '';
        const decoder = new TextDecoder();

        for await (const chunk of response.body) {
            const text = decoder.decode(chunk, { stream: true });
            const lines = text.split('\n');

            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    const data = line.replace(/^data: /, '');
                    if (data === '[DONE]') break;

                    try {
                        const json = JSON.parse(data);
                        if (json.choices && json.choices[0] && json.choices[0].delta) {
                            rewrittenEmail += json.choices[0].delta.content || '';
                        }
                    } catch (e) {
                        console.error('Error parsing JSON', e);
                    }
                }
            }

            res.write(text);  // Send the chunk to the client
        }

        // Save the input and output to the database
        try {
            const newEmail = new Email({ userId, inputEmail, rewrittenEmail });
            await newEmail.save();
            console.log('Email saved to database:', newEmail);
        } catch (saveError) {
            console.error('Error saving to database:', saveError);
        }

        console.log('Email rewritten and saved to database');
        res.end();  // End the response stream
    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({ error: 'An error occurred while rewriting the email. Please try again.' });
    }
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
