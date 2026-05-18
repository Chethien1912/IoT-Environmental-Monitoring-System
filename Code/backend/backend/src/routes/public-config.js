// Route public-config tra ve URL public de app co the doc cau hinh khi backend duoc expose ra ngoai.
async function publicConfigRoutes(fastify) {
  fastify.get('/api/public-config', async (request) => {
    const host = request.headers.host;
    const protocol =
      request.headers['x-forwarded-proto'] || (host && host.includes('localhost') ? 'http' : 'https');
    const origin = `${protocol}://${host}`;

    return {
      success: true,
      data: {
        apiUrl: origin,
        wsUrl: origin,
        mqttWsUrl: `${origin.replace(/^http/, 'ws')}/mqtt`
      }
    };
  });
}

module.exports = publicConfigRoutes;
