const crypto = require('crypto');
const { brevoApiKey, brevoSenderEmail, brevoSenderName } = require('../config/env');

const otpStore = new Map();
const rateLimitStore = new Map();
const welcomeSentSet = new Set();

const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes
const MAX_ATTEMPTS = 5;
const COOLDOWN_MS = 60 * 1000; // 1 minute

function generateOtp() {
  const num = crypto.randomInt(100000, 1000000);
  return num.toString();
}

function hashOtp(otp) {
  return crypto.createHash('sha256').update(otp).digest('hex');
}

function recipientDomain(email) {
  return email.slice(email.lastIndexOf('@') + 1);
}

function logDelivery(event, { status, messageId, recipient, reason } = {}) {
  console.info('[BrevoDelivery]', JSON.stringify({
    timestamp: new Date().toISOString(),
    event,
    httpStatus: status,
    messageId,
    recipientDomain: recipient ? recipientDomain(recipient) : undefined,
    deliveryState: reason || (status && status >= 200 && status < 300 ? 'accepted_by_brevo' : 'failed'),
  }));
}

async function sendEmailViaBrevo({ to, subject, htmlContent }) {
  if (!brevoApiKey || !brevoSenderEmail) {
    console.warn('[BrevoService] BREVO_API_KEY or BREVO_SENDER_EMAIL is not configured.');
    return { success: false, reason: 'API_KEY_MISSING' };
  }

  try {
    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'accept': 'application/json',
        'api-key': brevoApiKey,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        sender: { name: brevoSenderName, email: brevoSenderEmail },
        to: [{ email: to }],
        subject: subject,
        htmlContent: htmlContent,
      }),
    });

    if (response.ok) {
      const data = await response.json().catch(() => ({}));
      logDelivery('submission_accepted', { status: response.status, messageId: data.messageId, recipient: to });
      return { success: true, messageId: data.messageId };
    }

    const errorBody = await response.text();
    logDelivery('submission_rejected', { status: response.status, recipient: to, reason: 'brevo_rejected' });
    console.error('[BrevoService] Brevo API send error (status code):', response.status);
    return { success: false, reason: 'BREVO_API_ERROR' };
  } catch (err) {
    logDelivery('submission_failed', { recipient: to, reason: 'network_error' });
    console.error('[BrevoService] Network error connecting to Brevo API.');
    return { success: false, reason: 'NETWORK_ERROR' };
  }
}

async function sendOtpEmail(email, purpose = 'LOGIN') {
  const normalizedEmail = email.trim().toLowerCase();
  const normalizedPurpose = purpose.trim().toUpperCase();

  const rateKey = `${normalizedEmail}_${normalizedPurpose}`;
  const lastSent = rateLimitStore.get(rateKey);
  const now = Date.now();
  if (lastSent && now - lastSent < COOLDOWN_MS) {
    throw new Error('Please wait 60 seconds before requesting a new OTP.');
  }

  const otp = generateOtp();
  const expiresAt = now + OTP_TTL_MS;

  otpStore.set(rateKey, {
    otpHash: hashOtp(otp),
    expiresAt,
    attempts: 0,
    purpose: normalizedPurpose,
  });

  rateLimitStore.set(rateKey, now);

  const purposeTitle =
    normalizedPurpose === 'REGISTRATION'
      ? 'Registration Verification'
      : normalizedPurpose === 'PASSWORD_RESET'
      ? 'Password Reset'
      : 'Login Verification';

  const htmlContent = `
    <div style="font-family: system-ui, -apple-system, sans-serif; max-width: 480px; margin: 0 auto; background: #0f172a; color: #f8fafc; padding: 32px; border-radius: 16px;">
      <h2 style="color: #38bdf8; text-align: center; margin-bottom: 24px;">Voyager Chat</h2>
      <p style="font-size: 16px; color: #cbd5e1; text-align: center;">Welcome to Voyager Chat!</p>
      <p style="font-size: 14px; color: #94a3b8; text-align: center;">Your ${purposeTitle} code is:</p>
      <div style="background: #1e293b; border-radius: 12px; padding: 20px; text-align: center; font-size: 32px; letter-spacing: 8px; font-weight: bold; color: #38bdf8; margin: 24px 0;">
        ${otp}
      </div>
      <p style="font-size: 13px; color: #94a3b8; text-align: center;">This code expires in 10 minutes. Do not share this code with anyone.</p>
      <p style="font-size: 12px; color: #64748b; text-align: center; margin-top: 24px;">If you did not request this, please ignore this email.</p>
    </div>
  `;

  const res = await sendEmailViaBrevo({
    to: normalizedEmail,
    subject: `Your Voyager Chat verification code`,
    htmlContent,
  });

  if (!res.success) {
    otpStore.delete(rateKey);
    throw new Error('Failed to deliver OTP email through Brevo.');
  }

  return res;
}

function verifyOtp(email, inputOtp, purpose = 'LOGIN') {
  const normalizedEmail = email.trim().toLowerCase();
  const normalizedPurpose = purpose.trim().toUpperCase();
  const rateKey = `${normalizedEmail}_${normalizedPurpose}`;

  const record = otpStore.get(rateKey);

  if (!record) {
    return { success: false, message: 'Invalid or expired OTP code.' };
  }

  if (Date.now() > record.expiresAt) {
    otpStore.delete(rateKey);
    return { success: false, message: 'OTP has expired. Please request a new code.' };
  }

  if (record.attempts >= MAX_ATTEMPTS) {
    otpStore.delete(rateKey);
    return { success: false, message: 'Maximum verification attempts exceeded. Request a new OTP.' };
  }

  record.attempts += 1;

  const suppliedHash = hashOtp(inputOtp.trim());
  const expectedHash = Buffer.from(record.otpHash, 'hex');
  const actualHash = Buffer.from(suppliedHash, 'hex');
  if (expectedHash.length !== actualHash.length || !crypto.timingSafeEqual(expectedHash, actualHash)) {
    return { success: false, message: 'Invalid OTP code. Please try again.' };
  }

  // Single-use deletion
  otpStore.delete(rateKey);
  return { success: true };
}

async function sendWelcomeEmail(email, displayName = 'Voyager User') {
  const normalizedEmail = email.trim().toLowerCase();

  if (welcomeSentSet.has(normalizedEmail)) {
    return { success: true, message: 'Welcome email already sent.' };
  }

  const htmlContent = `
    <div style="font-family: system-ui, -apple-system, sans-serif; max-width: 480px; margin: 0 auto; background: #0f172a; color: #f8fafc; padding: 32px; border-radius: 16px;">
      <h2 style="color: #38bdf8; text-align: center; margin-bottom: 24px;">Voyager Chat</h2>
      <h3 style="color: #f8fafc; text-align: center;">Welcome to Voyager Chat, ${displayName}!</h3>
      <p style="font-size: 14px; color: #cbd5e1; line-height: 1.6; margin-top: 16px;">
        Your account has been successfully created and your email has been verified.
      </p>
      <p style="font-size: 14px; color: #cbd5e1; line-height: 1.6;">
        You can now securely use Voyager Chat for end-to-end encrypted messaging, voice/video calls, and real-time collaboration.
      </p>
      <p style="font-size: 13px; color: #94a3b8; text-align: center; margin-top: 32px;">
        Thank you for joining us.
      </p>
    </div>
  `;

  const res = await sendEmailViaBrevo({
    to: normalizedEmail,
    subject: `Welcome to Voyager Chat!`,
    htmlContent,
  });

  if (res.success) {
    welcomeSentSet.add(normalizedEmail);
  }

  return res;
}

module.exports = {
  sendOtpEmail,
  verifyOtp,
  sendWelcomeEmail,
  sendEmailViaBrevo,
  logDelivery,
};
