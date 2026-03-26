import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/admin_remote_datasource.dart';
import '../../../../core/di/injection.dart';
import 'package:go_router/go_router.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _ds = AdminRemoteDataSource(sl());
  List<dynamic> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      _users = await _ds.getUsers();
    } catch (e) {
      if (mounted) {
        // FORCE ERROR TO SHOW ON SCREEN
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('API Failed 🚨'),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStatus(String userId, bool activate) async {
    try {
      await _ds.toggleUserStatus(userId, activate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(activate ? 'User Activated' : 'User Deactivated'),
          backgroundColor: activate ? Colors.green : Colors.red,
        ));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
   appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // 🔥 FIX: Safely navigate back. If there is no history, force a return to the dashboard.
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
        ),
        title: const Text('Users', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)), // Remember to keep the correct title for each page!
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _users.isEmpty
                  ? const Center(child: Text('No users found in system.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index] as Map<String, dynamic>;
                        final isActive = user['is_active'] == true;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: Text((user['full_name'] as String? ?? 'U')[0].toUpperCase(), style: const TextStyle(color: AppColors.primary)),
                            ),
                            title: Text(user['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${user['email']}\nRole: ${user['role']}', style: const TextStyle(fontSize: 12)),
                            isThreeLine: true,
                            trailing: Switch(
                              value: isActive,
                              activeColor: Colors.green,
                              inactiveThumbColor: Colors.red,
                              onChanged: (val) => _toggleStatus(user['id'], val),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}