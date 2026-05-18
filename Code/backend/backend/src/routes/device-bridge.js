const Device = require('../models/Device');
const Telemetry = require('../models/Telemetry');
const wsService = require('../websocket/wsServer');

function resolveDeviceByHardwareId(hardwareId) {
  const normalized = Device.normalizeHardwareId(hardwareId);
  if (!normalized) {
    return null;
  }

  return Device.findByHardwareId(normalized) || Device.findById(normalized);
}

function toNumberOrNull(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function toOptionalBool(value) {
  if (typeof value === 'boolean') {
    return value;
  }
  if (value === 1 || value === '1') {
    return true;
  }
  if (value === 0 || value === '0') {
    return false;
  }
  return undefined;
}

function sanitizeThresholdPayload(body) {
  const source = body && typeof body.thresholds === 'object' ? body.thresholds : {};
  return {
    temp:
      toNumberOrNull(source.temp)
      ?? toNumberOrNull(source.temperature)
      ?? toNumberOrNull(source.temperatureThreshold),
    humid:
      toNumberOrNull(source.humid)
      ?? toNumberOrNull(source.humidity)
      ?? toNumberOrNull(source.humidityThreshold),
    co: toNumberOrNull(source.co) ?? toNumberOrNull(source.coThreshold),
    no2: toNumberOrNull(source.no2) ?? toNumberOrNull(source.no2Threshold)
  };
}

function sanitizeTelemetryPayload(body) {
  return {
    temperatureC: toNumberOrNull(body.temperatureC),
    humidityPercent: toNumberOrNull(body.humidityPercent),
    coPpm: toNumberOrNull(body.coPpm),
    no2Ppm: toNumberOrNull(body.no2Ppm),
    dateText: String(body.dateText || ''),
    timeText: String(body.timeText || ''),
    deviceMac: String(body.deviceMac || ''),
    relay1On: toOptionalBool(body.relay1On) ?? false,
    relay2On: toOptionalBool(body.relay2On) ?? false,
    relay3On: toOptionalBool(body.relay3On) ?? false,
    buzzerOn: toOptionalBool(body.buzzerOn) ?? false,
    relay4On: toOptionalBool(body.relay4On) ?? false,
    wifiConnected: toOptionalBool(body.wifiConnected) ?? false,
    mode: String(body.mode || 'esp32'),
    controlMode: String(body.controlMode || body.mode || 'manual')
      .trim()
      .toLowerCase(),
    thresholds: sanitizeThresholdPayload(body)
  };
}

async function deviceBridgeRoutes(fastify) {
  fastify.post('/api/telemetry', async (request, reply) => {
    const payload = sanitizeTelemetryPayload(request.body || {});
    const device = resolveDeviceByHardwareId(payload.deviceMac);
    if (!device) {
      return reply.code(202).send({
        success: true,
        data: {
          registered: false
        },
        message: 'Device MAC chua duoc lien ket voi backend.'
      });
    }

    const receivedAt = new Date().toISOString();
    Telemetry.insert({
      deviceId: device.id,
      payload,
      receivedAt
    });
    const updatedDevice = Device.saveLastTelemetry(device.id, payload, receivedAt);
    wsService.broadcastTelemetry(device.id, payload);
    wsService.broadcastStatus(device.id, true);

    return {
      success: true,
      data: {
        registered: true,
        deviceId: updatedDevice.id
      }
    };
  });

  fastify.get('/api/device-state', async (request, reply) => {
    const deviceMac = String((request.query || {}).deviceMac || '').trim();
    const device = resolveDeviceByHardwareId(deviceMac);
    if (!device) {
      return reply.code(404).send({
        success: false,
        error: 'Device MAC chua duoc lien ket voi backend.',
        code: 'NOT_FOUND'
      });
    }

    return {
      success: true,
      data: {
        deviceId: device.id,
        desiredRelay1On: device.desired_relay1,
        desiredRelay2On: device.desired_relay2,
        desiredRelay3On: device.desired_relay3,
        desiredRelay4On: device.desired_relay4,
        controlMode: device.control_mode,
        automationSettings: device.automation_settings,
        pendingRtc: device.pending_rtc_payload,
        pendingRtcVersion: Number(device.pending_rtc_version || 0),
        serverTimeIso: new Date().toISOString()
      }
    };
  });

  fastify.post('/api/device-rtc-ack', async (request, reply) => {
    const body = request.body || {};
    const deviceMac = String(body.deviceMac || '').trim();
    const version = Number(body.pendingRtcVersion || 0);
    const device = resolveDeviceByHardwareId(deviceMac);
    if (!device) {
      return reply.code(404).send({
        success: false,
        error: 'Device MAC chua duoc lien ket voi backend.',
        code: 'NOT_FOUND'
      });
    }

    const updated = Device.clearRtcSync(device.id, version);
    return {
      success: true,
      data: {
        deviceId: updated ? updated.id : device.id,
        pendingRtcVersion: updated ? Number(updated.pending_rtc_version || 0) : version
      }
    };
  });

  fastify.post('/api/device-local-control', async (request, reply) => {
    const body = request.body || {};
    const deviceMac = String(body.deviceMac || '').trim();
    const device = resolveDeviceByHardwareId(deviceMac);
    if (!device) {
      return reply.code(404).send({
        success: false,
        error: 'Device MAC chua duoc lien ket voi backend.',
        code: 'NOT_FOUND'
      });
    }

    const updated = Device.syncHardwareRuntime(device.id, {
      desiredRelay1: toOptionalBool(body.relay1On),
      desiredRelay2: toOptionalBool(body.relay2On),
      desiredRelay3: toOptionalBool(body.relay3On),
      controlMode: String(body.controlMode || device.control_mode || 'manual')
        .trim()
        .toLowerCase(),
      thresholds: sanitizeThresholdPayload(body)
    });

    if (!updated) {
      return reply.code(500).send({
        success: false,
        error: 'Khong the cap nhat relay desired state.',
        code: 'INTERNAL_ERROR'
      });
    }

    wsService.broadcastStatus(updated.id, true);
    return {
      success: true,
      data: {
        deviceId: updated.id,
        desiredRelay1On: updated.desired_relay1,
        desiredRelay2On: updated.desired_relay2,
        desiredRelay3On: updated.desired_relay3,
        desiredRelay4On: updated.desired_relay4,
        controlMode: updated.control_mode,
        automationSettings: updated.automation_settings
      }
    };
  });
}

module.exports = deviceBridgeRoutes;
