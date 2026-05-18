// WebSocket server dung Socket.IO de day telemetry, status va command ack ve app theo room user/device/admin.
//Có chức năng tạo WebSocket server bằng Socket.IO để backend gửi dữ liệu realtime về app/web.
// Nói đơn giản: HTTP API bình thường là app phải hỏi backend. WebSocket thì backend có dữ liệu mới là đẩy ngay về app
const { Server } = require('socket.io');

const Device = require('../models/Device');

let io = null;
// Hàm emitLastTelemetry gửi dữ liệu telemetry cuối cùng của thiết bị về client khi client mới subscribe vào thiết bị đó. Nếu thiết bị có last_telemetry thì sẽ gửi về client qua sự kiện 'telemetry' với payload chứa deviceId, data và timestamp.
function emitLastTelemetry(socket, device) {
  if (device && device.last_telemetry) {
    socket.emit('telemetry', {
      deviceId: device.id,
      data: device.last_telemetry,
      timestamp: new Date().toISOString()
    });
  }
}
// Hàm init khởi tạo Socket.IO server, thiết lập middleware xác thực JWT cho kết nối WebSocket, và xử lý sự kiện kết nối của client. Khi client kết nối, nó sẽ join vào room riêng theo userId và role (admin hoặc user). Client cũng có thể subscribe hoặc unsubscribe vào các room thiết bị để nhận dữ liệu telemetry của thiết bị đó.
function init(fastify) {
  io = new Server(fastify.server, {
    cors: { origin: '*' },
    transports: ['websocket', 'polling']
  });

  io.use(async (socket, next) => { //sau khi Fastify server chạy, backend khởi động Socket.IO.
    try {
      const token = socket.handshake.auth && socket.handshake.auth.token;
      if (!token) {
        return next(new Error('UNAUTHORIZED'));
      }

      const payload = await fastify.jwt.verify(token);
      socket.data.userId = payload.userId;
      socket.data.role = payload.role;
      return next();
    } catch (error) {
      return next(new Error('UNAUTHORIZED'));
    }
  });
  // Kiểm tra JWT khi app kết nối WebSocket. Nếu token hợp lệ, lấy userId và role từ payload và lưu vào socket.data để sử dụng sau này. Nếu token không hợp lệ thì trả về lỗi UNAUTHORIZED và không cho phép kết nối WebSocket.
  io.on('connection', (socket) => {
    socket.join(`user:${socket.data.userId}`);
    if (socket.data.role === 'admin') {
      socket.join('admin');
    }
   
    socket.on('subscribe:device', ({ deviceId }) => { // Khi client gửi sự kiện 'subscribe:device' với payload chứa deviceId, backend sẽ kiểm tra xem thiết bị đó có tồn tại không và nếu có thì kiểm tra xem user có quyền truy cập vào thiết bị đó không (admin hoặc owner). Nếu có quyền thì cho socket join vào room `device:${deviceId}` để nhận dữ liệu telemetry của thiết bị đó. Sau khi join xong, gọi hàm emitLastTelemetry để gửi dữ liệu telemetry cuối cùng của thiết bị về client ngay lập tức.
      const device = Device.findById(deviceId);
      if (!device) {
        return;
      }

      const canAccess =
        socket.data.role === 'admin' || device.owner_id === socket.data.userId;
      if (!canAccess) {
        return;
      }

      socket.join(`device:${deviceId}`);
      emitLastTelemetry(socket, device);
    });

    socket.on('unsubscribe:device', ({ deviceId }) => {
      socket.leave(`device:${deviceId}`);
    });
  });
}
// Hàm broadcastTelemetry được gọi khi có dữ liệu telemetry mới từ thiết bị. Nó sẽ gửi dữ liệu đó đến tất cả client đang subscribe vào thiết bị đó (room `device:${deviceId}`) và đến tất cả admin (room 'admin') qua sự kiện 'telemetry' với payload chứa deviceId, data và timestamp.
function broadcastTelemetry(deviceId, data) {
  if (!io) {
    return;
  }

  const payload = {
    deviceId,
    data,
    timestamp: new Date().toISOString()
  };
  io.to(`device:${deviceId}`).emit('telemetry', payload);
  io.to('admin').emit('telemetry', payload);
}
// Hàm này gửi trạng thái online/offline của thiết bị. Khi có thiết bị online hoặc offline, backend sẽ gọi hàm này để gửi trạng thái đó đến tất cả client đang subscribe vào thiết bị đó và đến tất cả admin qua sự kiện 'device:status' với payload chứa deviceId, isOnline và timestamp.
function broadcastStatus(deviceId, isOnline) {
  if (!io) {
    return;
  }

  const device = Device.findById(deviceId);
  if (!device) {
    return;
  }

  const payload = {
    deviceId,
    isOnline,
    timestamp: new Date().toISOString()
  };
  io.to(`user:${device.owner_id}`).emit('device:status', payload);
  io.to('admin').emit('device:status', payload);
}
// Hàm broadcastCommandAck được gọi khi có lệnh mới được gửi đến thiết bị và nhận được phản hồi xác nhận từ thiết bị. Nó sẽ gửi thông tin xác nhận đó đến tất cả client đang subscribe vào thiết bị đó và đến tất cả admin qua sự kiện 'command:ack' với payload chứa deviceId, commandId, status và timestamp.
function broadcastCommandAck(deviceId, commandId, status) {
  if (!io) {
    return;
  }

  const payload = {
    deviceId,
    commandId,
    status,
    timestamp: new Date().toISOString()
  };
  io.to(`device:${deviceId}`).emit('command:ack', payload);
  io.to('admin').emit('command:ack', payload);
}

module.exports = {
  init,
  broadcastTelemetry,
  broadcastStatus,
  broadcastCommandAck
};
