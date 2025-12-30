-- Detection logs table
CREATE TABLE IF NOT EXISTS detection_logs (
  id SERIAL PRIMARY KEY,
  camera_id VARCHAR(255) NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  counts JSONB NOT NULL,
  total_objects INTEGER NOT NULL,
  frames_processed INTEGER,
  fps DECIMAL(10,2),
  runtime_seconds DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast queries
CREATE INDEX IF NOT EXISTS idx_detection_logs_camera_timestamp 
  ON detection_logs(camera_id, timestamp DESC);

-- Camera status table
CREATE TABLE IF NOT EXISTS cameras (
  id VARCHAR(255) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  raspberry_pi_ip VARCHAR(50),
  detection_status VARCHAR(20) DEFAULT 'inactive',
  detection_started_at TIMESTAMP,
  detection_stopped_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for camera queries
CREATE INDEX IF NOT EXISTS idx_cameras_status 
  ON cameras(detection_status);

CREATE INDEX IF NOT EXISTS idx_cameras_updated_at 
  ON cameras(updated_at DESC);

