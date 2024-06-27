const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const { openai } = require('@ai-sdk/openai');
const { streamText } = require('ai');

dotenv.config();

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

    const prompt = `Rewrite the following email to make it more professional and concise:\n\n${inputEmail}\n\nRewritten email:`;

    try {
        const result = await streamText({
            model: openai('gpt-3.5-turbo'),
            messages: [
                { role: 'system', content: "You are a professional email editor." },
                { role: 'user', content: prompt }
            ],
            apiKey: OPENAI_API_KEY,
        });

        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');

        let rewrittenEmail = '';

        for await (const textPart of result.textStream) {
            rewrittenEmail += textPart;
            res.write(`data: ${textPart}\n\n`);
        }

        res.write('data: [DONE]\n\n');
        res.end();

        // Save the input and output to the database
        const newEmail = new Email({ userId, inputEmail, rewrittenEmail });
        await newEmail.save();
        console.log('Email rewritten and saved to database');
    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({ error: 'An error occurred while rewriting the email. Please try again.' });
    }
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
