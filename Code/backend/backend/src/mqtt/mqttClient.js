// MQTT service ket noi broker, nghe telemetry/status/ack tu ESP32, cap nhat DB va broadcast cho app.
const mqtt = require('mqtt');

const Device = require('../models/Device');
const Telemetry = require('../models/Telemetry');
const Command = require('../models/Command');

let client = null;
let connected = false;
let wsServiceRef = null;
let heartbeatTimer = null;

function nowIso() {
  return new Date().toISOString();
}

function handleTelemetry(deviceId, payload) {
  const device = Device.findById(deviceId);
  if (!device) {
    return;
  }

  const receivedAt = nowIso();
  Telemetry.insert({ deviceId, payload, receivedAt });
  Device.saveLastTelemetry(deviceId, payload, receivedAt);
  wsServiceRef.broadcastTelemetry(deviceId, payload);
  if (!device.is_online) {
    wsServiceRef.broadcastStatus(deviceId, true);
  }
}

function handleStatus(deviceId, payload) {
  const device = Device.findById(deviceId);
  if (!device) {
    return;
  }

  const isOnline = String(payload).trim().toLowerCase() === 'online';
  Device.setOnline(deviceId, isOnline, isOnline ? nowIso() : device.last_seen);
  wsServiceRef.broadcastStatus(deviceId, isOnline);
}

function handleAck(deviceId, payload) {
  const device = Device.findById(deviceId);
  if (!device) {
    return;
  }

  const commandId = Number(payload.commandId);
  if (!Number.isFinite(commandId)) {
    return;
  }

  const status = payload.status === 'success' ? 'acked' : 'failed';
  Command.updateStatus(commandId, status, 'acked_at', nowIso());
  wsServiceRef.broadcastCommandAck(deviceId, commandId, status);
}

function setupHeartbeat() {
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
  }

  heartbeatTimer = setInterval(() => {
    const cutoff = new Date(Date.now() - 90_000).toISOString();
    const staleDevices = Device.listStaleOnline(cutoff);
    for (const deviceId of staleDevices) {
      Device.setOnline(deviceId, false);
      wsServiceRef.broadcastStatus(deviceId, false);
    }
  }, 30_000);
}

function connect({ mqttUrl, username, password, wsService }) {
  wsServiceRef = wsService;
  client = mqtt.connect(mqttUrl, {
    clientId: `backend_${Math.random().toString(16).slice(2, 10)}`,
    username,
    password,
    reconnectPeriod: 3000
  });

  client.on('connect', () => {
    connected = true;
    client.subscribe(['iot/+/telemetry', 'iot/+/status', 'iot/+/ack'], { qos: 1 });
  });

  client.on('close', () => {
    connected = false;
  });

  client.on('error', () => {
    connected = false;
  });

  client.on('message', (topic, rawPayload) => {
    const parts = topic.split('/');
    if (parts.length !== 3 || parts[0] !== 'iot') {
      return;
    }

    const deviceId = parts[1];
    const channel = parts[2];
    const textPayload = rawPayload.toString('utf8');

    if (channel === 'telemetry') {
      try {
        const payload = JSON.parse(textPayload);
        handleTelemetry(deviceId, payload);
      } catch (_) {
        return;
      }
      return;
    }

    if (channel === 'status') {
      handleStatus(deviceId, textPayload);
      return;
    }

    if (channel === 'ack') {
      try {
        const payload = JSON.parse(textPayload);
        handleAck(deviceId, payload);
      } catch (_) {
        return;
      }
    }
  });

  setupHeartbeat();
}

async function publishCommand(deviceId, commandObj) {
  if (!client || !connected) {
    return false;
  }

  await new Promise((resolve, reject) => {
    client.publish(
      `iot/${deviceId}/command`,
      JSON.stringify(commandObj),
      { qos: 1, retain: false },
      (error) => (error ? reject(error) : resolve())
    );
  });
  return true;
}

function disconnect() {
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }

  if (client) {
    client.end(true);
  }
  connected = false;
}

function isConnected() {
  return connected;
}

module.exports = {
  connect,
  publishCommand,
  disconnect,
  isConnected
};
