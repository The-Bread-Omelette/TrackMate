import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/admin_remote_datasource.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _ds = AdminRemoteDataSource(sl());
  Map<String, dynamic> _stats = {};
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
      _stats = await _ds.getStats();
    } catch (e) {
      // 🔥 FIX: Show the exact error so we know why it's returning 0!
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Stats API Failed 🚨'),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticatedState).user;

    // 🔥 FIX: Responsive grid layout so it doesn't stretch wildly
    int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;

    return MainLayout(
      user: user,
      title: 'Admin Dashboard',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800), // 🔥 Restricts width on Web
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome, Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Text('Manage users, trainers, and system settings', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // STATS GRID
                      GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5, // 🔥 Tighter proportions
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _StatCard(
                            icon: Icons.people_alt_outlined,
                            iconColor: AppColors.primary,
                            title: 'Total Users',
                            value: '${_stats['total_users'] ?? 0}',
                          ),
                          _StatCard(
                            icon: Icons.manage_accounts_outlined,
                            iconColor: Colors.purple,
                            title: 'Active Trainers',
                            value: '${_stats['active_trainers'] ?? 0}',
                          ),
                          _StatCard(
                            icon: Icons.warning_amber_rounded,
                            iconColor: Colors.red,
                            title: 'Pending Reports',
                            value: '${_stats['pending_reports'] ?? 0}',
                          ),
                          _StatCard(
                            icon: Icons.assignment_ind_outlined,
                            iconColor: Colors.orange,
                            title: 'Trainer Apps',
                            value: '${_stats['pending_trainer_applications'] ?? 0}',
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      
                      // QUICK ACTIONS ROW
                      Row(
                        children: [
                          _QuickActionCard(
                            icon: Icons.manage_accounts,
                            label: 'Trainer Apps',
                            color: Colors.orange,
                            onTap: () {
                              context.push(AppRouter.adminTrainers).then((_) => _load());
                            },
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            icon: Icons.warning_amber_rounded,
                            label: 'Reports',
                            color: AppColors.error,
                            onTap: () {
                              context.push(AppRouter.adminReports).then((_) => _load());
                            },
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            icon: Icons.group,
                            label: 'All Users',
                            color: Colors.green,
                            onTap: () {
                              context.push(AppRouter.adminUsers).then((_) => _load());
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// 🔥 FIXED STAT CARD LAYOUT
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  const _StatCard({required this.icon, required this.iconColor, required this.title, required this.value});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20), 
              const SizedBox(width: 8), 
              Expanded(child: Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)))
            ]
          ),
          const SizedBox(height: 12), // 🔥 Replaced the broken Spacer()
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.onTap, this.color = AppColors.primary});
  
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}