// Plugin auth dang ky JWT va cung cap hai preHandler de bao ve route user thuong va admin.
// File này cấu hình JWT và tạo middleware xác thực.
const fp = require('fastify-plugin');
const jwt = require('@fastify/jwt');
const env = require('../config/env');

async function authPlugin(fastify) {
  await fastify.register(jwt, {
    secret: env.jwtSecret
  });

  fastify.decorate('authenticate', async function authenticate(request, reply) {
    try {
      await request.jwtVerify();
    } catch (error) {
      return reply.code(401).send({
        success: false,
        error: 'Ban chua dang nhap hoac token khong hop le.',
        code:
          error.code === 'FST_JWT_AUTHORIZATION_TOKEN_EXPIRED'
            ? 'TOKEN_EXPIRED'
            : 'UNAUTHORIZED'
      });
    }
  });

  fastify.decorate('requireAdmin', async function requireAdmin(request, reply) {
    if (!request.user || request.user.role !== 'admin') {
      return reply.code(403).send({
        success: false,
        error: 'Ban khong co quyen thuc hien thao tac nay.',
        code: 'UNAUTHORIZED'
      });
    }
  });
}

module.exports = fp(authPlugin, {
  name: 'app-auth'
});
