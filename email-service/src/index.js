require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { logger } = require('./logger');
const { sendVerificationCode } = require('./email-service');

const app = express();
const PORT = process.env.PORT || 3000;
const API_KEY = process.env.API_KEY || 'default-api-key';

// Middleware
app.use(cors());
app.use(express.json());

// API Key validation middleware
const validateApiKey = (req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  
  if (!apiKey || apiKey !== API_KEY) {
    logger.warn(`Unauthorized API access attempt from ${req.ip}`);
    return res.status(401).json({ 
      success: false, 
      message: 'Unauthorized. Invalid API Key' 
    });
  }
  
  next();
};

// Routes
app.get('/', (req, res) => {
  res.json({ 
    message: 'Monkey Messenger Email Service API', 
    status: 'Running' 
  });
});

// Send verification code endpoint
app.post('/api/send-verification-code', validateApiKey, async (req, res) => {
  try {
    const { email, code } = req.body;
    
    if (!email || !code) {
      return res.status(400).json({ 
        success: false, 
        message: 'Email and code are required' 
      });
    }
    
    logger.info(`Sending verification code to ${email}`);
    
    const result = await sendVerificationCode(email, code);
    
    logger.info(`Email sent successfully to ${email}`);
    res.json({ 
      success: true, 
      message: 'Verification code sent successfully' 
    });
  } catch (error) {
    logger.error(`Error sending verification code: ${error.message}`);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to send verification code',
      error: error.message
    });
  }
});

// Start server
app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (error) => {
  logger.error(`Unhandled Rejection: ${error.message}`);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error(`Uncaught Exception: ${error.message}`);
  process.exit(1);
}); 