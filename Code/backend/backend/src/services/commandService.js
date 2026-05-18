// CommandService tao command, publish len broker neu device dang online va cap nhat status command.
// File này xử lý nghiệp vụ liên quan đến lệnh điều khiển thiết bị, ví dụ khi user gửi lệnh bật đèn đến thiết bị, thì CommandService sẽ tạo một command mới, lưu vào database và gửi lệnh đó đến thiết bị qua MQTT nếu thiết bị đang online. Ngoài ra nó cũng cập nhật trạng thái của command (ví dụ sent, delivered, failed) dựa trên phản hồi từ thiết bị.
const Command = require('../models/Command'); 
const Device = require('../models/Device');

class CommandService {
  static async createAndDispatch({ deviceId, action, params = {}, userId, mqttService }) { // Hàm này được gọi khi user gửi một lệnh mới đến thiết bị. Ví dụ user muốn bật đèn, thì action có thể là 'turn_on' và params có thể chứa thông tin thêm như độ sáng, màu sắc, v.v.
    const payload = {
      action,
      params
    };

    const command = Command.create({ // Tạo một command mới trong database với trạng thái 'pending'. Command này sẽ được cập nhật trạng thái sau khi gửi đến thiết bị.
      deviceId,
      payload,
      createdBy: userId
    });

    const device = Device.findById(deviceId); // Kiểm tra xem thiết bị có tồn tại và đang online không. Nếu có thì gửi lệnh đến thiết bị qua MQTT.
    if (device && device.is_online) {
      const message = {
        commandId: command.id,
        action,
        params,
        timestamp: new Date().toISOString()
      };

      await mqttService.publishCommand(deviceId, message); 
      return Command.updateStatus(command.id, 'sent', 'sent_at', new Date().toISOString());
    }

    return command;
  }
}

module.exports = CommandService;
