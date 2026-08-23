let ioInstance = null;

function initializeSocket(io) {
  ioInstance = io;

  io.on('connection', (socket) => {
    console.log(`Socket connected: ${socket.id}`);

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