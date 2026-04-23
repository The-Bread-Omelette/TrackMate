import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../features/messaging/data/messaging_remote_datasource.dart';
import '../../../../features/messaging/presentation/pages/chat_page.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/trainer_remote_datasource.dart';

class StudentDetailPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final TrainerRemoteDataSource ds;

  const StudentDetailPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.ds,
  });

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic> _detail = {};
  List<dynamic> _workouts = [];
  Map<String, dynamic> _nutrition = {};
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.ds.getStudentDetail(widget.studentId),
        widget.ds.getStudentWorkouts(widget.studentId),
        widget.ds.getStudentNutrition(widget.studentId),
        widget.ds.getStudentStats(widget.studentId),
      ]);
      if (mounted) {
        setState(() {
          _detail = results[0] as Map<String, dynamic>;
          _workouts = results[1] as List<dynamic>;
          _nutrition = results[2] as Map<String, dynamic>;
          _stats = results[3] as Map<String, dynamic>;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _showBookingDialog(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null) return;

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;

    final scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    
    String sessionType = 'online';
    final locCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final notesCtrl = TextEditingController(text: "Standard 1-on-1 check-in");

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Session Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: sessionType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                    DropdownMenuItem(value: 'offline', child: Text('Offline')),
                  ],
                  onChanged: (v) => setDialogState(() => sessionType = v!),
                ),
                if (sessionType == 'online')
                  TextField(controller: linkCtrl, decoration: const InputDecoration(labelText: 'Meet Link')),
                if (sessionType == 'offline')
                  TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location')),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await widget.ds.scheduleSession(widget.studentId, scheduled, 60, notesCtrl.text, 
                    location: locCtrl.text, meetingLink: linkCtrl.text, type: sessionType);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session booked!')));
                } catch (_) {}
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
            onPressed: () async {
              try {
                final msgDs = sl<MessagingRemoteDataSource>();
                final convData = await msgDs.startConversation(widget.studentId);
                if (context.mounted) {
                  final authState = context.read<AuthBloc>().state as AuthAuthenticatedState;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
                    conversationId: convData['conversation_id'],
                    otherUserId: widget.studentId,
                    otherUserName: widget.studentName,
                    ds: msgDs,
                    currentUserId: authState.user.id,
                  )));
                }
              } catch (_) {}
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBookingDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.calendar_month, color: Colors.white),
        label: const Text('Book Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          // 🔥 FIXED: Use NestedScrollView to allow the tabs to expand and take up remaining space
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _topStat('Adherence', '${_detail['adherence'] ?? 0}%'),
                            const SizedBox(width: 12),
                            _topStat('Streak', '${(_stats['streak_days'] ?? 0)} days'),
                            const SizedBox(width: 12),
                            _topStat('Workouts', '${(_stats['weekly']?['workouts_completed'] ?? 0)}/wk'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _NotesSection(
                          notes: (_detail['notes'] as List?) ?? [],
                          controller: _noteCtrl,
                          onSend: () async {
                            if (_noteCtrl.text.isEmpty) return;
                            await widget.ds.addNote(widget.studentId, _noteCtrl.text);
                            _noteCtrl.clear();
                            _load();
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabs,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textMuted,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(text: 'Profile'),
                        Tab(text: 'Diet'),
                        Tab(text: 'Workouts'),
                        Tab(text: 'History'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabs,
                children: [
                  _ProfileTab(detail: _detail),
                  _NutritionTab(nutrition: _nutrition),
                  _WorkoutsTab(workouts: _workouts),
                  _HistoryTab(stats: _stats),
                ],
              ),
            ),
    );
  }

  Widget _topStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// --- TAB CONTENTS ---

class _ProfileTab extends StatelessWidget {
  final Map<String, dynamic> detail;
  const _ProfileTab({required this.detail});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _infoTile(Icons.height, 'Height', '${detail['height_cm'] ?? '--'} cm'),
        _infoTile(Icons.monitor_weight_outlined, 'Weight', '${detail['weight_kg'] ?? '--'} kg'),
        _infoTile(Icons.directions_walk, 'Step Goal', '${detail['daily_step_goal'] ?? '--'}'),
        _infoTile(Icons.local_fire_department, 'Calorie Goal', '${detail['daily_calorie_goal'] ?? '--'} kcal'),
        _infoTile(Icons.bolt, 'Activity Level', detail['activity_level'] ?? '--'),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _NutritionTab extends StatelessWidget {
  final Map<String, dynamic> nutrition;
  const _NutritionTab({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final summary = nutrition['summary'] as Map<String, dynamic>? ?? {};
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text('Total Calories', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text('${summary['total_calories'] ?? 0} kcal', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _macroCircle('Protein', '${summary['total_protein_g'] ?? 0}g', Colors.orange),
            const SizedBox(width: 12),
            _macroCircle('Carbs', '${summary['total_carbs_g'] ?? 0}g', Colors.blue),
            const SizedBox(width: 12),
            _macroCircle('Fats', '${summary['total_fat_g'] ?? 0}g', Colors.red),
          ],
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.restaurant_menu, color: AppColors.primary),
          title: const Text('Meals Logged Today'),
          trailing: Text('${summary['meal_count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      ],
    );
  }

  Widget _macroCircle(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _WorkoutsTab extends StatelessWidget {
  final List<dynamic> workouts;
  const _WorkoutsTab({required this.workouts});

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) return const Center(child: Text('No workouts logged yet.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workouts.length,
      itemBuilder: (_, i) {
        final w = workouts[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.fitness_center, color: Colors.white, size: 20)),
            title: Text(w['name'] ?? 'Workout', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${(w['sets'] as List?)?.length ?? 0} sets completed'),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _HistoryTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final weekly = stats['weekly'] as Map<String, dynamic>? ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _historyRow(Icons.check_circle_outline, 'Workouts this week', '${weekly['workouts_completed'] ?? 0}', Colors.green),
        _historyRow(Icons.local_fire_department_outlined, 'Calories Burned', '${weekly['calories_burned'] ?? 0}', Colors.orange),
        _historyRow(Icons.directions_run, 'Total Steps', '${weekly['total_steps'] ?? 0}', Colors.blue),
      ],
    );
  }

  Widget _historyRow(IconData icon, String label, String value, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}

// --- UTILS ---
class _NotesSection extends StatelessWidget {
  final List<dynamic> notes;
  final TextEditingController controller;
  final VoidCallback onSend;

  const _NotesSection({required this.notes, required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: AppColors.border)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Private Coaching Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller, 
                  decoration: const InputDecoration(hintText: 'Add a note...', border: InputBorder.none)
                )
              ),
              IconButton(onPressed: onSend, icon: const Icon(Icons.send, color: AppColors.primary)),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const Divider(),
            // 🔥 TRICK: Show up to 3 most recent notes instead of just 1
            ...notes.take(3).map((n) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        n['content'] ?? '', 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis, 
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.background, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}