const express = require('express');
const fetch = require('node-fetch');
const cors = require('cors');
require('dotenv').config();
const db = require('./firebase'); // Ensure the path is correct

const app = express();
const PORT = process.env.PORT || 3000;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

app.use(cors());
app.use(express.json());

app.post('/api/rewrite-email', async (req, res) => {
    console.log('Received request to rewrite email');
    const inputEmail = req.body.inputEmail;
    const prompt = `Rewrite the following email to make it more professional and concise:\n\n${inputEmail}\n\nRewritten email:`;

    try {
        console.log('Sending request to OpenAI API');
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

        // Save the input and output to Firestore
        await db.collection('emails').add({
            inputEmail,
            rewrittenEmail,
            createdAt: new Date()
        });

        console.log('Email rewritten and saved to Firestore');
        res.json({ rewrittenEmail });
    } catch (error) {
        console.error('Error occurred:', error);
        res.status(500).json({ error: 'An error occurred while rewriting the email. Please try again.' });
    }
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
