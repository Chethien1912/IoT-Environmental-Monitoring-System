// Day la entry point chinh: dang ky plugin, route, websocket, MQTT va khoi dong Fastify server.
const Fastify = require('fastify');//Dòng này import Fastify. Fastify là framework để tạo HTTP server, tương tự Express nhưng nhanh và gọn hơn.

const env = require('./config/env');//đọc cấu hình từ .env file. Ví dụ env.port, env.mqttUrl, v.v.
require('./config/database'); // kết nối database. Khi import file này, nó sẽ tự động kết nối đến database dựa trên cấu hình trong file đó.
// corsPlugin: cho phép app/frontend gọi API backend. Ví dụ app Flutter Web chạy ở địa chỉ khác backend thì vẫn gọi được API.
// authPlugin: đăng ký JWT và tạo middleware xác thực.
const corsPlugin = require('./plugins/cors');
const authPlugin = require('./plugins/auth');
//Mỗi file route là một nhóm API. Ví dụ authRoutes chứa các API liên quan đến xác thực, userRoutes chứa các API liên quan đến người dùng, v.v.
const authRoutes = require('./routes/auth');// API đăng nhập/đăng ký
const userRoutes = require('./routes/users');// API người dùng
const deviceRoutes = require('./routes/devices'); // API thiết bị
const commandRoutes = require('./routes/commands'); // API cầu nối thiết bị (device bridge) để nhận dữ liệu từ thiết bị và gửi lệnh đến thiết bị. Đây là phần quan trọng nhất vì nó kết nối trực tiếp với thiết bị vật lý.
const healthRoutes = require('./routes/health'); // API kiểm tra sức khỏe của server, thường là GET /health trả về 200 OK nếu server đang chạy tốt.
const publicConfigRoutes = require('./routes/public-config'); // API cung cấp cấu hình công khai cho frontend, ví dụ như danh sách thiết bị, thông tin người dùng, v.v. Những thông tin này có thể được frontend sử dụng để hiển thị giao diện hoặc cấu hình kết nối MQTT.
const deviceBridgeRoutes = require('./routes/device-bridge'); //API cầu nối thiết bị (device bridge) để nhận dữ liệu từ thiết bị và gửi lệnh đến thiết bị. Đây là phần quan trọng nhất vì nó kết nối trực tiếp với thiết bị vật lý.
const mqttService = require('./mqtt/mqttClient'); // mqttService là module quản lý kết nối MQTT, đăng ký các topic, xử lý tin nhắn đến và gửi tin nhắn đi. Nó sẽ được sử dụng trong deviceBridgeRoutes để nhận dữ liệu từ thiết bị và gửi lệnh đến thiết bị, cũng như trong wsService để gửi dữ liệu thời gian thực đến frontend qua WebSocket.
const wsService = require('./websocket/wsServer');// wsService là module quản lý kết nối WebSocket, cho phép gửi dữ liệu thời gian thực từ backend đến frontend. Ví dụ khi có dữ liệu mới từ thiết bị qua MQTT, backend có thể gửi dữ liệu đó ngay lập tức đến frontend qua WebSocket để cập nhật giao diện người dùng.

async function buildServer() {
  const fastify = Fastify({
    logger: true // bật logging để dễ dàng theo dõi hoạt động của server. Khi có lỗi hoặc khi server khởi động, Fastify sẽ tự động in log ra console.
  });

  fastify.decorate('config', env);
  fastify.decorate('mqttService', mqttService);

  await fastify.register(corsPlugin); // cho phép frontend/app gọi backend
  await fastify.register(authPlugin); // đăng ký plugin xác thực JWT, tạo middleware auth để bảo vệ các route cần xác thực. Ví dụ nếu một route yêu cầu auth, thì khi gọi API đó mà không có token hợp lệ sẽ bị trả về lỗi 401 Unauthorized.
  //Đây là lúc backend “gắn API vào server”.
  //Sau khi register xong, Fastify biết các đường dẫn như:
  /*
  GET /health
  GET /api/public-config
  POST /api/telemetry
  POST /api/auth/login
  GET /api/users
  GET /api/devices
  POST /api/devices/:id/command*/
  await fastify.register(healthRoutes);
  await fastify.register(publicConfigRoutes);
  await fastify.register(deviceBridgeRoutes);
  await fastify.register(authRoutes);
  await fastify.register(userRoutes);
  await fastify.register(deviceRoutes);
  await fastify.register(commandRoutes);

  return fastify;
}
//Hàm start() gọi buildServer() để tạo server.
async function start() { 
  const fastify = await buildServer(); //Gọi hàm buildServer() để lấy server đã cấu hình route/plugin.

  try { //Dùng try/catch để nếu backend khởi động lỗi thì bắt lỗi và in ra log
    await fastify.listen({ port: env.port, host: '0.0.0.0' });// Nếu env.port = 3000, backend chạy ở
    wsService.init(fastify);
    mqttService.connect({
      mqttUrl: env.mqttUrl,
      username: env.mqttUsername,
      password: env.mqttPassword,
      wsService
    });
    // Xử lý tắt server
    const shutdown = async () => {
      mqttService.disconnect();
      await fastify.close();
      process.exit(0);
    };
    // Bắt tín hiệu tắt server (Ctrl+C hoặc lệnh kill) để gọi hàm shutdown, đảm bảo đóng kết nối MQTT và Fastify một cách sạch sẽ trước khi thoát.  
    process.on('SIGINT', shutdown); // SIGINT là tín hiệu khi người dùng nhấn Ctrl+C trong terminal để dừng server.
    process.on('SIGTERM', shutdown);
  } catch (error) { // Nếu server bị lỗi khi chạy
    //
    fastify.log.error(error);//In lỗi ra terminal
    process.exit(1); //Thoát với mã lỗi 1 để báo rằng server đã khởi động thất bại.
  } 
}

start();
