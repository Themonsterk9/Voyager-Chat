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

async function handleGoogleAuth(req, res) {
  try {
    const { code, redirect_uri, code_verifier, client_id } = req.body;
    if (!code) {
      return res.status(400).json({ status: 'error', message: 'Authorization code is required.' });
    }

    const { googleClientId, googleClientSecret } = require('../config/env');
    const effectiveClientId = client_id || googleClientId;
    const params = new URLSearchParams({
      client_id: effectiveClientId,
      client_secret: googleClientSecret,
      code: code,
      grant_type: 'authorization_code',
      redirect_uri: redirect_uri || '',
    });
    if (code_verifier) {
      params.append('code_verifier', code_verifier);
    }

    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
    });

    if (!tokenRes.ok) {
      const errText = await tokenRes.text();
      return res.status(400).json({ status: 'error', message: `Google token exchange failed: ${errText}` });
    }

    const tokenData = await tokenRes.json();
    const accessToken = tokenData.access_token;
    if (!accessToken) {
      return res.status(400).json({ status: 'error', message: 'No access token received from Google.' });
    }

    const userRes = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!userRes.ok) {
      return res.status(400).json({ status: 'error', message: 'Failed to fetch Google user profile.' });
    }

    const userInfo = await userRes.json();
    const googleId = userInfo.id || '';
    const email = userInfo.email || 'user@google.com';
    const name = userInfo.name || email.split('@')[0];
    const picture = userInfo.picture || null;

    return res.status(200).json({
      status: 'success',
      user: {
        id: `google_${googleId}`,
        email: email,
        displayName: name,
        avatarUrl: picture,
      },
    });
  } catch (err) {
    return res.status(500).json({ status: 'error', message: err.message || 'Google authentication error.' });
  }
}

module.exports = {
  handleSendOtp,
  handleVerifyOtp,
  handleSendWelcome,
  handleForgotPassword,
  handleGoogleAuth,
};
