# PostgreSQL Database Setup

This directory contains the PostgreSQL database schema and models for the AIOD Counter backend.

## Setup

### 1. Install PostgreSQL

**macOS:**
```bash
brew install postgresql@14
brew services start postgresql@14
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql
```

### 2. Create Database

```bash
# Connect to PostgreSQL
sudo -u postgres psql

# Create database and user
CREATE DATABASE aiodcounter;
CREATE USER aiodcounter_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE aiodcounter TO aiodcounter_user;

# Exit
\q
```

### 3. Run Schema Migration

```bash
# Using psql
psql -U aiodcounter_user -d aiodcounter -f database/schema.sql

# Or using connection string
psql $DATABASE_URL -f database/schema.sql
```

### 4. Configure Environment Variables

Add to your `.env` file:

```env
# PostgreSQL Configuration
USE_POSTGRES=true
DATABASE_URL=postgresql://aiodcounter_user:your_password@localhost:5432/aiodcounter

# OR individual settings:
DB_HOST=localhost
DB_PORT=5432
DB_NAME=aiodcounter
DB_USER=aiodcounter_user
DB_PASSWORD=your_password
DB_SSL=false
```

## Tables

### `detection_logs`
Stores detection count data from cameras:
- `id`: Auto-increment primary key
- `camera_id`: Camera identifier (VARCHAR)
- `timestamp`: Detection timestamp
- `counts`: JSONB object with detection counts
- `total_objects`: Total objects detected
- `frames_processed`: Number of frames processed
- `fps`: Frames per second
- `runtime_seconds`: Runtime in seconds
- `created_at`: Record creation timestamp

### `cameras`
Stores camera configuration and status:
- `id`: Camera ID (PRIMARY KEY)
- `name`: Camera name
- `raspberry_pi_ip`: Raspberry Pi IP address
- `detection_status`: Status ('active', 'inactive', etc.)
- `detection_started_at`: When detection started
- `detection_stopped_at`: When detection stopped
- `created_at`: Camera creation timestamp
- `updated_at`: Last update timestamp

## Usage

The database models are available in `database/models.js`:

```javascript
const { DetectionLogsModel, CamerasModel } = require('./database/models');

// Create detection log
await DetectionLogsModel.create({
  camera_id: 'camera-123',
  timestamp: new Date(),
  counts: { person: 5, car: 2 },
  total_objects: 7
});

// Get camera
const camera = await CamerasModel.findById('camera-123');
```

## Dual Storage Mode

The backend supports both PostgreSQL and Firestore:
- If `USE_POSTGRES=true` or `DATABASE_URL` is set, PostgreSQL will be used
- Otherwise, Firestore will be used
- Both can be used simultaneously for redundancy

