// Route users va profile cho phep admin quan ly tai khoan va user tu doi mat khau cua minh.
const bcrypt = require('bcryptjs');

const User = require('../models/User');

function isValidUsername(value) {
  return /^[A-Za-z0-9_]{3,30}$/.test(value);
}

function isValidPassword(value) {
  return typeof value === 'string' && value.length >= 8 && /[A-Z]/.test(value) && /\d/.test(value);
}

async function userRoutes(fastify) {
  fastify.get(
    '/api/users',
    { preHandler: [fastify.authenticate, fastify.requireAdmin] },
    async () => ({
      success: true,
      data: User.list().map((item) => User.sanitize(item))
    })
  );

  fastify.post(
    '/api/users',
    { preHandler: [fastify.authenticate, fastify.requireAdmin] },
    async (request, reply) => {
      const { username, password, role } = request.body || {};

      if (!isValidUsername(username) || !isValidPassword(password) || !['user', 'admin'].includes(role)) {
        return reply.code(400).send({
          success: false,
          error: 'Du lieu tao user khong hop le.',
          code: 'VALIDATION_ERROR'
        });
      }

      if (User.findByUsername(username)) {
        return reply.code(409).send({
          success: false,
          error: 'Username da ton tai.',
          code: 'VALIDATION_ERROR'
        });
      }

      const passwordHash = await bcrypt.hash(password, 10);
      const user = User.create({ username, passwordHash, role });
      return {
        success: true,
        data: User.sanitize(user)
      };
    }
  );

  fastify.put(
    '/api/users/:id',
    { preHandler: [fastify.authenticate, fastify.requireAdmin] },
    async (request, reply) => {
      const targetId = Number(request.params.id);
      if (request.user.userId === targetId) {
        return reply.code(400).send({
          success: false,
          error: 'Khong duoc sua chinh minh qua route admin.',
          code: 'VALIDATION_ERROR'
        });
      }

      const existing = User.findById(targetId);
      if (!existing) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay user.',
          code: 'NOT_FOUND'
        });
      }

      const { username, role, is_active: isActive } = request.body || {};
      if (username && !isValidUsername(username)) {
        return reply.code(400).send({
          success: false,
          error: 'username khong hop le.',
          code: 'VALIDATION_ERROR'
        });
      }

      if (role && !['user', 'admin'].includes(role)) {
        return reply.code(400).send({
          success: false,
          error: 'role khong hop le.',
          code: 'VALIDATION_ERROR'
        });
      }

      const updated = User.update(targetId, {
        username,
        role,
        isActive
      });

      return {
        success: true,
        data: User.sanitize(updated)
      };
    }
  );

  fastify.put(
    '/api/users/:id/reset-password',
    { preHandler: [fastify.authenticate, fastify.requireAdmin] },
    async (request, reply) => {
      const targetId = Number(request.params.id);
      const existing = User.findById(targetId);
      if (!existing) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay user.',
          code: 'NOT_FOUND'
        });
      }

      const { newPassword } = request.body || {};
      if (!isValidPassword(newPassword)) {
        return reply.code(400).send({
          success: false,
          error: 'Mat khau moi khong hop le.',
          code: 'VALIDATION_ERROR'
        });
      }

      const passwordHash = await bcrypt.hash(newPassword, 10);
      User.update(targetId, { passwordHash });

      return {
        success: true,
        data: { id: targetId }
      };
    }
  );

  fastify.delete(
    '/api/users/:id',
    { preHandler: [fastify.authenticate, fastify.requireAdmin] },
    async (request, reply) => {
      const targetId = Number(request.params.id);
      if (request.user.userId === targetId) {
        return reply.code(400).send({
          success: false,
          error: 'Khong duoc xoa chinh minh.',
          code: 'VALIDATION_ERROR'
        });
      }

      const existing = User.findById(targetId);
      if (!existing) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay user.',
          code: 'NOT_FOUND'
        });
      }

      User.delete(targetId);
      return {
        success: true,
        data: { id: targetId }
      };
    }
  );

  fastify.get(
    '/api/profile',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const user = User.findById(request.user.userId);
      if (!user) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay user.',
          code: 'NOT_FOUND'
        });
      }

      return {
        success: true,
        data: User.sanitize(user)
      };
    }
  );

  fastify.put(
    '/api/profile/password',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const { currentPassword, newPassword } = request.body || {};
      if (!currentPassword || !isValidPassword(newPassword)) {
        return reply.code(400).send({
          success: false,
          error: 'Du lieu doi mat khau khong hop le.',
          code: 'VALIDATION_ERROR'
        });
      }

      const user = User.findById(request.user.userId);
      if (!user) {
        return reply.code(404).send({
          success: false,
          error: 'Khong tim thay user.',
          code: 'NOT_FOUND'
        });
      }

      const matched = await bcrypt.compare(currentPassword, user.password_hash);
      if (!matched) {
        return reply.code(401).send({
          success: false,
          error: 'Mat khau hien tai khong dung.',
          code: 'INVALID_CREDENTIALS'
        });
      }

      const passwordHash = await bcrypt.hash(newPassword, 10);
      User.update(user.id, { passwordHash });

      return {
        success: true,
        data: { id: user.id }
      };
    }
  );
}

module.exports = userRoutes;
