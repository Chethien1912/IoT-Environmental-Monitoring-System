// DeviceService xu ly tao thiet bi, kiem tra quyen truy cap va verify secret cho MQTT auth webhook.
const bcrypt = require('bcryptjs'); // bcryptjs là thư viện để hash và so sánh mật khẩu. Ở đây nó được dùng để hash device secret khi tạo thiết bị mới, và để so sánh device secret khi thiết bị kết nối MQTT auth webhook.
const { nanoid } = require('nanoid'); //tạo chuỗi id/secret ngẫu nhiên

const Device = require('../models/Device'); // model để lưu hoặc tìm thiết bị trong database

class DeviceService {
  static async createDevice({ ownerId, name, type = 'esp32', hardwareId = null }) { // Hàm này dùng để tạo thiết bị mới.Ví dụ user thêm một ESP32 mới trong app.
    const safeType = (type || 'esp32').trim().toLowerCase();
    const deviceId = `${safeType}_${nanoid(8)}`;
    const deviceSecret = nanoid(32); // Secret này giống như mật khẩu riêng của thiết bị.
    const deviceSecretHash = await bcrypt.hash(deviceSecret, 10);

    const device = Device.create({ // Rồi tạo thiết bị trong database
      id: deviceId,
      name: name.trim(),
      type: safeType,
      ownerId,
      deviceSecretHash,
      hardwareId
    });

    return {
      ...device,
      deviceSecret
    };
  }

  static canAccessDevice(requestUser, device) { // Hàm này kiểm tra user có quyền truy cập thiết bị không.
    if (!requestUser || !device) {
      return false;
    }

    return requestUser.role === 'admin' || device.owner_id === requestUser.userId;
  }

  static async verifyDeviceSecret(deviceId, secret) { // Hàm này kiểm tra secret của thiết bị.
    const device = Device.findById(deviceId);
    if (!device) {
      return false;
    }

    return bcrypt.compare(secret, device.device_secret_hash);
  }
}

module.exports = DeviceService;
