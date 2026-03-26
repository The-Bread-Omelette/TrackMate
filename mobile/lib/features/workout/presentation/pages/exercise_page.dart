import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/workout_remote_datasource.dart';
import 'cardio_timer_page.dart'; // REQUIRED IMPORT
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';

class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key});

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  late final WorkoutRemoteDataSource _ds;
  List<dynamic> _history = [];
  bool _loading = true;
  final _weightCtrl = TextEditingController();
  late PedometerService _pedometer;
  int _liveSteps = 0;
  List<dynamic> _stepsHistory = [];

  @override
  void initState() {
    super.initState();
    _ds = WorkoutRemoteDataSource(sl<Dio>());
    _pedometer = PedometerService();
    if (!kIsWeb) {
      _pedometer.start();
      _pedometer.steps.listen((s) {
        if (mounted) setState(() => _liveSteps = s);
      });
    }
    _load();
  }

  @override
  void dispose() {
    _pedometer.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _history = await _ds.getSessionHistory();
    } catch (_) {}

    try {
      final res = await sl<Dio>().get('/api/v1/fitness/steps/history', queryParameters: {'days': 7});
      if (mounted) setState(() => _stepsHistory = res.data as List<dynamic>);
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _startQuickSession(String name) async {
    try {
      final session = await _ds.startSession(name: name);
      final sessionId = session['session_id'] as String;
      await _ds.finishSession(sessionId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name session logged')));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticatedState ? authState.user : null;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MainLayout(
      user: user,
      title: 'Exercise',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!kIsWeb) ...[
                    _StepCounterCard(
                      liveSteps: _liveSteps,
                      onLog: () async {
                        await _ds.startSession(name: 'Walk');
                        await sl<Dio>().post('/api/v1/fitness/steps', data: {'steps': _liveSteps});
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Steps logged')));
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text('Track your workouts', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _ExerciseTypeCard(
                          emoji: '💪',
                          title: 'Gym Session',
                          subtitle: 'Log sets & weight',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GymSessionPage(ds: _ds, stepsHistory: _stepsHistory),
                            ),
                          ).then((_) => _load()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExerciseTypeCard(
                          emoji: '🏃',
                          title: 'Cardio',
                          subtitle: 'Timer & Tracking',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CardioTimerPage()),
                          ).then((_) => _load()),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  const Text('Recent Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  if (_history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No sessions yet', style: TextStyle(color: AppColors.textMuted))),
                    )
                  else
                    ..._history.map((s) {
                      final session = s as Map<String, dynamic>;
                      final sets = (session['sets'] as List?) ?? [];
                      return _SessionCard(
                        session: session,
                        sets: sets,
                        formattedDate: _formatDate(session['started_at'] ?? ''),
                      );
                    }),

                  const SizedBox(height: 32),
                  const Text('Log Weight', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _WeightLogCard(
                    controller: _weightCtrl,
                    onLog: () async {
                      final w = double.tryParse(_weightCtrl.text);
                      if (w == null) return;
                      try {
                        await sl<Dio>().post('/api/v1/fitness/weight', data: {'weight_kg': w});
                        _weightCtrl.clear();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Weight logged')));
                        }
                      } catch (_) {}
                    },
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Extracted Web-Safe Sub-Widgets
// ---------------------------------------------------------------------------

class _StepCounterCard extends StatelessWidget {
  final int liveSteps;
  final VoidCallback onLog;
  const _StepCounterCard({required this.liveSteps, required this.onLog});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_walk, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Steps Today (Live)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text('$liveSteps', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: onLog, 
            child: const Text('Log')
          ),
        ],
      ),
    );
  }
}

class _ExerciseTypeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExerciseTypeCard({required this.emoji, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final List<dynamic> sets;
  final String formattedDate;

  const _SessionCard({required this.session, required this.sets, required this.formattedDate});

  @override
  Widget build(BuildContext context) {
    final String name = session['name'] ?? 'Workout';
    final String imgName = name.toLowerCase().replaceAll(' ', '_');
    final bool isGym = name.contains('Gym') || name.contains('Workout');
    
    // Calculates Cardio Duration
    String durationText = '';
    if (session['started_at'] != null && session['ended_at'] != null) {
      try {
        final start = DateTime.parse(session['started_at']);
        final end = DateTime.parse(session['ended_at']);
        final diff = end.difference(start);
        if (diff.inMinutes > 0) {
          durationText = '${diff.inMinutes} min';
        } else if (diff.inSeconds > 0) {
          durationText = '${diff.inSeconds} sec';
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Render Local Asset Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/${isGym ? 'barbell_squat' : imgName}.jpg',
              width: 50, height: 50, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 50, height: 50, color: AppColors.background,
                child: Icon(isGym ? Icons.fitness_center : Icons.directions_run, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  durationText.isNotEmpty ? durationText : '${sets.length} sets', 
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)
                ),
              ],
            ),
          ),
          Text(formattedDate, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _WeightLogCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onLog;

  const _WeightLogCard({required this.controller, required this.onLog});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Weight in kg', labelText: "Today's Weight"),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: onLog, 
            child: const Text('Log')
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gym Session Page (Completely decoupled and safe)
// ---------------------------------------------------------------------------

class GymSessionPage extends StatefulWidget {
  final WorkoutRemoteDataSource ds;
  final List<dynamic> stepsHistory;
  const GymSessionPage({super.key, required this.ds, required this.stepsHistory});

  @override
  State<GymSessionPage> createState() => _GymSessionPageState();
}

class _GymSessionPageState extends State<GymSessionPage> {
  String? _sessionId;
  final List<Map<String, dynamic>> _sets = [];
  List<dynamic> _exercises = [];
  Map<String, dynamic>? _selectedExercise;
  final _repsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  bool _starting = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() => _starting = true);
    try {
      final session = await widget.ds.startSession(name: 'Gym Session');
      setState(() => _sessionId = session['session_id'] as String);
      _exercises = await widget.ds.searchExercises();
      if (_exercises.isNotEmpty) {
        _selectedExercise = _exercises.first as Map<String, dynamic>;
      }
    } catch (_) {}
    if (mounted) setState(() => _starting = false);
  }

  Future<void> _logSet() async {
    if (_sessionId == null || _selectedExercise == null) return;
    final reps = int.tryParse(_repsCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);
    if (reps == null) return;

    // OPTIMISTIC UI UPDATE: Update instantly before backend call to prevent freeze
    setState(() {
      _sets.add({
        'exercise': _selectedExercise!['name'],
        'reps': reps,
        'weight': weight,
      });
      _repsCtrl.clear();
      _weightCtrl.clear();
    });

    try {
      await widget.ds.logSet(_sessionId!, {
        'exercise_id': _selectedExercise!['id'],
        'set_number': _sets.length, // Already added locally, so length is the new set number
        'reps': reps,
        'weight_kg': weight,
      });
    } catch (_) {}
  }

  Future<void> _finish() async {
    if (_sessionId == null) return;
    setState(() => _finishing = true);
    try {
      await widget.ds.finishSession(_sessionId!);
      if (mounted) Navigator.pop(context);
    } catch (_) {}
    if (mounted) setState(() => _finishing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gym Session', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _finishing ? null : _finish,
            child: _finishing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Finish', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _starting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_selectedExercise != null) ...[
                  // Dynamic Image Rendering for Current Exercise
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/${_selectedExercise!['name'].toLowerCase().replaceAll(' ', '_')}.jpg',
                      height: 180, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 180, color: AppColors.surface, child: const Icon(Icons.fitness_center, size: 64, color: AppColors.textMuted)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_exercises.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Exercise', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedExercise,
                          isExpanded: true,
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: _exercises.map((e) {
                            final ex = e as Map<String, dynamic>;
                            return DropdownMenuItem(value: ex, child: Text(ex['name'] ?? ''));
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedExercise = v),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _repsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reps'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (kg)'))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                                onPressed: _logSet,
                                icon: const Icon(Icons.add),
                                label: const Text('Log Set'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_sets.isNotEmpty) ...[
                  const Text('Sets Logged', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._sets.asMap().entries.map((e) {
                    final s = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(s['exercise'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                          Text('${s['reps']} reps${s['weight'] != null ? ' · ${s['weight']}kg' : ''}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 24),
                const Text('Steps This Week', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: widget.stepsHistory.isEmpty
                      ? const Text('No step data yet', style: TextStyle(color: AppColors.textMuted))
                      : Column(
                          children: widget.stepsHistory.map((s) {
                            final entry = s as Map<String, dynamic>;
                            final steps = (entry['steps'] as num).toInt();
                            final date = entry['date'] as String;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(date.substring(5), style: const TextStyle(color: AppColors.textSecondary)),
                                  Row(children: [
                                    Text('$steps steps', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 100,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: (steps / 10000).clamp(0.0, 1.0),
                                          backgroundColor: AppColors.border,
                                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
    );
  }
}

class PedometerService {
  void start() {}
  Stream<int> get steps => const Stream.empty();
  void dispose() {}
}