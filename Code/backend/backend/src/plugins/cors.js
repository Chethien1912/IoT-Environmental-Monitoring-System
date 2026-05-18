// Plugin CORS giup app Flutter/Web co the goi API backend tu moi origin duoc cau hinh.

const fp = require('fastify-plugin');
const cors = require('@fastify/cors');
const env = require('../config/env');

async function corsPlugin(fastify) {
  await fastify.register(cors, {
    origin: env.corsOrigin === '*' ? true : env.corsOrigin,
    credentials: true
  });
}

module.exports = fp(corsPlugin, {
  name: 'app-cors'
});
