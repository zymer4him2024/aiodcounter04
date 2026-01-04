const { pool } = require('./config');

/**
 * Detection Logs Model
 */
class DetectionLogsModel {
  /**
   * Insert a new detection log
   */
  static async create(data) {
    const {
      camera_id,
      timestamp,
      counts,
      total_objects,
      frames_processed,
      fps,
      runtime_seconds
    } = data;

    const query = `
      INSERT INTO detection_logs (
        camera_id, timestamp, counts, total_objects,
        frames_processed, fps, runtime_seconds
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
    `;

    const values = [
      camera_id,
      timestamp,
      JSON.stringify(counts),
      total_objects,
      frames_processed || null,
      fps || null,
      runtime_seconds || null
    ];

    const result = await pool.query(query, values);
    return result.rows[0];
  }

  /**
   * Get detection logs for a camera
   */
  static async findByCameraId(cameraId, options = {}) {
    const {
      limit = 100,
      offset = 0,
      startTime,
      endTime
    } = options;

    let query = `
      SELECT * FROM detection_logs
      WHERE camera_id = $1
    `;
    const values = [cameraId];
    let paramCount = 1;

    if (startTime) {
      paramCount++;
      query += ` AND timestamp >= $${paramCount}`;
      values.push(startTime);
    }

    if (endTime) {
      paramCount++;
      query += ` AND timestamp <= $${paramCount}`;
      values.push(endTime);
    }

    paramCount++;
    query += ` ORDER BY timestamp DESC LIMIT $${paramCount}`;
    values.push(limit);

    if (offset > 0) {
      paramCount++;
      query += ` OFFSET $${paramCount}`;
      values.push(offset);
    }

    const result = await pool.query(query, values);
    return result.rows;
  }

  /**
   * Get latest detection log for a camera
   */
  static async findLatestByCameraId(cameraId) {
    const query = `
      SELECT * FROM detection_logs
      WHERE camera_id = $1
      ORDER BY timestamp DESC
      LIMIT 1
    `;

    const result = await pool.query(query, [cameraId]);
    return result.rows[0] || null;
  }

  /**
   * Get aggregated stats for a camera
   */
  static async getStatsByCameraId(cameraId, startTime, endTime) {
    const query = `
      SELECT 
        COUNT(*) as log_count,
        SUM(total_objects) as total_objects_sum,
        AVG(total_objects) as avg_objects,
        AVG(fps) as avg_fps,
        AVG(runtime_seconds) as avg_runtime_seconds,
        MIN(timestamp) as first_log,
        MAX(timestamp) as last_log
      FROM detection_logs
      WHERE camera_id = $1
        AND timestamp >= $2
        AND timestamp <= $3
    `;

    const result = await pool.query(query, [cameraId, startTime, endTime]);
    return result.rows[0];
  }
}

/**
 * Cameras Model
 */
class CamerasModel {
  /**
   * Create or update a camera
   */
  static async upsert(data) {
    const {
      id,
      name,
      raspberry_pi_ip,
      detection_status,
      detection_started_at,
      detection_stopped_at,
      activated,
      activated_at,
      status,
      site_id
    } = data;

    const query = `
      INSERT INTO cameras (
        id, name, raspberry_pi_ip, detection_status,
        detection_started_at, detection_stopped_at,
        activated, activated_at, status, site_id
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      ON CONFLICT (id) DO UPDATE SET
        name = COALESCE(EXCLUDED.name, cameras.name),
        raspberry_pi_ip = COALESCE(EXCLUDED.raspberry_pi_ip, cameras.raspberry_pi_ip),
        detection_status = COALESCE(EXCLUDED.detection_status, cameras.detection_status),
        detection_started_at = EXCLUDED.detection_started_at,
        detection_stopped_at = EXCLUDED.detection_stopped_at,
        activated = COALESCE(EXCLUDED.activated, cameras.activated),
        activated_at = COALESCE(EXCLUDED.activated_at, cameras.activated_at),
        status = COALESCE(EXCLUDED.status, cameras.status),
        site_id = COALESCE(EXCLUDED.site_id, cameras.site_id),
        updated_at = CURRENT_TIMESTAMP
      RETURNING *
    `;

    const values = [
      id,
      name,
      raspberry_pi_ip || null,
      detection_status || 'inactive',
      detection_started_at || null,
      detection_stopped_at || null,
      activated !== undefined ? activated : false,
      activated_at || null,
      status || null,
      site_id || null
    ];

    const result = await pool.query(query, values);
    return result.rows[0];
  }

  /**
   * Get camera by ID
   */
  static async findById(cameraId) {
    const query = 'SELECT * FROM cameras WHERE id = $1';
    const result = await pool.query(query, [cameraId]);
    return result.rows[0] || null;
  }

  /**
   * Get all cameras
   */
  static async findAll(options = {}) {
    const { status, limit = 100, offset = 0 } = options;

    let query = 'SELECT * FROM cameras';
    const values = [];
    let paramCount = 0;

    if (status) {
      paramCount++;
      query += ` WHERE detection_status = $${paramCount}`;
      values.push(status);
    }

    query += ` ORDER BY updated_at DESC LIMIT $${paramCount + 1} OFFSET $${paramCount + 2}`;
    values.push(limit, offset);

    const result = await pool.query(query, values);
    return result.rows;
  }

  /**
   * Update camera detection status
   */
  static async updateDetectionStatus(cameraId, status, startedAt = null, stoppedAt = null) {
    const query = `
      UPDATE cameras
      SET 
        detection_status = $2,
        detection_started_at = $3,
        detection_stopped_at = $4,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $1
      RETURNING *
    `;

    const values = [cameraId, status, startedAt, stoppedAt];
    const result = await pool.query(query, values);
    return result.rows[0];
  }

  /**
   * Update camera last detection stats
   */
  static async updateLastDetectionStats(cameraId, stats) {
    // Note: This assumes you might want to add a last_detection_stats JSONB column
    // For now, we'll just update the updated_at timestamp
    const query = `
      UPDATE cameras
      SET updated_at = CURRENT_TIMESTAMP
      WHERE id = $1
      RETURNING *
    `;

    const result = await pool.query(query, [cameraId]);
    return result.rows[0];
  }
}

module.exports = {
  DetectionLogsModel,
  CamerasModel
};

