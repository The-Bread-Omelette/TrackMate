import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/workout_remote_datasource.dart';
import 'cardio_timer_page.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
// 🔥 IMPORT YOUR ANALYTICS PAGE HERE (Adjust path if needed)
import '../../../analytics/presentation/pages/analytics_page.dart';

// 🔥 Hardcoded CSV Data containing types and multipliers
const List<Map<String, dynamic>> localExercises = [
  {"id": "1", "name": "Barbell Squat", "type": "strength", "multiplier": 3.0, "image": "assets/images/barbell_squat.jpg"},
  {"id": "2", "name": "Push-up", "type": "strength", "multiplier": 4.0, "image": "assets/images/push_up.jpg"},
  {"id": "3", "name": "Deadlift", "type": "strength", "multiplier": 3.0, "image": "assets/images/deadlift.jpg"},
  {"id": "4", "name": "Pull-up", "type": "strength", "multiplier": 4.0, "image": "assets/images/pull_up.jpg"},
  {"id": "5", "name": "Plank", "type": "time", "multiplier": 1.75, "image": "assets/images/plank.jpg"},
  {"id": "6", "name": "Running", "type": "time", "multiplier": 4.8, "image": "assets/images/running.jpg"},
  {"id": "7", "name": "Dumbbell Bicep Curl", "type": "strength", "multiplier": 1.75, "image": "assets/images/dumbbell_bicep_curl.jpg"},
  {"id": "8", "name": "Burpee", "type": "time", "multiplier": 4.25, "image": "assets/images/burpee.jpg"},
  {"id": "9", "name": "Russian Twist", "type": "strength", "multiplier": 2.0, "image": "assets/images/russian_twist.jpg"},
  {"id": "10", "name": "Lunges", "type": "strength", "multiplier": 2.5, "image": "assets/images/lunges.jpg"},
];

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

  int _currentPage = 1;
  final int _itemsPerPage = 5;
  DateTime? _selectedDate;

  // 🔥 DECLARED HERE SO THE WHOLE CLASS CAN ACCESS THEM
  double _userWeight = 70.0;
  double _userHeight = 175.0;

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
    
    // 1. Fetch Session History
    try {
      _history = await _ds.getSessionHistory(limit: 100); 
    } catch (_) {}

    // 2. Fetch Step History
    try {
      final res = await sl<Dio>().get('/api/v1/fitness/steps/history', queryParameters: {'days': 7});
      if (mounted) setState(() => _stepsHistory = res.data as List<dynamic>);
    } catch (_) {}

    // 🔥 3. THE NO-BACKEND-CHANGE FIX: Grab latest weight from the existing Trends API!
    try {
      final weightRes = await sl<Dio>().get('/api/v1/fitness/weight/trend', queryParameters: {'days': 30}); 
      if (mounted && weightRes.data != null) {
        final List<dynamic> trendData = weightRes.data as List<dynamic>;
        if (trendData.isNotEmpty) {
          setState(() {
            // Grabs the very last logged weight in the array
            _userWeight = (trendData.last['weight_kg'] as num).toDouble();
          });
        }
      }
    } catch (e) {
      debugPrint("Could not load weight trend: $e");
    }

    if (mounted) setState(() => _loading = false);
  }
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _currentPage = 1; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticatedState ? authState.user : null;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    List<dynamic> filteredHistory = _history;
    if (_selectedDate != null) {
      final dateString = _selectedDate!.toIso8601String().substring(0, 10);
      filteredHistory = _history.where((s) => s['started_at'].toString().startsWith(dateString)).toList();
    }

    final int totalPages = (filteredHistory.isEmpty) ? 1 : (filteredHistory.length / _itemsPerPage).ceil();
    final int startIndex = (_currentPage - 1) * _itemsPerPage;
    final int endIndex = (startIndex + _itemsPerPage > filteredHistory.length) ? filteredHistory.length : startIndex + _itemsPerPage;
    final List<dynamic> paginatedHistory = filteredHistory.isEmpty ? [] : filteredHistory.sublist(startIndex, endIndex);

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatChip(icon: Icons.height, label: 'Height', value: '${_userHeight}cm'),
                      _StatChip(icon: Icons.scale, label: 'Weight', value: '${_userWeight}kg'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (!kIsWeb) ...[
                    _StepCounterCard(
                      liveSteps: _liveSteps,
                      onLog: () async {
                        await _ds.startSession(name: 'Walk');
                        await sl<Dio>().post('/api/v1/fitness/steps', data: {'steps': _liveSteps});
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Steps logged')));
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
                          emoji: '💪', title: 'Gym Session', subtitle: 'Log sets & weight',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GymSessionPage(ds: _ds, userWeightKg: _userWeight))).then((_) => _load()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExerciseTypeCard(
                          emoji: '🏃', title: 'Cardio', subtitle: 'Timer & Tracking',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardioTimerPage(userWeightKg: _userWeight))).then((_) => _load()),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          if (_selectedDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red, size: 20),
                              onPressed: () => setState(() { _selectedDate = null; _currentPage = 1; }),
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month, color: AppColors.primary),
                            onPressed: _pickDate,
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (filteredHistory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No sessions found', style: TextStyle(color: AppColors.textMuted))),
                    )
                  else ...[
                    ...paginatedHistory.map((s) {
                      final session = s as Map<String, dynamic>;
                      final sets = (session['sets'] as List?) ?? [];
                      return _SessionCard(
                        session: session,
                        sets: sets,
                        formattedDate: _formatDate(session['started_at'] ?? ''),
                      );
                    }),
                    
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(totalPages, (index) {
                            int page = index + 1;
                            bool isActive = _currentPage == page;
                            return GestureDetector(
                              onTap: () => setState(() => _currentPage = page),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.primary : AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
                                ),
                                child: Center(
                                  child: Text('$page', style: TextStyle(color: isActive ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Log Weight', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        // 🔥 ROUTED TO DETAILED ANALYTICS VIEW
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsPage(initialView: 1))),
                        icon: const Icon(Icons.show_chart, size: 18),
                        label: const Text('Trends'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _WeightLogCard(
                    controller: _weightCtrl,
                    onLog: () async {
                      final w = double.tryParse(_weightCtrl.text);
                      if (w == null) return;
                      try {
                        await sl<Dio>().post('/api/v1/fitness/weight', data: {'weight_kg': w});
                        _weightCtrl.clear();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Weight logged')));
                        _load(); // Reload to refresh data
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
// Extracted Sub-Widgets
// ---------------------------------------------------------------------------

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}

class _StepCounterCard extends StatelessWidget {
  final int liveSteps;
  final VoidCallback onLog;
  const _StepCounterCard({required this.liveSteps, required this.onLog});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
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
          ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: onLog, child: const Text('Log')),
        ],
      ),
    );
  }
}

class _ExerciseTypeCard extends StatelessWidget {
  final String emoji, title, subtitle;
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
    
    final matchingExercise = localExercises.firstWhere((e) => e['name'] == name, orElse: () => <String,dynamic>{});
    final String imagePath = matchingExercise.isNotEmpty ? matchingExercise['image'] : 'assets/images/barbell_squat.jpg';
    final bool isGym = name.contains('Gym') || name.contains('Workout') || name.contains('Walk');

    // Display Note logic (where duration is stored)
    final String durationNote = session['notes'] ?? '';
    final String displaySubtitle = durationNote.isNotEmpty ? durationNote : '${sets.length} sets';
    
    // Format Calories
    final String calBurned = session['calories_burned'] != null && session['calories_burned'] > 0 
        ? '${(session['calories_burned'] as num).toStringAsFixed(0)} kcal' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              imagePath,
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
                Row(
                  children: [
                    Text(displaySubtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    if (calBurned.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                      Text(calBurned, style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]
                  ],
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
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Expanded(child: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Weight in kg', labelText: "Today's Weight"))),
          const SizedBox(width: 16),
          ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: onLog, child: const Text('Log')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gym Session Page (Adapts dynamically to Time vs Strength)
// ---------------------------------------------------------------------------

class GymSessionPage extends StatefulWidget {
  final WorkoutRemoteDataSource ds;
  final double userWeightKg;
  const GymSessionPage({super.key, required this.ds, required this.userWeightKg});
  @override
  State<GymSessionPage> createState() => _GymSessionPageState();
}

class _GymSessionPageState extends State<GymSessionPage> {
  String? _sessionId;
  final List<Map<String, dynamic>> _sets = [];
  Map<String, dynamic>? _selectedExercise;
  
  final _repsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(); 
  
  bool _starting = false;
  bool _finishing = false;
  
  late DateTime _sessionStartTime;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _startSession();
  }

  Future<void> _startSession() async {
    setState(() => _starting = true);
    try {
      final session = await widget.ds.startSession(name: 'Gym Session');
      setState(() => _sessionId = session['session_id'] as String);
      _selectedExercise = localExercises.first;
    } catch (_) {}
    if (mounted) setState(() => _starting = false);
  }

  Future<void> _logSet() async {
    if (_sessionId == null || _selectedExercise == null) return;
    
    bool isTime = _selectedExercise!['type'] == 'time';
    int? reps = int.tryParse(_repsCtrl.text);
    double? weight = double.tryParse(_weightCtrl.text);
    int? duration = int.tryParse(_durationCtrl.text);

    if (isTime && duration == null) return;
    if (!isTime && reps == null) return;

    setState(() {
      _sets.add({
        'exercise': _selectedExercise!['name'],
        'reps': reps,
        'weight': weight,
        'duration_seconds': duration,
        'isTime': isTime
      });
      _repsCtrl.clear();
      _weightCtrl.clear();
      _durationCtrl.clear();
    });

    try {
      await widget.ds.logSet(_sessionId!, {
        'exercise_id': "00000000-0000-0000-0000-000000000000", 
        'set_number': _sets.length,
        'reps': reps,
        'weight_kg': weight,
        'duration_seconds': duration,
      });
    } catch (_) {}
  }

  Future<void> _finish() async {
    if (_sessionId == null) return;
    setState(() => _finishing = true);
    try {
      final diff = DateTime.now().difference(_sessionStartTime);
      final int mins = diff.inMinutes;
      final int secs = diff.inSeconds % 60;
      final String durationStr = "${mins}m ${secs}s";

      final double totalMinutesFloat = diff.inSeconds / 60.0;
      final double calories = (totalMinutesFloat / 30.0) * 3.0 * widget.userWeightKg;

      await widget.ds.finishSession(
        _sessionId!, 
        caloriesBurned: calories,
        notes: durationStr 
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {}
    if (mounted) setState(() => _finishing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Gym Session'), backgroundColor: AppColors.surface, elevation: 0, actions: [
        TextButton(
          onPressed: _finishing ? null : _finish, 
          child: _finishing 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Finish', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
        ),
      ]),
      body: _starting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_selectedExercise != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      _selectedExercise!['image'],
                      height: 180, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 180, color: AppColors.surface, child: const Icon(Icons.fitness_center, size: 64)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedExercise,
                        isExpanded: true,
                        items: localExercises.map((e) => DropdownMenuItem(value: e, child: Text(e['name']))).toList(),
                        onChanged: (v) => setState(() {
                          _selectedExercise = v;
                          _repsCtrl.clear();
                          _weightCtrl.clear();
                          _durationCtrl.clear();
                        }),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_selectedExercise != null && _selectedExercise!['type'] == 'time')
                        TextField(
                          controller: _durationCtrl, 
                          keyboardType: TextInputType.number, 
                          decoration: const InputDecoration(labelText: 'Duration (Seconds)', hintText: 'e.g., 60')
                        )
                      else
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _repsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reps'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (kg)'))),
                          ],
                        ),
                      
                      const SizedBox(height: 16),
                      ElevatedButton.icon(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)), onPressed: _logSet, icon: const Icon(Icons.add), label: const Text('Log Set')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_sets.isNotEmpty) ...[
                  const Text('Sets Logged', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._sets.asMap().entries.map((e) {
                    final set = e.value;
                    final String detailText = set['isTime'] 
                        ? '${set['duration_seconds']} seconds' 
                        : '${set['reps']} reps${set['weight'] != null ? ' · ${set['weight']}kg' : ''}';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                      child: Row(
                        children: [
                          Container(width: 28, height: 28, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)))),
                          const SizedBox(width: 12),
                          Expanded(child: Text(set['exercise'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                          Text(detailText, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    );
                  }),
                ],
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