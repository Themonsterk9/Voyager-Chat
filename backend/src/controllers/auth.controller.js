const crypto = require('crypto');
const { sendOtpEmail, verifyOtp, sendWelcomeEmail, logDelivery } = require('../services/brevo.service');
const { googleAndroidClientId, googleWindowsClientId, googleClientSecret, sessionSecret } = require('../config/env');

const sessionTtlSeconds = 60 * 60 * 24 * 30;

function base64url(value) { return Buffer.from(value).toString('base64url'); }

function signSession(user) {
  if (!sessionSecret) throw new Error('Authentication service is not configured.');
  const now = Math.floor(Date.now() / 1000);
  const payload = { sub: user.id, email: user.email, name: user.displayName, iat: now, exp: now + sessionTtlSeconds };
  const unsigned = `${base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))}.${base64url(JSON.stringify(payload))}`;
  return `${unsigned}.${crypto.createHmac('sha256', sessionSecret).update(unsigned).digest('base64url')}`;
}

function readSession(token) {
  if (!sessionSecret || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const expected = crypto.createHmac('sha256', sessionSecret).update(`${parts[0]}.${parts[1]}`).digest();
  const supplied = Buffer.from(parts[2], 'base64url');
  if (expected.length !== supplied.length || !crypto.timingSafeEqual(expected, supplied)) return null;
  try {
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    if (!payload.sub || !payload.email || payload.exp <= Math.floor(Date.now() / 1000)) return null;
    return { id: payload.sub, email: payload.email, displayName: payload.name || null };
  } catch (_) { return null; }
}

function authenticatedResponse(res, user, extra = {}) {
  return res.status(200).json({ status: 'success', user, session: signSession(user), ...extra });
}

function googleUserFromClaims(claims) {
  if (!claims.sub || !claims.email || (claims.email_verified !== 'true' && claims.email_verified !== true)) throw new Error('Google did not return a verified email address.');
  return { id: `google_${claims.sub}`, email: claims.email.toLowerCase(), displayName: claims.name || claims.email.split('@')[0], avatarUrl: claims.picture || null };
}

async function verifyGoogleIdToken(idToken, audiences) {
  const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`);
  if (!response.ok) throw new Error('Google identity token is invalid.');
  const claims = await response.json();
  if (!['accounts.google.com', 'https://accounts.google.com'].includes(claims.iss)) throw new Error('Google token issuer is invalid.');
  if (!audiences.filter(Boolean).includes(claims.aud)) throw new Error('Google token audience is invalid.');
  return googleUserFromClaims(claims);
}

async function handleSendOtp(req, res) {
  try {
    const { email, purpose = 'LOGIN' } = req.body;
    if (!email || typeof email !== 'string' || !email.includes('@')) return res.status(400).json({ status: 'error', message: 'Valid email address is required.' });
    const brevoRes = await sendOtpEmail(email, purpose);
    return res.status(200).json({ status: 'success', message: 'OTP submitted for delivery.', messageId: brevoRes.messageId });
  } catch (err) { return res.status(400).json({ status: 'error', message: err.message || 'Failed to send OTP.' }); }
}

async function handleVerifyOtp(req, res) {
  try {
    const { email, otp, purpose = 'LOGIN', displayName } = req.body;
    if (!email || !otp) return res.status(400).json({ status: 'error', message: 'Email and OTP are required.' });
    const result = verifyOtp(email, otp, purpose);
    if (!result.success) return res.status(400).json({ status: 'error', message: result.message });
    const normalizedEmail = email.trim().toLowerCase();
    const user = { id: `usr_otp_${crypto.createHash('sha256').update(normalizedEmail).digest('hex').slice(0, 24)}`, email: normalizedEmail, displayName: displayName || normalizedEmail.split('@')[0] };
    let welcome;
    if (purpose.trim().toUpperCase() === 'REGISTRATION') {
      const result = await sendWelcomeEmail(normalizedEmail, user.displayName);
      welcome = { acceptedByBrevo: result.success, messageId: result.messageId };
    }
    return authenticatedResponse(res, user, { welcome });
  } catch (err) { return res.status(500).json({ status: 'error', message: err.message || 'Internal verification error.' }); }
}

async function handleSendWelcome(req, res) {
  try {
    const { email, displayName = 'Voyager User' } = req.body;
    if (!email || typeof email !== 'string' || !email.includes('@')) return res.status(400).json({ status: 'error', message: 'Valid email address is required.' });
    const brevoRes = await sendWelcomeEmail(email, displayName);
    return res.status(200).json({ status: 'success', message: 'Welcome email submitted for delivery.', messageId: brevoRes.messageId });
  } catch (err) { return res.status(400).json({ status: 'error', message: err.message || 'Failed to send welcome email.' }); }
}

async function handleForgotPassword(req, res) {
  const { email } = req.body;
  if (email && typeof email === 'string' && email.includes('@')) {
    try { await sendOtpEmail(email, 'PASSWORD_RESET'); } catch (_) { /* don't disclose account state */ }
  }
  return res.status(200).json({ status: 'success', message: 'If an account exists for this email, password reset instructions have been sent.' });
}

async function handleGoogleIdToken(req, res) {
  try {
    if (!googleAndroidClientId || !req.body.idToken) return res.status(400).json({ status: 'error', message: 'Android Google sign-in is not configured or incomplete.' });
    return authenticatedResponse(res, await verifyGoogleIdToken(req.body.idToken, [googleAndroidClientId, googleWindowsClientId]));
  } catch (err) { return res.status(400).json({ status: 'error', message: err.message || 'Google authentication failed.' }); }
}

async function handleGoogleAuthCode(req, res) {
  try {
    const { code, redirect_uri: redirectUri, code_verifier: codeVerifier } = req.body;
    if (!code || !redirectUri || !codeVerifier || !googleWindowsClientId) return res.status(400).json({ status: 'error', message: 'Google authorization response is incomplete.' });
    const params = new URLSearchParams({ client_id: googleWindowsClientId, code, grant_type: 'authorization_code', redirect_uri: redirectUri, code_verifier: codeVerifier });
    if (googleClientSecret) params.append('client_secret', googleClientSecret);
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: params.toString() });
    if (!tokenRes.ok) return res.status(400).json({ status: 'error', message: 'Google token exchange failed.' });
    const tokenData = await tokenRes.json();
    return authenticatedResponse(res, await verifyGoogleIdToken(tokenData.id_token, [googleWindowsClientId]));
  } catch (err) { return res.status(400).json({ status: 'error', message: err.message || 'Google authentication failed.' }); }
}

function handleValidateSession(req, res) {
  const user = readSession(req.headers.authorization?.replace(/^Bearer\s+/i, ''));
  if (!user) return res.status(401).json({ status: 'error', message: 'Session is invalid or expired.' });
  return res.status(200).json({ status: 'success', user });
}

function handleBrevoEvent(req, res) {
  const event = req.body || {};
  logDelivery('provider_event', { status: 200, messageId: event['message-id'] || event.messageId, recipient: event.email, reason: event.event });
  return res.sendStatus(204);
}

module.exports = { handleSendOtp, handleVerifyOtp, handleSendWelcome, handleForgotPassword, handleGoogleIdToken, handleGoogleAuthCode, handleValidateSession, handleBrevoEvent };
