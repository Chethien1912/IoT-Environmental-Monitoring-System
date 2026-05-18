// Model RefreshToken luu va revoke refresh token da hash de co the logout va khoa session.
const db = require('../config/database');

class RefreshToken {
  static create({ tokenHash, userId, expiresAt }) {
    const result = db
      .prepare(
        'INSERT INTO refresh_tokens (token_hash, user_id, expires_at) VALUES (?, ?, ?)'
      )
      .run(tokenHash, userId, expiresAt);

    return this.findById(result.lastInsertRowid);
  }

  static findById(id) {
    return db.prepare('SELECT * FROM refresh_tokens WHERE id = ?').get(id) || null;
  }

  static findByTokenHash(tokenHash) {
    return (
      db
        .prepare(
          `
          SELECT refresh_tokens.*, users.username, users.role, users.is_active
          FROM refresh_tokens
          JOIN users ON users.id = refresh_tokens.user_id
          WHERE token_hash = ?
          `
        )
        .get(tokenHash) || null
    );
  }

  static deleteByTokenHash(tokenHash) {
    return db.prepare('DELETE FROM refresh_tokens WHERE token_hash = ?').run(tokenHash);
  }

  static deleteByUserId(userId) {
    return db.prepare('DELETE FROM refresh_tokens WHERE user_id = ?').run(userId);
  }
}

module.exports = RefreshToken;
