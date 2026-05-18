// Model Telemetry luu lich su sensor va co ham cleanup de giu lai du lieu 7 ngay.
const db = require('../config/database');

class Telemetry {
  static insert({ deviceId, payload, receivedAt = null }) {
    const result = db
      .prepare(
        `
        INSERT INTO telemetry (device_id, payload, received_at)
        VALUES (?, ?, COALESCE(?, datetime('now')))
        `
      )
      .run(deviceId, JSON.stringify(payload), receivedAt);

    return db.prepare('SELECT * FROM telemetry WHERE id = ?').get(result.lastInsertRowid);
  }

  static findByDevice(deviceId, limit = 50, fromTime = null) {
    const safeLimit = Math.max(1, Math.min(Number(limit) || 50, 200));

    const rows = fromTime
      ? db
          .prepare(
            `
            SELECT * FROM telemetry
            WHERE device_id = ? AND received_at >= ?
            ORDER BY received_at DESC
            LIMIT ?
            `
          )
          .all(deviceId, fromTime, safeLimit)
      : db
          .prepare(
            `
            SELECT * FROM telemetry
            WHERE device_id = ?
            ORDER BY received_at DESC
            LIMIT ?
            `
          )
          .all(deviceId, safeLimit);

    return rows.map((row) => ({
      ...row,
      payload: JSON.parse(row.payload)
    }));
  }

  static cleanup7days() {
    return db
      .prepare("DELETE FROM telemetry WHERE received_at < datetime('now', '-7 days')")
      .run();
  }
}

module.exports = Telemetry;
