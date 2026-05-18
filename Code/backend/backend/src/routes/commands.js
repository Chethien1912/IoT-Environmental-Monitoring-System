// Route commands ghi lenh xuong DB, publish xuong MQTT neu device dang online va cho phep xem lich su lenh.
const Command = require('../models/Command');
const Device = require('../models/Device');
const DeviceService = require('../services/deviceService');
const CommandService = require('../services/commandService');

async function commandRoutes(fastify) {
  fastify.post(
    '/api/devices/:id/command',
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
          error: 'Ban khong co quyen gui lenh.',
          code: 'UNAUTHORIZED'
        });
      }

      const { action, params = {} } = request.body || {};
      if (!action || typeof action !== 'string') {
        return reply.code(400).send({
          success: false,
          error: 'action la bat buoc.',
          code: 'VALIDATION_ERROR'
        });
      }

      const command = await CommandService.createAndDispatch({
        deviceId: device.id,
        action,
        params: typeof params === 'object' && params ? params : {},
        userId: request.user.userId,
        mqttService: fastify.mqttService
      });

      return {
        success: true,
        data: {
          commandId: command.id,
          status: command.status,
          message:
            command.status === 'sent'
              ? 'Da day lenh xuong broker.'
              : 'Thiet bi dang offline, lenh duoc xep hang.'
        }
      };
    }
  );

  fastify.get(
    '/api/devices/:id/commands',
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
          error: 'Ban khong co quyen xem lich su lenh.',
          code: 'UNAUTHORIZED'
        });
      }

      const { status, limit = 20 } = request.query || {};
      return {
        success: true,
        data: Command.findByDevice(device.id, { status: status || null, limit })
      };
    }
  );
}

module.exports = commandRoutes;
