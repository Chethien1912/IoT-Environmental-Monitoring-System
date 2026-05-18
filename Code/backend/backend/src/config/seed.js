// File nay tao tai khoan admin mac dinh de co the dang nhap backend ngay tu lan dau.
const bcrypt = require('bcryptjs');

const db = require('./database');

const username = 'admin';
const password = 'Admin@123';

const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);

if (!existing) {
  const passwordHash = bcrypt.hashSync(password, 10);
  db.prepare(
    'INSERT INTO users (username, password_hash, role, is_active) VALUES (?, ?, ?, ?)'
  ).run(username, passwordHash, 'admin', 1);
  console.log('Da tao tai khoan admin mac dinh: admin / Admin@123');
} else {
  console.log('Tai khoan admin da ton tai, bo qua seed.');
}
