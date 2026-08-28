const express = require('express');
const router = express.Router();
const {
  handleSendOtp,
  handleVerifyOtp,
  handleSendWelcome,
  handleForgotPassword,
  handleGoogleIdToken,
  handleGoogleAuthCode,
  handleValidateSession,
  handleBrevoEvent,
} = require('../controllers/auth.controller');

router.post('/send-otp', handleSendOtp);
router.post('/verify-otp', handleVerifyOtp);
router.post('/send-welcome', handleSendWelcome);
router.post('/forgot-password', handleForgotPassword);
router.post('/google', handleGoogleIdToken);
router.post('/google/code', handleGoogleAuthCode);
router.get('/session', handleValidateSession);
router.post('/brevo/events', handleBrevoEvent);

module.exports = router;
