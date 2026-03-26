import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/trainer_remote_datasource.dart';
import 'student_detail_page.dart';

class TrainerStudentsPage extends StatefulWidget {
  const TrainerStudentsPage({super.key});

  @override
  State<TrainerStudentsPage> createState() => _TrainerStudentsPageState();
}

class _TrainerStudentsPageState extends State<TrainerStudentsPage> {
  final _ds = TrainerRemoteDataSource(sl());
  List<dynamic> _students = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _ds.getStudents(),
        _ds.getStats(),
      ]);
      setState(() {
        _students = results[0] as List<dynamic>;
        _stats = results[1] as Map<String, dynamic>;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    // final user = (context.read<AuthBloc>().state as AuthAuthenticatedState).user;
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticatedState ? authState.user : null;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return MainLayout(
      user: user,
      title: 'My Students',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AiInsightsCard(students: _students),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StatCard(Icons.people_outline, 'Students',
                            '${_stats['total_students'] ?? 0}'),
                        const SizedBox(width: 12),
                        _StatCard(Icons.trending_up, 'Adherence',
                            '${_stats['avg_adherence'] ?? 0}%',
                            color: AppColors.success),
                        const SizedBox(width: 12),
                        _StatCard(Icons.error_outline, 'Attention',
                            '${_stats['needs_attention'] ?? 0}',
                            color: AppColors.error),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Active Students',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _students.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (context, i) {
                          final s = _students[i] as Map<String, dynamic>;
                          final adherence = (s['adherence'] as num).toInt();
                          final needsAttention = s['needs_attention'] == true;
                          final color = needsAttention
                              ? AppColors.error
                              : adherence >= 80
                                  ? AppColors.success
                                  : AppColors.primary;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: Text(
                                (s['full_name'] as String? ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(s['full_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: adherence / 100,
                                    backgroundColor: AppColors.border,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(color),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                needsAttention ? 'Attention' : '$adherence%',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentDetailPage(
                                    studentId: s['id'] as String,
                                    studentName: s['full_name'] as String? ?? '',
                                    ds: _ds),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _AiInsightsCard extends StatelessWidget {
  final List<dynamic> students;
  const _AiInsightsCard({required this.students});

  @override
  Widget build(BuildContext context) {
    final excellent = students
        .where((s) => (s['adherence'] as num) >= 90)
        .length;
    final attention = students
        .where((s) => s['needs_attention'] == true)
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B42FA), Color(0xFFB042FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('AI Weekly Insights',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (excellent > 0)
            _insight('$excellent students', ' exceeding goals with 90%+ adherence.'),
          if (attention > 0) ...[
            const SizedBox(height: 8),
            _insight('$attention students',
                " haven't been active and may need check-ins."),
          ],
          if (excellent == 0 && attention == 0)
            const Text('All students are on track this week.',
                style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _insight(String bold, String normal) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        children: [
          TextSpan(
              text: bold,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: normal),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard(this.icon, this.label, this.value,
      {this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}