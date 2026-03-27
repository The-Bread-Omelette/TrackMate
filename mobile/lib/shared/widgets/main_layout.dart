import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../shared/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';

class MainLayout extends StatefulWidget {
  final UserEntity user;
  final Widget child;
  final String title;

  const MainLayout({
    super.key,
    required this.user,
    required this.child,
    required this.title,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    // Check if there is a page to go back to in the navigation stack
    final bool canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        // 🔥 THE FIX: Show back button on sub-pages, otherwise default to Drawer menu
        leading: canPop ? const BackButton() : null,
      ),
      drawer: _AppDrawer(user: widget.user),
      body: widget.child,
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final UserEntity user;

  const _AppDrawer({required this.user});

  @override
  Widget build(BuildContext context) {
    final isTrainee = user.role == UserRole.trainee;
    final isTrainer = user.role == UserRole.trainer;
    final isAdmin = user.role == UserRole.admin;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 24,
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  user.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user.role.name,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          if (isTrainee) ...[
            _tile(context, Icons.dashboard, 'Dashboard', '/dashboard'),
            _tile(context, Icons.restaurant, 'Food Logging', '/food'),
            _tile(context, Icons.fitness_center, 'Exercise', '/exercise'),
            _tile(context, Icons.bar_chart, 'Analytics', '/analytics'),
            _tile(context, Icons.calendar_month, 'Calendar', '/calendar'),
            _tile(context, Icons.people, 'Social', '/social'),
            _tile(context, Icons.search, 'Find a Trainer', '/find-trainer'),
            _tile(context, Icons.message, 'Messages', '/messages'),
            _tile(context, Icons.notifications, 'Notifications', AppRouter.notifications),
          ],

          if (isTrainer) ...[
            _tile(context, Icons.people, 'My Students', '/trainer/students'),
            _tile(context, Icons.inbox, 'Requests & Calendar', '/trainer/requests'),
            _tile(context, Icons.people, 'Social', '/social'),
            _tile(context, Icons.message, 'Messages', '/messages'),
            _tile(context, Icons.notifications, 'Notifications', AppRouter.notifications),
          ],

          if (isAdmin) ...[
            _tile(context, Icons.dashboard, 'Dashboard', '/admin/dashboard'),
            _tile(context, Icons.manage_accounts, 'Manage Trainers', '/admin/trainers'),
            _tile(context, Icons.people, 'Users', '/admin/users'),
          ],

          _tile(context, Icons.settings, 'Settings', '/settings'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Logout', style: TextStyle(color: AppColors.error)),
            onTap: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(const AuthLogoutEvent());
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: () {
        // Safely pop the drawer, then WAIT for the animation to finish before routing
        Navigator.of(context).pop();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (context.mounted) context.go(route);
        });
      },
    );
  }
}