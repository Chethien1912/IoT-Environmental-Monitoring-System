// Route health de kiem tra backend da san sang va phuc vu script start hoac monitoring.
async function healthRoutes(fastify) {
  fastify.get('/health', async () => ({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    mqttConnected: fastify.mqttService ? fastify.mqttService.isConnected() : false
  }));
}

module.exports = healthRoutes;
