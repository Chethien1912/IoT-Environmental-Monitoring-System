// Route devices cho phep tao thiet bi, xem danh sach, xem chi tiet, lich su telemetry va xoa thiet bi.
const Device = require('../models/Device');
const Telemetry = require('../models/Telemetry');
const DeviceService = require('../services/deviceService');

async function deviceRoutes(fastify) {
  fastify.post(
    '/api/devices',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const { name, type, hardwareId } = request.body || {};
      if (!name || String(name).trim().length < 2) {
        return reply.code(400).send({
          success: false,
          error: 'Ten thiet bi khong hop le.',
          code: 'VALIDATION_ERROR'
        });
      }

      let device;
      try {
        device = await DeviceService.createDevice({
          ownerId: request.user.userId,
          name: String(name).trim(),
          type: type ? String(type).trim() : 'esp32',
          hardwareId: hardwareId ? String(hardwareId).trim() : null
        });
      } catch (error) {
        const message = String(error && error.message ? error.message : error);
        if (message.includes('idx_devices_hardware_id') || message.includes('UNIQUE constraint failed: devices.hardware_id')) {
          return reply.code(409).send({
            success: false,
            error: 'Hardware ID / MAC da duoc lien ket voi thiet bi khac.',
            code: 'VALIDATION_ERROR'
          });
        }
        throw error;
      }

      return {
        success: true,
        data: {
          id: device.id,
          name: device.name,
          type: device.type,
          hardwareId: device.hardware_id,
          deviceSecret: device.deviceSecret
        },
        message: 'Luu deviceSecret ngay, khong the xem lai sau.'
      };
    }
  );

  fastify.get(
    '/api/devices',
    { preHandler: [fastify.authenticate] },
    async (request) => ({
      success: true,
      data: request.user.role === 'admin' ? Device.listAll() : Device.findByOwner(request.user.userId)
    })
  );

  fastify.get(
    '/api/devices/:id',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const device = Device.findById(request.params.id);
      if (!device) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay thiet bi.',
          code: 'NOT_FOUND'
        });
      }

      if (!DeviceService.canAccessDevice(request.user, device)) {
        return reply.code(403).send({
          success: false,
          error: 'Ban khong co quyen xem thiet bi nay.',
          code: 'UNAUTHORIZED'
        });
      }

      return {
        success: true,
        data: device
      };
    }
  );

  fastify.put(
    '/api/devices/:id/control-state',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const device = Device.findById(request.params.id);
      if (!device) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay thiet bi.',
          code: 'NOT_FOUND'
        });
      }

      if (!DeviceService.canAccessDevice(request.user, device)) {
        return reply.code(403).send({
          success: false,
          error: 'Ban khong co quyen cap nhat relay.',
          code: 'UNAUTHORIZED'
        });
      }

      const body = request.body || {};
      const updated = Device.updateControlState(device.id, {
        desiredRelay1:
          typeof body.desiredRelay1On === 'boolean' ? body.desiredRelay1On : undefined,
        desiredRelay2:
          typeof body.desiredRelay2On === 'boolean' ? body.desiredRelay2On : undefined,
        desiredRelay3:
          typeof body.desiredRelay3On === 'boolean' ? body.desiredRelay3On : undefined,
        desiredRelay4:
          typeof body.desiredRelay4On === 'boolean' ? body.desiredRelay4On : undefined
      });

      return {
        success: true,
        data: updated
      };
    }
  );

  fastify.put(
    '/api/devices/:id/automation',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const device = Device.findById(request.params.id);
      if (!device) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay thiet bi.',
          code: 'NOT_FOUND'
        });
      }

      if (!DeviceService.canAccessDevice(request.user, device)) {
        return reply.code(403).send({
          success: false,
          error: 'Ban khong co quyen cap nhat automation.',
          code: 'UNAUTHORIZED'
        });
      }

      const body = request.body || {};
      const updated = Device.updateAutomationConfig(device.id, {
        controlMode: String(body.controlMode || 'manual').trim().toLowerCase(),
        automationSettings:
          body.automationSettings && typeof body.automationSettings === 'object'
            ? body.automationSettings
            : {}
      });

      return {
        success: true,
        data: updated
      };
    }
  );

  fastify.put(
    '/api/devices/:id/hardware',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const device = Device.findById(request.params.id);
      if (!device) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay thiet bi.',
          code: 'NOT_FOUND'
        });
      }

      if (!DeviceService.canAccessDevice(request.user, device)) {
        return reply.code(403).send({
          success: false,
          error: 'Ban khong co quyen lien ket phan cung.',
          code: 'UNAUTHORIZED'
        });
      }

      const hardwareId = String((request.body || {}).hardwareId || '').trim();
      if (hardwareId) {
        const boundDevice = Device.findByHardwareId(hardwareId);
        if (boundDevice && boundDevice.id !== device.id) {
          return reply.code(409).send({
            success: false,
            error: 'Hardware ID nay da duoc lien ket voi thiet bi khac.',
            code: 'VALIDATION_ERROR'
          });
        }
      }

      return {
        success: true,
        data: Device.bindHardwareId(device.id, hardwareId || null)
      };
    }
  );

  fastify.put(
    '/api/devices/:id/rtc-sync',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const device = Device.findById(request.params.id);
      if (!device) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay thiet bi.',
          code: 'NOT_FOUND'
        });
      }

      if (!DeviceService.canAccessDevice(request.user, device)) {
        return reply.code(403).send({
          success: false,
          error: 'Ban khong co quyen dong bo RTC.',
          code: 'UNAUTHORIZED'
        });
      }

      const dateTimeIso = String((request.body || {}).dateTimeIso || '').trim();
      const parsed = new Date(dateTimeIso);
      if (!dateTimeIso || Number.isNaN(parsed.getTime())) {
        return reply.code(400).send({
          success: false,
          error: 'dateTimeIso khong hop le.',
          code: 'VALIDATION_ERROR'
        });
      }

      const rtcPayload = {
        iso: parsed.toISOString(),
        year: parsed.getFullYear(),
        month: parsed.getMonth() + 1,
        day: parsed.getDate(),
        hour: parsed.getHours(),
        minute: parsed.getMinutes(),
        second: parsed.getSeconds()
      };

      return {
        success: true,
        data: Device.queueRtcSync(device.id, rtcPayload)
      };
    }
  );

  fastify.get(
    '/api/devices/:id/telemetry',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const device = Device.findById(request.params.id);
      if (!device) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay thiet bi.',
          code: 'NOT_FOUND'
        });
      }

      if (!DeviceService.canAccessDevice(request.user, device)) {
        return reply.code(403).send({
          success: false,
          error: 'Ban khong co quyen xem telemetry.',
          code: 'UNAUTHORIZED'
        });
      }

      const { limit = 50, from } = request.query || {};
      return {
        success: true,
        data: Telemetry.findByDevice(device.id, limit, from || null)
      };
    }
  );

  fastify.delete(
    '/api/devices/:id',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const device = Device.findById(request.params.id);
      if (!device) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay thiet bi.',
          code: 'NOT_FOUND'
        });
      }

      if (!DeviceService.canAccessDevice(request.user, device)) {
        return reply.code(403).send({
          success: false,
          error: 'Ban khong co quyen xoa thiet bi.',
          code: 'UNAUTHORIZED'
        });
      }

      Device.delete(device.id);
      return {
        success: true,
        data: { id: device.id }
      };
    }
  );

  fastify.post('/internal/mqtt/auth', async (request, reply) => {
    const internalSecret = request.headers['x-internal-secret'];
    if (internalSecret !== fastify.config.internalSecret) {
      return reply.code(200).send({ result: 'deny' });
    }

    const { username, password } = request.body || {};
    if (!username || !password) {
      return reply.code(200).send({ result: 'deny' });
    }

    const allowed = await DeviceService.verifyDeviceSecret(username, password);
    return reply.code(200).send({ result: allowed ? 'allow' : 'deny' });
  });

  fastify.post('/internal/mqtt/acl', async (request, reply) => {
    const internalSecret = request.headers['x-internal-secret'];
    if (internalSecret !== fastify.config.internalSecret) {
      return reply.code(200).send({ result: 'deny' });
    }

    const { username, action, topic } = request.body || {};
    const expected = String(username || '').trim();
    const topicText = String(topic || '').trim();
    let allowed = false;

    if (action === 'publish') {
      allowed =
        topicText === `iot/${expected}/telemetry` ||
        topicText === `iot/${expected}/status` ||
        topicText === `iot/${expected}/ack`;
    } else if (action === 'subscribe') {
      allowed = topicText === `iot/${expected}/command`;
    }

    return reply.code(200).send({ result: allowed ? 'allow' : 'deny' });
  });
}

module.exports = deviceRoutes;
