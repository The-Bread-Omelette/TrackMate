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
void _showBookingDialog(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null) return;

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;

    final scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    
    if (!context.mounted) return;
    try {
      await widget.ds.scheduleSession(widget.studentId, scheduled, 60, "Standard 1-on-1 check-in");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session booked successfully!')));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to book session')));
    }
  }
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this); // 🔥 Increased to 4 tabs
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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

  Future<void> _addNote() async {
    if (_noteCtrl.text.trim().isEmpty) return;
    try {
      await widget.ds.addNote(widget.studentId, _noteCtrl.text.trim());
      _noteCtrl.clear();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note added')));
    } catch (_) {}
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
          // 🔥 Message Student Button
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
            onPressed: () async {
              try {
                final msgDs = sl<MessagingRemoteDataSource>();
                final convData = await msgDs.startConversation(widget.studentId);
                if (context.mounted) {
                  final authState = context.read<AuthBloc>().state as AuthAuthenticatedState;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        conversationId: convData['conversation_id'],
                        otherUserId: widget.studentId,
                        otherUserName: widget.studentName,
                        ds: msgDs,
                        currentUserId: authState.user.id,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start chat')));
              }
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
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
                    onSend: _addNote,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        TabBar(
                          controller: _tabs,
                          labelColor: Colors.white,
                          unselectedLabelColor: AppColors.textSecondary,
                          indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          tabs: const [
                            Tab(text: 'Profile'), // 🔥 New Tab
                            Tab(text: 'Diet'),
                            Tab(text: 'Workouts'),
                            Tab(text: 'History'),
                          ],
                        ),
                        SizedBox(
                          height: 350,
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _ProfileTab(detail: _detail), // 🔥 New Tab Content
                              _NutritionTab(nutrition: _nutrition),
                              _WorkoutsTab(workouts: _workouts),
                              _HistoryTab(stats: _stats),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _topStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// 🔥 NEW: Profile Tab to show basic student info
class _ProfileTab extends StatelessWidget {
  final Map<String, dynamic> detail;
  const _ProfileTab({required this.detail});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoRow(Icons.height, 'Height', '${detail['height_cm'] ?? '--'} cm'),
        const Divider(),
        _infoRow(Icons.monitor_weight_outlined, 'Weight', '${detail['weight_kg'] ?? '--'} kg'),
        const Divider(),
        _infoRow(Icons.directions_walk, 'Step Goal', '${detail['daily_step_goal'] ?? '--'}'),
        const Divider(),
        _infoRow(Icons.local_fire_department_outlined, 'Calorie Goal', '${detail['daily_calorie_goal'] ?? '--'} kcal'),
        const Divider(),
        _infoRow(Icons.directions_run, 'Activity Level', detail['activity_level'] ?? '--'),
        if (detail['bio'] != null) ...[
          const Divider(),
          const Text('Bio', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(detail['bio'], style: const TextStyle(fontSize: 14)),
        ]
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  final List<dynamic> notes;
  final TextEditingController controller;
  final VoidCallback onSend;

  const _NotesSection({required this.notes, required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text('Coaching Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 2,
            decoration: InputDecoration(hintText: 'Add a private note about this student...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(onPressed: onSend, icon: const Icon(Icons.add, size: 14), label: const Text('Add Note')),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...notes.map((n) {
              final note = n as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('You', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(_formatDate(note['created_at'] ?? ''), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(note['content'] ?? '', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }
}

class _NutritionTab extends StatelessWidget {
  final Map<String, dynamic> nutrition;
  const _NutritionTab({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final summary = nutrition['summary'] as Map<String, dynamic>? ?? {};
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Calories', '${summary['total_calories'] ?? 0} kcal'),
          _row('Protein', '${summary['total_protein_g'] ?? 0}g'),
          _row('Carbs', '${summary['total_carbs_g'] ?? 0}g'),
          _row('Fat', '${summary['total_fat_g'] ?? 0}g'),
          _row('Meals logged', '${summary['meal_count'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _WorkoutsTab extends StatelessWidget {
  final List<dynamic> workouts;
  const _WorkoutsTab({required this.workouts});

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) return const Center(child: Text('No workouts yet', style: TextStyle(color: AppColors.textMuted)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: workouts.length,
      itemBuilder: (_, i) {
        final w = workouts[i] as Map<String, dynamic>;
        return ListTile(
          leading: const Icon(Icons.fitness_center, color: AppColors.primary),
          title: Text(w['name'] ?? 'Workout'),
          subtitle: Text('${(w['sets'] as List?)?.length ?? 0} sets'),
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
      padding: const EdgeInsets.all(12),
      children: [
        ListTile(leading: const Icon(Icons.fitness_center, color: Colors.blue), title: const Text('Workouts this week'), trailing: Text('${weekly['workouts_completed'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))),
        ListTile(leading: const Icon(Icons.local_fire_department, color: Colors.orange), title: const Text('Calories burned'), trailing: Text('${(weekly['calories_burned'] ?? 0).toStringAsFixed(0)} kcal', style: const TextStyle(fontWeight: FontWeight.bold))),
        ListTile(leading: const Icon(Icons.directions_walk, color: AppColors.success), title: const Text('Total steps'), trailing: Text('${weekly['total_steps'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))),
        ListTile(leading: const Icon(Icons.star, color: Colors.amber), title: const Text('Streak'), trailing: Text('${stats['streak_days'] ?? 0} days', style: const TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}