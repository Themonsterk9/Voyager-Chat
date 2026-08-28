const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();

app.use(helmet());
app.use(morgan('dev'));

app.use(
  cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  })
);

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const chatRoutes = require('./routes/chat.routes');

app.get('/health', (req, res) => {
  res.status(200).json({
    name: 'Voyager Chat Backend',
    status: 'OK',
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/chat', chatRoutes);

app.use((req, res) => {
  res.status(404).json({
    status: 'error',
    message: 'Route not found',
    path: req.originalUrl,
  });
});

app.use((err, req, res, next) => {
  console.error('Unhandled server error:', err);

  res.status(err.status || 500).json({
    status: 'error',
    message: err.message || 'Internal server error',
  });
});

module.exports = app;