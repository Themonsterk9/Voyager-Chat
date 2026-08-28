require('dotenv').config();

const http = require('http');
const { Server } = require('socket.io');

const app = require('./app');
const { port, brevoApiKey, brevoSenderEmail, googleClientSecret, sessionSecret } = require('./config/env');
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
  console.info(`BREVO_API_KEY = ${brevoApiKey ? 'LOADED' : 'MISSING'}`);
  console.info(`BREVO_SENDER_EMAIL = ${brevoSenderEmail ? 'LOADED' : 'MISSING'}`);
  console.info(`GOOGLE_CLIENT_SECRET = ${googleClientSecret ? 'LOADED' : 'MISSING'}`);
  console.info(`SESSION_SECRET = ${sessionSecret ? 'LOADED' : 'MISSING'}`);
});
