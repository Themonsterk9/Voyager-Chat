const express = require('express');
const router = express.Router();
const {
  handleSendOtp,
  handleVerifyOtp,
  handleSendWelcome,
  handleForgotPassword,
  handleGoogleAuth,
} = require('../controllers/auth.controller');

router.post('/send-otp', handleSendOtp);
router.post('/verify-otp', handleVerifyOtp);
router.post('/send-welcome', handleSendWelcome);
router.post('/forgot-password', handleForgotPassword);
router.post('/google', handleGoogleAuth);

module.exports = router;
