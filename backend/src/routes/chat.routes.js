const express = require('express');
const {
  handleGetConversations,
  handleCreateDirectConversation,
  handleGetMessages,
  handleSendMessage,
} = require('../controllers/chat.controller');

const router = express.Router();

router.get('/conversations', handleGetConversations);
router.post('/conversations/direct', handleCreateDirectConversation);
router.get('/conversations/:id/messages', handleGetMessages);
router.post('/conversations/:id/messages', handleSendMessage);

module.exports = router;
