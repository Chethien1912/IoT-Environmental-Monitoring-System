// File nay nap bien moi truong, dat gia tri mac dinh an toan va xuat ra mot object de toan bo app dung chung.
const path = require('path');
const dotenv = require('dotenv');

dotenv.config();

function readString(name, fallback = '') {
  const value = process.env[name];
  return typeof value === 'string' && value.trim() ? value.trim() : fallback;
}

function readInt(name, fallback) {
  const value = Number.parseInt(process.env[name] || '', 10);
  return Number.isFinite(value) ? value : fallback;
}

const env = {
  port: readInt('PORT', 3000),
  nodeEnv: readString('NODE_ENV', 'development'),
  jwtSecret: readString('JWT_SECRET', 'change_this_secret_key_min_32_chars'),
  jwtAccessExpiresIn: readString('JWT_ACCESS_EXPIRES_IN', '1h'),
  refreshTokenTtlDays: readInt('REFRESH_TOKEN_TTL_DAYS', 7),
  mqttUrl: readString('MQTT_URL', 'mqtt://localhost:1883'),
  mqttUsername: readString('MQTT_USERNAME', 'backend'),
  mqttPassword: readString('MQTT_PASSWORD', 'backend_secret'),
  dbPath: path.resolve(process.cwd(), readString('DB_PATH', './data/iot.db')),
  internalSecret: readString('INTERNAL_SECRET', 'random_secret_string'),
  corsOrigin: readString('CORS_ORIGIN', '*')
};

if (env.jwtSecret.length < 32) {
  throw new Error('JWT_SECRET phai dai toi thieu 32 ky tu.');
}

module.exports = env;
