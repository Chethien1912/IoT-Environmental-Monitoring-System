// AuthService gom login, refresh, logout va tao/revoke refresh token de route chi con viec xu ly request/response.
// Hash là quá trình biến một dữ liệu gốc thành một chuỗi mới có độ dài cố định, để không lưu dữ liệu gốc trực tiếp.  password=123456 thì hash biến password thành $2a$10$9sS1VtYxQfKk9. Nếu database bị lộ, người khác chỉ thấy bản hash, không thấy dữ liệu gốc
const crypto = require('crypto'); // tạo refresh token và hash token
const bcrypt = require('bcryptjs'); // hash/check password
 
const env = require('../config/env'); //  đọc cấu hình thời hạn token
const RefreshToken = require('../models/RefreshToken'); // lưu refresh token vào database
const User = require('../models/User'); // tìm/tạo user

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function addDays(date, days) { // Hàm này tính ngày hết hạn refresh token
  const next = new Date(date);
  next.setUTCDate(next.getUTCDate() + days);
  return next.toISOString();
}

class AuthService {
  static async _buildSessionForUser(fastify, user) { // Hàm này tạo phiên đăng nhập cho user.
    const accessToken = await fastify.jwt.sign(
      { userId: user.id, role: user.role },
      { expiresIn: env.jwtAccessExpiresIn }
    );

    const refreshToken = crypto.randomBytes(32).toString('hex'); 
    RefreshToken.create({ // Hash refresh token rồi lưu database để sau này kiểm tra khi user gửi refresh token để lấy access token mới. Nếu refresh token không tồn tại hoặc đã hết hạn thì sẽ không cấp access token mới.
      tokenHash: hashToken(refreshToken),
      userId: user.id,
      expiresAt: addDays(new Date(), env.refreshTokenTtlDays)
    });

    return {
      accessToken,
      refreshToken,
      user: User.sanitize(user)
    };
  }
//   _buildSessionForUser()
// -> tạo accessToken JWT
// -> tạo refreshToken
// -> lưu hash refreshToken vào DB
// -> trả token + thông tin user sạch cho app

  static async login(fastify, username, password) { // Hàm này xử lý đăng nhập. Khi user gửi username và password, hàm này sẽ tìm user trong database, kiểm tra password, nếu hợp lệ thì gọi _buildSessionForUser để tạo phiên đăng nhập và trả về access token, refresh token và thông tin user.
    const user = User.findByUsername(username);
    if (!user || !user.is_active) {
      return null;
    }

    const passwordMatch = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatch) {
      return null;
    }

    return this._buildSessionForUser(fastify, user);
  }
 
  static async register(fastify, username, password) { // Hàm này xử lý đăng ký tài khoản mới. Khi user gửi username và password để đăng ký, hàm này sẽ kiểm tra xem username đã tồn tại chưa, nếu chưa thì hash password, tạo user mới trong database và gọi _buildSessionForUser để tạo phiên đăng nhập cho user mới. 
    const existing = User.findByUsername(username);
    if (existing) {
      return { error: 'Username da ton tai.', code: 'VALIDATION_ERROR' };
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = User.create({
      username,
      passwordHash,
      role: 'user',
      isActive: true
    });

    return this._buildSessionForUser(fastify, user);
  }

  static async refreshAccessToken(fastify, refreshToken) { // Hàm này dùng khi access token hết hạn
    const tokenHash = hashToken(refreshToken);
    const record = RefreshToken.findByTokenHash(tokenHash);

    if (!record) {
      return { error: 'Refresh token khong ton tai.', code: 'NOT_FOUND' };
    }

    if (new Date(record.expires_at).getTime() <= Date.now()) {
      RefreshToken.deleteByTokenHash(tokenHash);
      return { error: 'Refresh token da het han.', code: 'TOKEN_EXPIRED' };
    }

    if (!record.is_active) {
      return { error: 'Tai khoan da bi vo hieu hoa.', code: 'UNAUTHORIZED' };
    }

    const accessToken = await fastify.jwt.sign(
      { userId: record.user_id, role: record.role },
      { expiresIn: env.jwtAccessExpiresIn }
    );

    return { accessToken };
  }
  // Access token hết hạn sau 1 giờ
  // App gửi refresh token lên backend
  // Backend kiểm tra refresh token
  // Nếu hợp lệ, backend cấp access token mới

  static logout(refreshToken) {
    const tokenHash = hashToken(refreshToken);
    RefreshToken.deleteByTokenHash(tokenHash);
    return { success: true };
  }
}

module.exports = AuthService;
