// Route auth xu ly dang nhap, refresh token va logout theo dinh dang response thong nhat.
const AuthService = require('../services/authService');

function isValidUsername(value) {
  return /^[A-Za-z0-9_]{3,30}$/.test(String(value || ''));
}

function isValidPassword(value) {
  return (
    typeof value === 'string' &&
    value.length >= 8 &&
    /[A-Z]/.test(value) &&
    /\d/.test(value)
  );
}

async function authRoutes(fastify) {
  fastify.post('/api/auth/register', async (request, reply) => {
    const { username, password } = request.body || {};
    if (!isValidUsername(username) || !isValidPassword(password)) {
      return reply.code(400).send({
        success: false,
        error:
          'Username phai tu 3-30 ky tu [A-Za-z0-9_] va password toi thieu 8 ky tu, co chu hoa va so.',
        code: 'VALIDATION_ERROR'
      });
    }

    const result = await AuthService.register(
      fastify,
      String(username).trim(),
      String(password)
    );

    if (result.error) {
      return reply.code(409).send({
        success: false,
        error: result.error,
        code: result.code
      });
    }

    return {
      success: true,
      data: result
    };
  });

  fastify.post('/api/auth/login', async (request, reply) => {
    const { username, password } = request.body || {};
    if (!username || !password) {
      return reply.code(400).send({
        success: false,
        error: 'username va password la bat buoc.',
        code: 'VALIDATION_ERROR'
      });
    }

    const result = await AuthService.login(
      fastify,
      String(username).trim(),
      String(password)
    );

    if (!result) {
      return reply.code(401).send({
        success: false,
        error: 'Sai ten dang nhap hoac mat khau.',
        code: 'INVALID_CREDENTIALS'
      });
    }

    return {
      success: true,
      data: result
    };
  });

  fastify.post('/api/auth/refresh', async (request, reply) => {
    const { refreshToken } = request.body || {};
    if (!refreshToken) {
      return reply.code(400).send({
        success: false,
        error: 'refreshToken la bat buoc.',
        code: 'VALIDATION_ERROR'
      });
    }

    const result = await AuthService.refreshAccessToken(fastify, refreshToken);
    if (result.error) {
      return reply.code(result.code === 'TOKEN_EXPIRED' ? 401 : 404).send({
        success: false,
        error: result.error,
        code: result.code
      });
    }

    return {
      success: true,
      data: result
    };
  });

  fastify.post(
    '/api/auth/logout',
    { preHandler: [fastify.authenticate] },
    async (request, reply) => {
      const { refreshToken } = request.body || {};
      if (!refreshToken) {
        return reply.code(400).send({
          success: false,
          error: 'refreshToken la bat buoc.',
          code: 'VALIDATION_ERROR'
        });
      }

      return {
        success: true,
        data: AuthService.logout(refreshToken)
      };
    }
  );
}

module.exports = authRoutes;
