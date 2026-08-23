require('dotenv').config();

const http = require('http');
const { Server } = require('socket.io');

const app = require('./app');
const { port } = require('./config/env');
const { initializeSocket } = require('./sockets/socket.service');

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

initializeSocket(io);

server.listen(port, () => {
  console.log(`Voyager Chat backend running on port ${port}`);
});