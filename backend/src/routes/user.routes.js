const express = require('express');
const { handleSearchUsers, handleGetUserProfile, handleUpsertProfile } = require('../controllers/user.controller');

const router = express.Router();

router.get('/search', handleSearchUsers);
router.get('/profile/:id', handleGetUserProfile);
router.post('/profile', handleUpsertProfile);

module.exports = router;
