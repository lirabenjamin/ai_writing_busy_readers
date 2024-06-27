const express = require('express');
const fetch = require('node-fetch');
const cors = require('cors');
const mongoose = require('mongoose');
require('dotenv').config();

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

app.post('/api/rewrite-email', async (req, res) => {
    console.log('Received request to rewrite email');
    const { inputEmail } = req.body;
    const userId = req.query.userid;
    if (!userId) {
        return res.status(400).json({ error: 'User ID is required' });
    }

    const basePrompt = `You are an AI assistant designed to rewrite emails to make them more concise, clear, and effective. Your task is to transform verbose, complex emails into streamlined messages that busy professionals can quickly read and act upon. You rewrite emails following Todd Rogers's six key principles: 1) Less Is More (Use fewer words, Include fewer ideas, Make fewer requests) 2) Make Reading Easy (Use short and common words, Write straightforward sentences, Write shorter sentences) 3) Design for Easy Navigation (Make key information immediately visible, Separate distinct ideas, Place related ideas together, Order ideas by priority, Include headings, Consider using visuals) 4) Use Enough Formatting but No More (Match formatting to readers' expectations, Highlight, bold, or underline the most important ideas, Limit your formatting) 5) Tell Readers Why They Should Care (Emphasize what readers value, Emphasize which readers should care) 6) Make Responding Easy (Simplify the steps required to act, Organize key information needed for action, Minimize the amount of attention required). When rewriting emails: Maintain the original subject line but modify if needed, Keep the tone professional but direct, Prioritize important information and action items, Use bullet points or numbered lists, Bold key phrases or deadlines, Remove unnecessary details, Break down long paragraphs, Use active voice and clear language, Retain all critical information. Your goal is to create an email that can be quickly scanned and understood, with clear action items and key information prominently displayed.`;

    const prompt = `Rewrite the following email to make it more professional and concise:\n\n${inputEmail}\n\nRewritten email:`;

    try {
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
                    { role: "system", content: basePrompt },
                    { role: "user", content: prompt }
                ]
            })
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`OpenAI API error: ${response.status} ${response.statusText} - ${errorText}`);
        }

        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');

        let rewrittenEmail = '';
        const decoder = new TextDecoder();
        let buffer = '';

        response.body.on('data', (chunk) => {
            buffer += decoder.decode(chunk, { stream: true });
            let lines = buffer.split('\n');
            buffer = lines.pop(); // Keep the last line (might be incomplete) in buffer

            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    const data = line.replace(/^data: /, '');
                    console.log(`Received chunk: ${data}`);
                    if (data === '[DONE]') {
                        res.write('data: [DONE]\n\n');
                        res.end();
                        return;
                    }

                    try {
                        const json = JSON.parse(data);
                        if (json.choices && json.choices[0] && json.choices[0].delta) {
                            const content = json.choices[0].delta.content || '';
                            rewrittenEmail += content;
                            res.write(`data: ${content}\n\n`);  // Send the chunk to the client
                        }
                    } catch (e) {
                        console.error('Error parsing JSON', e);
                    }
                }
            }
        });

        response.body.on('end', async () => {
            try {
                const newEmail = new Email({ userId, inputEmail, rewrittenEmail });
                await newEmail.save();
                console.log('Email saved to database:', newEmail);
            } catch (saveError) {
                console.error('Error saving to database:', saveError);
            }

            console.log('Email rewritten and saved to database');
        });

    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({ error: 'An error occurred while rewriting the email. Please try again.' });
    }
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
