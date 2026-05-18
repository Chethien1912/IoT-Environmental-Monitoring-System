import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../services/api_client.dart';
import '../widgets/dashboard_chrome.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.api,
    required this.onLoggedIn,
  });

  final ApiClient api;
  final ValueChanged<AuthSession> onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  late final TextEditingController _backendUrl;

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _backendUrl = TextEditingController(text: widget.api.baseUrl);
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _backendUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text.trim();
    final password = _password.text;
    final backendUrl = _backendUrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(
          () => _error = 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.');
      return;
    }

    if (backendUrl.isEmpty) {
      setState(() => _error = 'Vui lòng nhập Backend URL.');
      return;
    }

    if (_isRegisterMode && password != _confirmPassword.text) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      widget.api.setBaseUrl(backendUrl);
      final session = _isRegisterMode
          ? await widget.api.register(username: username, password: password)
          : await widget.api.login(username: username, password: password);
      if (mounted) {
        widget.onLoggedIn(session);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _error = null;
      _password.clear();
      _confirmPassword.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: _buildFormPanel(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormPanel(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 520;

    return Container(
      padding: EdgeInsets.all(isCompact ? 22 : 28),
      decoration: glassPanelDecoration(
        colors: const [Color(0xCC13223B), Color(0xCC0C1527)],
        radius: 38,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _BrandLogoCard(
                width: isCompact ? 76 : 88,
                height: isCompact ? 76 : 88,
                padding: const EdgeInsets.all(10),
                imagePath: 'assets/images/logo_hcmute.png',
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isCompact ? 220 : 280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IoTapp',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 28 : 34,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegisterMode
                          ? 'Tạo tài khoản mới'
                          : 'Chào mừng trở lại',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: isCompact ? 18 : 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _BrandLogoCard(
                width: isCompact ? 124 : 156,
                height: isCompact ? 76 : 88,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                imagePath: 'assets/images/logo_aiot.png',
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _ProjectCreditsCard(),
          const SizedBox(height: 26),
          TextField(
            controller: _backendUrl,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Backend URL',
              icon: Icons.link_rounded,
            ).copyWith(
              hintText: 'VD: http://192.168.1.21:3000',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _username,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Tên đăng nhập',
              icon: Icons.person_rounded,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: _obscurePassword,
            textInputAction:
                _isRegisterMode ? TextInputAction.next : TextInputAction.done,
            onSubmitted: (_) {
              if (!_isRegisterMode) {
                _submit();
              }
            },
            decoration: _inputDecoration(
              label: 'Mật khẩu',
              icon: Icons.lock_rounded,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
          ),
          if (_isRegisterMode) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPassword,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: _inputDecoration(
                label: 'Xác nhận mật khẩu',
                icon: Icons.verified_user_rounded,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppPalette.danger.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AppPalette.danger.withValues(alpha: 0.24)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppPalette.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: Icon(
                _isRegisterMode
                    ? Icons.person_add_alt_1_rounded
                    : Icons.login_rounded,
              ),
              label: Text(
                _busy
                    ? (_isRegisterMode
                        ? 'Đang tạo tài khoản...'
                        : 'Đang đăng nhập...')
                    : (_isRegisterMode
                        ? 'Đăng ký và vào dashboard'
                        : 'Đăng nhập vào dashboard'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : _toggleMode,
              child: Text(
                _isRegisterMode
                    ? 'Đã có tài khoản? Đăng nhập'
                    : 'Chưa có tài khoản? Đăng ký',
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.72)),
      suffixIcon: suffixIcon,
    );
  }
}

class _BrandLogoCard extends StatelessWidget {
  const _BrandLogoCard({
    required this.width,
    required this.height,
    required this.padding,
    required this.imagePath,
    this.fit = BoxFit.contain,
  });

  final double width;
  final double height;
  final EdgeInsets padding;
  final String imagePath;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(imagePath, fit: fit),
    );
  }
}

class _ProjectCreditsCard extends StatelessWidget {
  const _ProjectCreditsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hệ thống giám sát nồng độ khí độc trong không khí và cảnh báo an toàn',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'GVHD: Nguyễn Văn Thái',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'SVTH',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'MSSV',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _StudentRow(
            name: 'Nguyễn Sỹ Duy',
            studentId: '23151225',
          ),
          const SizedBox(height: 8),
          const _StudentRow(
            name: 'Nguyễn Văn Tấn Đạt',
            studentId: '23151234',
          ),
          const SizedBox(height: 8),
          const _StudentRow(
            name: 'Nguyễn Chế Thiện',
            studentId: '23151313',
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.name,
    required this.studentId,
  });

  final String name;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              studentId,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
