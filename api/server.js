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
    inputEmail: String,
    rewrittenEmail: String,
    createdAt: { type: Date, default: Date.now }
});

const Email = mongoose.model('Email', emailSchema);

app.post('/api/rewrite-email', async (req, res) => {
    console.log('Received request to rewrite email');
    const inputEmail = req.body.inputEmail;
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
                messages: [
                    {"role": "system", "content": "You are a professional email editor."},
                    {"role": "user", "content": prompt}
                ]
            })
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`OpenAI API error: ${response.status} ${response.statusText} - ${errorText}`);
        }

        const data = await response.json();
        const rewrittenEmail = data.choices[0].message.content.trim();

        // Save the input and output to the database
        const newEmail = new Email({ inputEmail, rewrittenEmail });
        await newEmail.save();

        console.log('Email rewritten and saved to database');
        res.json({ rewrittenEmail });
    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({ error: 'An error occurred while rewriting the email. Please try again.' });
    }
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
