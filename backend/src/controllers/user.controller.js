const chatService = require('../services/chat.service');

async function handleSearchUsers(req, res) {
  try {
    const query = req.query.q || req.query.query || '';
    const excludeUserId = req.query.excludeUserId || req.query.exclude_user_id || null;

    const users = await chatService.searchUsers(query, excludeUserId);
    return res.status(200).json({ status: 'success', users });
  } catch (err) {
    return res.status(400).json({ status: 'error', message: err.message || 'Failed to search users.' });
  }
}

async function handleGetUserProfile(req, res) {
  try {
    const userId = req.params.id;
    if (!userId) return res.status(400).json({ status: 'error', message: 'User ID is required.' });

    const profile = await chatService.getUserProfile(userId);
    if (!profile) return res.status(404).json({ status: 'error', message: 'User profile not found.' });

    return res.status(200).json({ status: 'success', profile });
  } catch (err) {
    return res.status(500).json({ status: 'error', message: err.message || 'Failed to fetch user profile.' });
  }
}

async function handleUpsertProfile(req, res) {
  try {
    const profileData = req.body || {};
    if (!profileData.id) return res.status(400).json({ status: 'error', message: 'Profile ID is required.' });

    const profile = await chatService.upsertProfile(profileData);
    return res.status(200).json({ status: 'success', profile });
  } catch (err) {
    return res.status(400).json({ status: 'error', message: err.message || 'Failed to update profile.' });
  }
}

module.exports = {
  handleSearchUsers,
  handleGetUserProfile,
  handleUpsertProfile,
};
