import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/constants/api_constants.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/dashboard/presentation/bloc/dashboard_event.dart';
import '../../features/dashboard/presentation/bloc/dashboard_state.dart';
import '../../shared/widgets/main_layout.dart';
import '../theme/app_theme.dart';
import '../../features/trainer/data/trainer_remote_datasource.dart';
import '../../features/messaging/data/messaging_remote_datasource.dart';
import '../../features/messaging/presentation/pages/chat_page.dart';
import '../../features/trainer/presentation/pages/find_trainer_page.dart';
import '../../features/trainer/presentation/pages/coaching_hub_page.dart';
import '../../features/nutrition/presentation/pages/food_logging_page.dart';
import '../../features/workout/presentation/pages/exercise_page.dart';
import 'package:dio/dio.dart';
import '../../../main.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';

// 🔥 HELPER: Centralized modern card decoration for aesthetics
BoxDecoration _modernCardDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
    border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
  );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticatedState ? authState.user : null;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BlocProvider(
      create: (_) => sl<DashboardBloc>()..add(const DashboardLoad()),
      child: MainLayout(
        user: user,
        title: 'Dashboard',
        child: _DashboardBody(user: user),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final dynamic user;
  const _DashboardBody({required this.user});

  @override
  Widget build(BuildContext context) {
    final isTrainer = user.role.toString().toLowerCase().contains('trainer');

    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading || state is DashboardInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is DashboardError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.message, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<DashboardBloc>().add(const DashboardLoad()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final data = (state as DashboardLoaded).data;

        return RefreshIndicator(
          onRefresh: () async => context.read<DashboardBloc>().add(const DashboardLoad()),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Aesthetic Greeting Header
                Text(
                  'Hello, ${user.fullName.split(' ').first} 👋',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Here's your progress for today.",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 20),

                _MyTrainerCard(isTrainer: isTrainer),
                if (!isTrainer) const SizedBox(height: 16),

                // BMI Card
                _BMICard(key: ValueKey(state.hashCode)),
                const SizedBox(height: 16),

                _StepsCard(data: data),
                const SizedBox(height: 16),
                _CalorieCard(data: data),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _WaterCard(data: data)),
                    const SizedBox(width: 16),
                    Expanded(child: _StatsCard(data: data)),
                  ],
                ),
                const SizedBox(height: 16),

                _DynamicInsightCard(
                    key: ValueKey('insight_${state.hashCode}'),
                    data: data
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── SMART BMI CARD ─────────────────────────────────────────────────────────────

class _BMICard extends StatefulWidget {
  const _BMICard({super.key});

  @override
  State<_BMICard> createState() => _BMICardState();
}

class _BMICardState extends State<_BMICard> {
  double? _heightCm;
  double? _weightKg;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchBiometrics();
  }

  Future<void> _fetchBiometrics() async {
    try {
      final dio = sl<Dio>();
      final res = await dio.get(ApiConstants.profile);
      final p = res.data['profile'] as Map<String, dynamic>? ?? {};

      if (mounted) {
        setState(() {
          _heightCm = (p['height_cm'] as num?)?.toDouble();
          _weightKg = (p['weight_kg'] as num?)?.toDouble();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: _modernCardDecoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_heightCm == null || _weightKg == null || _heightCm! <= 0 || _weightKg! <= 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _modernCardDecoration(),
        child: Row(
          children: [
            const Icon(Icons.monitor_weight_outlined, color: AppColors.textMuted, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('BMI Calculator', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Add height & weight in settings', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final double heightMeters = _heightCm! / 100;
    final double bmi = _weightKg! / (heightMeters * heightMeters);

    String category = '';
    Color badgeColor = Colors.grey;

    if (bmi < 18.5) {
      category = 'Underweight';
      badgeColor = Colors.blue;
    } else if (bmi >= 18.5 && bmi < 24.9) {
      category = 'Normal';
      badgeColor = AppColors.success;
    } else if (bmi >= 25 && bmi < 29.9) {
      category = 'Overweight';
      badgeColor = Colors.orange;
    } else {
      category = 'Obese';
      badgeColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _modernCardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Body Mass Index', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(bmi.toStringAsFixed(1), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Text('BMI', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              category,
              style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── EXISTING CARDS ──────────────────────────────────────────────────────────

class _StepsCard extends StatelessWidget {
  final data;
  const _StepsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AnalyticsPage(initialView: 0)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: _modernCardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Daily Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            StreamBuilder<int>(
                stream: globalPedometer.steps,
                initialData: data.steps,
                builder: (context, snapshot) {
                  final liveSteps = snapshot.data ?? 0;
                  final double livePercentage = data.stepGoal > 0 ? (liveSteps / data.stepGoal * 100) : 0;
                  final int remaining = (data.stepGoal - liveSteps) > 0 ? (data.stepGoal - liveSteps) : 0;

                  return Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: CircularProgressIndicator(
                              value: (livePercentage / 100).clamp(0.0, 1.0),
                              strokeWidth: 12,
                              backgroundColor: AppColors.border.withValues(alpha: 0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                liveSteps.toString(),
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                              const Text('steps', style: TextStyle(color: AppColors.textSecondary)),
                              Text(
                                '${livePercentage.toStringAsFixed(0)}% of goal',
                                style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Goal: ${data.stepGoal} steps', style: const TextStyle(color: AppColors.textPrimary)),
                      Text('$remaining steps to go!', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  );
                }
            ),

            if (data.streakDays > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text('${data.streakDays} day streak', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  final data;
  const _CalorieCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final net = data.caloriesBurned - data.caloriesEaten;
    final isDeficit = net >= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calorie Balance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          _calRow(Icons.restaurant, Colors.orange, 'Calories Eaten',
              '${data.caloriesEaten.toStringAsFixed(0)} kcal', Colors.orange.shade50),
          const SizedBox(height: 12),
          _calRow(Icons.local_fire_department, AppColors.success, 'Calories Burned',
              '${data.caloriesBurned.toStringAsFixed(0)} kcal', Colors.green.shade50),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Net Balance', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${isDeficit ? '+' : ''}${net.toStringAsFixed(0)} kcal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDeficit ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              isDeficit
                  ? "You're in a caloric deficit — great for weight loss!"
                  : "You've exceeded your burn — consider light activity",
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _calRow(IconData icon, Color color, String label, String value, Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _DynamicInsightCard extends StatefulWidget {
  final dynamic data;
  const _DynamicInsightCard({super.key, required this.data});

  @override
  State<_DynamicInsightCard> createState() => _DynamicInsightCardState();
}

class _DynamicInsightCardState extends State<_DynamicInsightCard> {
  String? _activityLevel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchActivityLevel();
  }

  Future<void> _fetchActivityLevel() async {
    try {
      final dio = sl<Dio>();
      final res = await dio.get(ApiConstants.profile);
      if (mounted) {
        setState(() {
          _activityLevel = res.data['profile']?['activity_level'] ?? 'moderately_active';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _modernCardDecoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final net = widget.data.caloriesEaten - widget.data.caloriesBurned;
    final insight = InsightEngine.getInsight(_activityLevel, net.toDouble());

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _modernCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🔥 Cleaned up header, gracefully centered with slight letter spacing
          const Center(
            child: Text(
              'Daily Insight',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: insight.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(insight.icon, color: insight.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        insight.title,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: insight.color)
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Net Calories: ${net > 0 ? '+' : ''}${net.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 🔥 Upgraded, beautiful, full-width elegant quote box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: insight.color.withValues(alpha: 0.15)),
            ),
            child: Text(
              "\"${insight.description}\"",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  final data;
  const _WaterCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FoodLoggingPage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: _modernCardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_drop, color: Colors.blue, size: 32),
            const SizedBox(height: 16),
            Text('${data.waterLitres.toStringAsFixed(1)}L',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('Water Intake', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (data.waterPercentage / 100).clamp(0.0, 1.0),
              backgroundColor: AppColors.border.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text('of ${data.waterGoalLitres.toStringAsFixed(1)}L goal',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final data;
  const _StatsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExercisePage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: _modernCardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, color: Colors.orange, size: 32),
            const SizedBox(height: 16),
            Text('${data.workoutsThisWeek}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('Workouts', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            const Text('this week', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _MyTrainerCard extends StatefulWidget {
  final bool isTrainer;
  const _MyTrainerCard({required this.isTrainer});

  @override
  State<_MyTrainerCard> createState() => _MyTrainerCardState();
}

class _MyTrainerCardState extends State<_MyTrainerCard> {
  Map<String, dynamic>? _trainer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (!widget.isTrainer) {
      _loadTrainer();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadTrainer() async {
    try {
      final ds = sl<TrainerRemoteDataSource>();
      final trainer = await ds.getMyTrainer();
      if (mounted) setState(() => _trainer = trainer);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _quitTrainer() async {
    try {
      await sl<TrainerRemoteDataSource>().dio.post('${ApiConstants.apiVersion}/trainer/quit');
      if (mounted) {
        setState(() => _trainer = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have left your trainer.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to quit trainer.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isTrainer) {
      return const SizedBox.shrink();
    }

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_trainer == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.person_search, size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            const Text('No Active Trainer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text('Get personalized guidance and plans.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FindTrainerPage()))
                    .then((_) => _loadTrainer());
              },
              child: const Text('Find a Trainer'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text((_trainer!['full_name'] as String? ?? 'T')[0].toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Assigned Trainer', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(_trainer!['full_name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2)),
            onPressed: () async {
              try {
                final msgDs = sl<MessagingRemoteDataSource>();
                final trainerId = _trainer!['id'];
                final convData = await msgDs.startConversation(trainerId);
                if (mounted) {
                  final authState = context.read<AuthBloc>().state as AuthAuthenticatedState;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(conversationId: convData['conversation_id'], otherUserId: trainerId, otherUserName: _trainer!['full_name'], ds: msgDs, currentUserId: authState.user.id)));
                }
              } catch (_) {}
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              if (val == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CoachingHubPage(trainerInfo: _trainer!)),
                );
              } else if (val == 'quit') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Quit Trainer?'),
                    content: const Text('Are you sure you want to stop working with this trainer?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () { Navigator.pop(ctx); _quitTrainer(); },
                        child: const Text('Quit', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'profile', child: Text('View Profile')),
              const PopupMenuItem(value: 'quit', child: Text('Quit Trainer', style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }
}

class InsightData {
  final String title;
  final String description;
  final Color color;
  final IconData icon;

  InsightData(this.title, this.description, this.color, this.icon);
}

class InsightEngine {
  static InsightData getInsight(String? activityLevel, double netCalories) {
    final level = activityLevel?.toLowerCase() ?? 'moderately_active';

    // Sedentary (Little/No Exercise)
    if (level == 'sedentary') {
      if (netCalories < -500) return InsightData('Dangerously Low Energy', 'You are inactive, but undereating this severely can slow your metabolism.', AppColors.error, Icons.warning_amber_rounded);
      if (netCalories < -100) return InsightData('Light Cut', 'A good steady deficit for weight loss with a sedentary lifestyle.', AppColors.success, Icons.trending_down);
      if (netCalories <= 200) return InsightData('Maintaining Status Quo', 'You are perfectly balanced, but watch out for calorie creep!', Colors.blue, Icons.balance);
      if (netCalories <= 500) return InsightData('Creeping Up', 'You are in a surplus. Since you aren\'t moving much, this may turn to fat.', Colors.orange, Icons.trending_up);
      return InsightData('High Gain Risk', 'High surplus with low activity. Try to add a 30-minute walk today!', AppColors.error, Icons.directions_walk);
    }

    // Lightly Active (1-3 days/week)
    if (level == 'lightly_active') {
      if (netCalories < -500) return InsightData('Aggressive Cut', 'You might feel fatigued during your light workouts. Be careful.', Colors.orange, Icons.battery_alert);
      if (netCalories < -100) return InsightData('Steady Burn', 'Optimal balance for healthy, sustainable weight loss.', AppColors.success, Icons.local_fire_department);
      if (netCalories <= 200) return InsightData('Perfectly Maintained', 'Eating exactly right for your light movement.', Colors.blue, Icons.check_circle_outline);
      if (netCalories <= 500) return InsightData('Slight Overfeed', 'A minor surplus. Consider adding a short jog to balance it.', Colors.orange, Icons.directions_run);
      return InsightData('Outpacing Burn', 'Eating a bit too much for your current activity level.', AppColors.error, Icons.fastfood);
    }

    // Moderately Active (3-5 days/week)
    if (level == 'moderately_active') {
      if (netCalories < -500) return InsightData('Under-fueling', 'You train often! Feed your body so you don\'t lose muscle.', AppColors.error, Icons.restaurant);
      if (netCalories < -100) return InsightData('Lean Down Phase', 'Great for cutting body fat while maintaining training.', AppColors.success, Icons.fitness_center);
      if (netCalories <= 200) return InsightData('Prime Performance', 'Exactly what your body needs to perform and recover.', Colors.blue, Icons.bolt);
      if (netCalories <= 500) return InsightData('Lean Muscle Building', 'A great slight surplus for building muscle slowly.', AppColors.success, Icons.add_circle_outline);
      return InsightData('Calorie Spillover', 'Eating more than your muscles need to recover. Scale it back.', Colors.orange, Icons.warning);
    }

    // Very Active (6-7 days/week)
    if (level == 'very_active') {
      if (netCalories < -500) return InsightData('Crash Warning', 'Extreme deficit! High risk of muscle loss and severe fatigue.', AppColors.error, Icons.warning_amber_rounded);
      if (netCalories < -100) return InsightData('Athletic Cut', 'Keep your protein high to protect your muscles during this cut.', Colors.orange, Icons.shield);
      if (netCalories <= 200) return InsightData('Optimal Fueling', 'Incredible energy balance for your heavy training schedule.', Colors.blue, Icons.battery_charging_full);
      if (netCalories <= 500) return InsightData('Anabolic Zone', 'Perfect surplus for fueling hard workouts and muscle growth.', AppColors.success, Icons.trending_up);
      return InsightData('Aggressive Bulk', 'High surplus. Ensure you are lifting heavy to use this energy!', Colors.purple, Icons.fitness_center);
    }

    // Extra Active (Physical Job / Athlete)
    if (level == 'extra_active') {
      if (netCalories < -500) return InsightData('Severe Depletion', 'EAT! You are burning massive energy and need fuel to survive.', AppColors.error, Icons.local_dining);
      if (netCalories < -100) return InsightData('Slight Undereating', 'Careful with your recovery. Your body is under high stress.', Colors.orange, Icons.health_and_safety);
      if (netCalories <= 200) return InsightData('Machine Fueled', 'Perfect balance for extreme daily physical output.', Colors.blue, Icons.settings);
      if (netCalories <= 500) return InsightData('Recovery Mode', 'Needed surplus to rebuild muscle after exhausting days.', AppColors.success, Icons.build);
      return InsightData('Max Calorie Intake', 'A massive surplus. Make sure it\'s coming from clean, nutritious foods.', Colors.purple, Icons.restaurant_menu);
    }

    // Fallback just in case
    return InsightData('Logging Data', 'Keep tracking your meals and workouts to see your insights.', Colors.grey, Icons.analytics);
  }
}
