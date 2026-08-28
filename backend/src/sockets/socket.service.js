const chatService = require('../services/chat.service');

let ioInstance = null;

function initializeSocket(io) {
  ioInstance = io;

  io.on('connection', (socket) => {
    console.log(`Socket connected: ${socket.id}`);

    // Client authenticates session
    socket.on('authenticate', async (data, ack) => {
      try {
        const userId = typeof data === 'string' ? data : (data?.userId || data?.id);
        if (userId) {
          socket.userId = userId;
          socket.join(`user_${userId}`);
          console.log(`Socket ${socket.id} authenticated as user_${userId}`);
          if (typeof ack === 'function') ack({ status: 'success', userId });
        } else {
          if (typeof ack === 'function') ack({ status: 'error', message: 'Missing userId' });
        }
      } catch (err) {
        if (typeof ack === 'function') ack({ status: 'error', message: err.message });
      }
    });

    // Join a conversation room
    socket.on('join_conversation', async (data, ack) => {
      try {
        const conversationId = typeof data === 'string' ? data : data?.conversationId;
        const userId = socket.userId || data?.userId;

        if (!conversationId) {
          if (typeof ack === 'function') ack({ status: 'error', message: 'Missing conversationId' });
          return;
        }

        if (userId) {
          const isMember = await chatService.isConversationMember(conversationId, userId);
          if (!isMember) {
            console.warn(`User ${userId} attempted to join conversation ${conversationId} without membership.`);
          }
        }

        const roomName = `conversation_${conversationId}`;
        socket.join(roomName);
        console.log(`Socket ${socket.id} joined room ${roomName}`);
        if (typeof ack === 'function') ack({ status: 'success', conversationId });
      } catch (err) {
        if (typeof ack === 'function') ack({ status: 'error', message: err.message });
      }
    });

    // Leave a conversation room
    socket.on('leave_conversation', (data, ack) => {
      const conversationId = typeof data === 'string' ? data : data?.conversationId;
      if (conversationId) {
        const roomName = `conversation_${conversationId}`;
        socket.leave(roomName);
        console.log(`Socket ${socket.id} left room ${roomName}`);
        if (typeof ack === 'function') ack({ status: 'success' });
      }
    });

    // Send a message over Socket.IO
    socket.on('send_message', async (data, ack) => {
      try {
        const { conversationId, senderId, content, messageType, clientMessageId, replyToMessageId } = data || {};
        const effectiveSenderId = socket.userId || senderId;

        if (!conversationId || !effectiveSenderId) {
          if (typeof ack === 'function') ack({ status: 'error', message: 'Missing conversationId or senderId' });
          return;
        }

        // 1. Save and persist message via ChatService
        const message = await chatService.createMessage({
          conversationId,
          senderId: effectiveSenderId,
          content,
          messageType,
          clientMessageId,
          replyToMessageId,
        });

        // 2. Broadcast new_message to conversation room
        const roomName = `conversation_${conversationId}`;
        io.to(roomName).emit('new_message', message);
        io.to(roomName).emit('message_received', message);

        // Acknowledge sender
        if (typeof ack === 'function') {
          ack({ status: 'success', message });
        }
      } catch (err) {
        console.error('Error handling socket send_message:', err.message);
        if (typeof ack === 'function') {
          ack({ status: 'error', message: err.message || 'Failed to send message' });
        }
      }
    });

    // Typing indicators
    socket.on('typing_start', (data) => {
      const { conversationId, userId, displayName } = data || {};
      if (conversationId) {
        socket.to(`conversation_${conversationId}`).emit('user_typing', {
          conversationId,
          userId: userId || socket.userId,
          displayName,
        });
      }
    });

    socket.on('typing_stop', (data) => {
      const { conversationId, userId } = data || {};
      if (conversationId) {
        socket.to(`conversation_${conversationId}`).emit('user_stop_typing', {
          conversationId,
          userId: userId || socket.userId,
        });
      }
    });

    socket.on('disconnect', (reason) => {
      console.log(`Socket disconnected: ${socket.id} (${reason})`);
    });
  });
}

function getIO() {
  if (!ioInstance) {
    throw new Error('Socket.IO has not been initialized');
  }
  return ioInstance;
}

module.exports = {
  initializeSocket,
  getIO,
};