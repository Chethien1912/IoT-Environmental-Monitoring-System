// File nay khoi tao ket noi SQLite, tao schema bang IF NOT EXISTS va xuat ra singleton database.
const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');

const env = require('./env');

const dbDirectory = path.dirname(env.dbPath);
if (!fs.existsSync(dbDirectory)) {
  fs.mkdirSync(dbDirectory, { recursive: true });
}

const db = new Database(env.dbPath);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user',
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  token_hash TEXT UNIQUE NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'esp32',
  owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_secret_hash TEXT NOT NULL,
  hardware_id TEXT,
  is_online INTEGER NOT NULL DEFAULT 0,
  desired_relay1 INTEGER NOT NULL DEFAULT 0,
  desired_relay2 INTEGER NOT NULL DEFAULT 0,
  desired_relay3 INTEGER NOT NULL DEFAULT 0,
  desired_relay4 INTEGER NOT NULL DEFAULT 0,
  control_mode TEXT NOT NULL DEFAULT 'manual',
  automation_settings TEXT,
  pending_rtc_payload TEXT,
  pending_rtc_version INTEGER NOT NULL DEFAULT 0,
  last_seen TEXT,
  last_telemetry TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS telemetry (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  payload TEXT NOT NULL,
  received_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_telemetry_device_time
ON telemetry(device_id, received_at DESC);

CREATE TABLE IF NOT EXISTS commands (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  payload TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  sent_at TEXT,
  acked_at TEXT,
  created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
`);

function hasColumn(tableName, columnName) {
  const rows = db.prepare(`PRAGMA table_info(${tableName})`).all();
  return rows.some((row) => row.name === columnName);
}

function ensureColumn(tableName, columnName, definitionSql) {
  if (!hasColumn(tableName, columnName)) {
    db.exec(`ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${definitionSql}`);
  }
}

ensureColumn('devices', 'hardware_id', 'TEXT');
ensureColumn('devices', 'desired_relay1', 'INTEGER NOT NULL DEFAULT 0');
ensureColumn('devices', 'desired_relay2', 'INTEGER NOT NULL DEFAULT 0');
ensureColumn('devices', 'desired_relay3', 'INTEGER NOT NULL DEFAULT 0');
ensureColumn('devices', 'desired_relay4', 'INTEGER NOT NULL DEFAULT 0');
ensureColumn('devices', 'control_mode', "TEXT NOT NULL DEFAULT 'manual'");
ensureColumn('devices', 'automation_settings', 'TEXT');
ensureColumn('devices', 'pending_rtc_payload', 'TEXT');
ensureColumn('devices', 'pending_rtc_version', 'INTEGER NOT NULL DEFAULT 0');

db.exec(`
CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_hardware_id
ON devices(hardware_id)
WHERE hardware_id IS NOT NULL AND hardware_id != '';
`);

module.exports = db;
