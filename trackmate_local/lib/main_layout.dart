import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_page.dart';
import 'food_logging_page.dart';
import 'exercise_selection_page.dart';
import 'analytics_page.dart';
import 'trainer_dashboard_page.dart';
import 'trainer_requests_calendar_page.dart';
import 'admin_dashboard_page.dart';
import 'admin_manage_trainers_page.dart';
import 'admin_manage_reports_page.dart';

Future<void> checkLoginAndDo(
  BuildContext context,
  VoidCallback onLoginSuccess,
) async {
  final prefs = await SharedPreferences.getInstance();
  final savedEmail = prefs.getString('saved_email');

  if (savedEmail == null) {
    if (context.mounted) _showLoginPopup(context, onLoginSuccess);
  } else {
    onLoginSuccess();
  }
}

Future<void> _showLoginPopup(
  BuildContext context,
  VoidCallback onLoginSuccess,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Account Setup Required'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please log in locally to save workouts.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(hintText: 'Email', filled: true),
            ),
            SizedBox(height: 8),
            TextField(
              obscureText: true,
              decoration: InputDecoration(hintText: 'Password', filled: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF427AFA),
            ),
            child: const Text('Login', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('saved_email', 'test@user.com');
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
                onLoginSuccess();
              }
            },
          ),
        ],
      );
    },
  );
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  String _userRole = 'User';
  Widget?
  _currentPage; // Changed to nullable so we can show a loader while checking role
  String _pageTitle = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('saved_role') ?? 'User';

    setState(() {
      _userRole = role;

      // NEW: Set the initial page dynamically based on the role!
      if (_userRole == 'Admin') {
        _currentPage = const AdminDashboardPage(); // NEW!
        _pageTitle = 'Admin Dashboard';
      } else if (_userRole == 'Trainer') {
        _currentPage = TrainerDashboardPage();
        _pageTitle = 'My Students';
      } else {
        _currentPage = const DashboardPage();
        _pageTitle = 'Dashboard';
      }
    });
  }

  void _selectPage(Widget page, String title) {
    setState(() {
      _currentPage = page;
      _pageTitle = title;
    });
    Navigator.pop(context); // Close the drawer
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userRole == 'Admin';
    final isTrainer = _userRole == 'Trainer';
    final isUser = _userRole == 'User';

    // Show a blank screen or loading spinner for a split second while reading from memory
    if (_currentPage == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pageTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_pageTitle == 'Dashboard') // Only show streak on dashboard
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: Colors.orange,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '7 days',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF427AFA)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 24,
                    child: Icon(Icons.person, color: Color(0xFF427AFA)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Trackmate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Logged in as: $_userRole',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // --- USER MENU ---
            if (isUser) ...[
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Dashboard'),
                onTap: () => _selectPage(const DashboardPage(), 'Dashboard'),
              ),
              ListTile(
                leading: const Icon(Icons.restaurant),
                title: const Text('Food Logging'),
                onTap: () =>
                    _selectPage(const FoodLoggingPage(), 'Food Logging'),
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Exercise & Timer'),
                onTap: () => _selectPage(
                  const ExerciseSelectionPage(),
                  'Exercise & Timer',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Analytics'),
                onTap: () => _selectPage(const AnalyticsPage(), 'Analytics'),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Activity Calendar'),
                onTap: () => _selectPage(
                  const Center(child: Text("Calendar Coming Soon")),
                  'Activity Calendar',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Social & Trainers'),
                onTap: () => _selectPage(
                  const Center(child: Text("Social Coming Soon")),
                  'Social & Trainers',
                ),
              ),
              
            ],

            // --- TRAINER MENU ---
            if (isTrainer) ...[
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('My Students'),
                onTap: () => _selectPage(TrainerDashboardPage(), 'My Students'),
              ),

              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Requests & Calendar'),
                onTap: () => _selectPage(
                  const TrainerRequestsCalendarPage(),
                  'Requests & Calendar',
                ), // Replaced placeholder!
              ),
            ],
            if (isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Dashboard'),
                onTap: () =>
                    _selectPage(const AdminDashboardPage(), 'Admin Dashboard'),
              ),
              ListTile(
                leading: const Icon(Icons.manage_accounts),
                title: const Text('Manage Trainers'),
                onTap: () => _selectPage(
                  const AdminManageTrainersPage(),
                  'Manage Trainers',
                ), // Replace placeholder
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: const Text('Manage Reports'),
                onTap: () => _selectPage(
                  const AdminManageReportsPage(),
                  'Manage Reports',
                ), // Updated!
              ),
            ],

            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                // Return to login screen
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
      body: _currentPage,
    );
  }
}
