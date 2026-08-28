const chatService = require('../services/chat.service');

async function handleGetConversations(req, res) {
  try {
    const userId = req.query.userId || req.query.user_id;
    if (!userId) return res.status(400).json({ status: 'error', message: 'User ID is required.' });

    const conversations = await chatService.getUserConversations(userId);
    return res.status(200).json({ status: 'success', conversations });
  } catch (err) {
    return res.status(500).json({ status: 'error', message: err.message || 'Failed to fetch conversations.' });
  }
}

async function handleCreateDirectConversation(req, res) {
  try {
    const { userId, otherUserId } = req.body;
    if (!userId || !otherUserId) {
      return res.status(400).json({ status: 'error', message: 'Both userId and otherUserId are required.' });
    }

    const conversation = await chatService.createDirectConversation(userId, otherUserId);
    return res.status(200).json({ status: 'success', conversation });
  } catch (err) {
    return res.status(400).json({ status: 'error', message: err.message || 'Failed to create conversation.' });
  }
}

async function handleGetMessages(req, res) {
  try {
    const conversationId = req.params.id;
    const userId = req.query.userId || req.query.user_id;

    if (!conversationId) {
      return res.status(400).json({ status: 'error', message: 'Conversation ID is required.' });
    }

    if (userId) {
      const isMember = await chatService.isConversationMember(conversationId, userId);
      if (!isMember) {
        return res.status(403).json({ status: 'error', message: 'Forbidden: You are not a member of this conversation.' });
      }
    }

    const messages = await chatService.getConversationMessages(conversationId);
    return res.status(200).json({ status: 'success', messages });
  } catch (err) {
    return res.status(500).json({ status: 'error', message: err.message || 'Failed to fetch messages.' });
  }
}

async function handleSendMessage(req, res) {
  try {
    const conversationId = req.params.id;
    const { senderId, content, messageType, clientMessageId, replyToMessageId } = req.body;

    if (!conversationId || !senderId) {
      return res.status(400).json({ status: 'error', message: 'Conversation ID and senderId are required.' });
    }

    const message = await chatService.createMessage({
      conversationId,
      senderId,
      content,
      messageType,
      clientMessageId,
      replyToMessageId,
    });

    return res.status(201).json({ status: 'success', message });
  } catch (err) {
    return res.status(400).json({ status: 'error', message: err.message || 'Failed to send message.' });
  }
}

module.exports = {
  handleGetConversations,
  handleCreateDirectConversation,
  handleGetMessages,
  handleSendMessage,
};
