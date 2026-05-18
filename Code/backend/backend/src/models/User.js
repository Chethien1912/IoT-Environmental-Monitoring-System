// Model User gom cac ham dong bo de doc/ghi bang users va tranh tra ve password_hash ra ngoai API.
const db = require('../config/database');

class User {
  static sanitize(row) {
    if (!row) {
      return null;
    }

    return {
      id: row.id,
      username: row.username,
      role: row.role,
      is_active: Boolean(row.is_active),
      created_at: row.created_at
    };
  }

  static findById(id) {
    return db.prepare('SELECT * FROM users WHERE id = ?').get(id) || null;
  }

  static findByUsername(username) {
    return db.prepare('SELECT * FROM users WHERE username = ?').get(username) || null;
  }

  static create({ username, passwordHash, role = 'user', isActive = true }) {
    const result = db
      .prepare(
        'INSERT INTO users (username, password_hash, role, is_active) VALUES (?, ?, ?, ?)'
      )
      .run(username, passwordHash, role, isActive ? 1 : 0);

    return this.findById(result.lastInsertRowid);
  }

  static update(id, { username, role, isActive, passwordHash }) {
    const existing = this.findById(id);
    if (!existing) {
      return null;
    }

    db.prepare(
      `
      UPDATE users
      SET username = ?, role = ?, is_active = ?, password_hash = ?
      WHERE id = ?
      `
    ).run(
      username ?? existing.username,
      role ?? existing.role,
      typeof isActive === 'boolean' ? (isActive ? 1 : 0) : existing.is_active,
      passwordHash ?? existing.password_hash,
      id
    );

    return this.findById(id);
  }

  static delete(id) {
    return db.prepare('DELETE FROM users WHERE id = ?').run(id);
  }

  static list() {
    return db.prepare('SELECT * FROM users ORDER BY id ASC').all();
  }
}

module.exports = User;
