import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/user_account.dart';
import '../services/api_client.dart';
import '../widgets/dashboard_chrome.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({
    super.key,
    required this.api,
    required this.session,
  });

  final ApiClient api;
  final AuthSession session;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<UserAccount> _users = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await widget.api.fetchUsers();
      if (!mounted) {
        return;
      }
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _createUser() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'user';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Tao tai khoan moi'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('user')),
                      DropdownMenuItem(value: 'admin', child: Text('admin')),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() => role = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Huy'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await widget.api.createUser(
                      username: usernameController.text.trim(),
                      password: passwordController.text,
                      role: role,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.pop(context);
                    await _loadUsers();
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error.toString().replaceFirst('Exception: ', ''),
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Tao'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editUser(UserAccount user) async {
    final usernameController = TextEditingController(text: user.username);
    String role = user.role;
    bool isActive = user.isActive;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Cap nhat ${user.username}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('user')),
                      DropdownMenuItem(value: 'admin', child: Text('admin')),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() => role = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kich hoat tai khoan'),
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Huy'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await widget.api.updateUser(
                      user.id,
                      username: usernameController.text.trim(),
                      role: role,
                      isActive: isActive,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.pop(context);
                    await _loadUsers();
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error.toString().replaceFirst('Exception: ', ''),
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Luu'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resetPassword(UserAccount user) async {
    final passwordController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset mat khau ${user.username}'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'Mat khau moi'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huy'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await widget.api
                    .resetUserPassword(user.id, passwordController.text);
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Da reset mat khau thanh cong.')),
                );
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.toString().replaceFirst('Exception: ', ''),
                    ),
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserAccount user) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xac nhan xoa user'),
        content: Text('Xoa tai khoan ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoa'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.api.deleteUser(user.id);
      await _loadUsers();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.session.user.id;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF030712), Color(0xFF0A1E35), Color(0xFF061423)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadUsers,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ShellHero(
                  title: 'User Management',
                  subtitle: 'Admin ${widget.session.user.username}',
                  trailing: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _createUser,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Tao tai khoan moi'),
                  ),
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF7B7B)),
                  )
                else if (_users.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: glassPanelDecoration(),
                    child: const Text(
                      'Chua co user nao trong he thong.',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                else
                  ..._users.map((user) {
                    final bool isCurrentUser = user.id == currentUserId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: glassPanelDecoration(),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        title: Text(
                          user.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'ID: ${user.id} • Role: ${user.role} • ${user.isActive ? 'ACTIVE' : 'INACTIVE'}\nCreated: ${user.createdAt}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72)),
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'Sua user',
                              onPressed: _busy || isCurrentUser
                                  ? null
                                  : () => _editUser(user),
                              icon: const Icon(Icons.edit_rounded,
                                  color: Colors.white),
                            ),
                            IconButton(
                              tooltip: 'Reset mat khau',
                              onPressed:
                                  _busy ? null : () => _resetPassword(user),
                              icon: const Icon(Icons.lock_reset_rounded,
                                  color: Colors.white),
                            ),
                            IconButton(
                              tooltip: 'Xoa user',
                              onPressed: _busy || isCurrentUser
                                  ? null
                                  : () => _deleteUser(user),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Color(0xFFFF7B7B)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
