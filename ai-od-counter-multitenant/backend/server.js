const express = require('express');
const cors = require('cors');
const http = require('http');
const socketIo = require('socket.io');
require('dotenv').config();

// Initialize PostgreSQL database (optional)
let dbInitialized = false;
if (process.env.USE_POSTGRES === 'true' || process.env.DATABASE_URL) {
  try {
    const { testConnection, initializeSchema } = require('./database/config');
    (async () => {
      const connected = await testConnection();
      if (connected) {
        await initializeSchema();
        dbInitialized = true;
        console.log('✅ PostgreSQL database ready');
      }
    })();
  } catch (error) {
    console.warn('⚠️  PostgreSQL not configured, using Firestore only:', error.message);
  }
}

const app = express();
const server = http.createServer(app);

// Initialize Socket.IO for real-time updates
const io = socketIo(server, {
  cors: {
    origin: process.env.FRONTEND_URL || '*',
    methods: ['GET', 'POST']
  }
});

// Make io available globally for controllers
global.io = io;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Routes
const cameraRoutes = require('./routes/cameraRoutes');
app.use('/api', cameraRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'aiod-counter-backend'
  });
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id}`);
  
  // Join camera room
  socket.on('join_camera', (cameraId) => {
    socket.join(`camera_${cameraId}`);
    console.log(`Client ${socket.id} joined camera_${cameraId}`);
  });
  
  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    success: false,
    error: err.message || 'Internal server error'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
});

const PORT = process.env.PORT || 3001;

server.listen(PORT, () => {
  console.log(`🚀 Backend server running on port ${PORT}`);
  console.log(`📡 Socket.IO enabled for real-time updates`);
  console.log(`🔗 Health check: http://localhost:${PORT}/health`);
});

