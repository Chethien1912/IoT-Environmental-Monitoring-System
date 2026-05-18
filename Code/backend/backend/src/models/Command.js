// Model Command luu lenh gui xuong ESP32, cap nhat sent/acked/failed va truy van lich su lenh.
const db = require('../config/database');

class Command {
  static mapRow(row) {
    if (!row) {
      return null;
    }

    return {
      ...row,
      payload: JSON.parse(row.payload)
    };
  }

  static create({ deviceId, payload, createdBy }) {
    const result = db
      .prepare(
        `
        INSERT INTO commands (device_id, payload, created_by)
        VALUES (?, ?, ?)
        `
      )
      .run(deviceId, JSON.stringify(payload), createdBy ?? null);

    return this.findById(result.lastInsertRowid);
  }

  static findById(id) {
    const row = db.prepare('SELECT * FROM commands WHERE id = ?').get(id);
    return this.mapRow(row);
  }

  static updateStatus(id, status, timestampField = null, timestampValue = null) {
    const allowedFields = new Set(['sent_at', 'acked_at']);
    if (timestampField && allowedFields.has(timestampField)) {
      db.prepare(
        `UPDATE commands SET status = ?, ${timestampField} = ? WHERE id = ?`
      ).run(status, timestampValue, id);
    } else {
      db.prepare('UPDATE commands SET status = ? WHERE id = ?').run(status, id);
    }

    return this.findById(id);
  }

  static findPending(deviceId) {
    const rows = db
      .prepare(
        `
        SELECT * FROM commands
        WHERE device_id = ? AND status = 'pending'
        ORDER BY created_at ASC
        `
      )
      .all(deviceId);

    return rows.map((row) => this.mapRow(row));
  }

  static findByDevice(deviceId, { status = null, limit = 20 } = {}) {
    const safeLimit = Math.max(1, Math.min(Number(limit) || 20, 100));
    const rows = status
      ? db
          .prepare(
            `
            SELECT * FROM commands
            WHERE device_id = ? AND status = ?
            ORDER BY created_at DESC
            LIMIT ?
            `
          )
          .all(deviceId, status, safeLimit)
      : db
          .prepare(
            `
            SELECT * FROM commands
            WHERE device_id = ?
            ORDER BY created_at DESC
            LIMIT ?
            `
          )
          .all(deviceId, safeLimit);

    return rows.map((row) => this.mapRow(row));
  }
}

module.exports = Command;
