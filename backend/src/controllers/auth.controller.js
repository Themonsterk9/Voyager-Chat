const { sendOtpEmail, verifyOtp, sendWelcomeEmail } = require('../services/brevo.service');

async function handleSendOtp(req, res) {
  try {
    const { email, purpose = 'LOGIN' } = req.body;
    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return res.status(400).json({ status: 'error', message: 'Valid email address is required.' });
    }

    const brevoRes = await sendOtpEmail(email, purpose);
    return res.status(200).json({
      status: 'success',
      message: 'OTP sent successfully.',
      messageId: brevoRes.messageId,
    });
  } catch (err) {
    return res.status(400).json({ status: 'error', message: err.message || 'Failed to send OTP.' });
  }
}

async function handleVerifyOtp(req, res) {
  try {
    const { email, otp, purpose = 'LOGIN' } = req.body;
    if (!email || !otp) {
      return res.status(400).json({ status: 'error', message: 'Email and OTP are required.' });
    }

    const result = verifyOtp(email, otp, purpose);
    if (!result.success) {
      return res.status(400).json({ status: 'error', message: result.message });
    }

    return res.status(200).json({
      status: 'success',
      message: 'OTP verified successfully.',
      user: {
        id: `usr_otp_${email.trim().toLowerCase().split('').reduce((acc, char) => acc + char.charCodeAt(0), 0)}`,
        email: email.trim().toLowerCase(),
      },
    });
  } catch (err) {
    return res.status(500).json({ status: 'error', message: 'Internal verification error.' });
  }
}

async function handleSendWelcome(req, res) {
  try {
    const { email, displayName = 'Voyager User' } = req.body;
    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return res.status(400).json({ status: 'error', message: 'Valid email address is required.' });
    }

    const brevoRes = await sendWelcomeEmail(email, displayName);
    return res.status(200).json({
      status: 'success',
      message: 'Welcome email sent successfully.',
      messageId: brevoRes.messageId,
    });
  } catch (err) {
    return res.status(400).json({ status: 'error', message: err.message || 'Failed to send welcome email.' });
  }
}

async function handleForgotPassword(req, res) {
  try {
    const { email } = req.body;
    if (email && typeof email === 'string' && email.includes('@')) {
      try {
        await sendOtpEmail(email, 'PASSWORD_RESET');
      } catch (_) {}
    }
    return res.status(200).json({
      status: 'success',
      message: 'If an account exists for this email, password reset instructions have been sent.',
    });
  } catch (_) {
    return res.status(200).json({
      status: 'success',
      message: 'If an account exists for this email, password reset instructions have been sent.',
    });
  }
}

module.exports = {
  handleSendOtp,
  handleVerifyOtp,
  handleSendWelcome,
  handleForgotPassword,
};
