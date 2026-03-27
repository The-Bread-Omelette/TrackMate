import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../data/workout_remote_datasource.dart';

// 🔥 Hardcoded CSV Data directly matching your parameters
const List<Map<String, dynamic>> cardioExercises = [
  {"name": "Running", "multiplier": 4.8, "image": "assets/images/running.jpg"},
  {"name": "Burpee", "multiplier": 4.25, "image": "assets/images/burpee.jpg"},
  {"name": "Lunges", "multiplier": 2.5, "image": "assets/images/lunges.jpg"},
  {"name": "Push-up", "multiplier": 4.0, "image": "assets/images/push_up.jpg"},
  {"name": "Plank", "multiplier": 1.75, "image": "assets/images/plank.jpg"},
];

class CardioTimerPage extends StatefulWidget {
  final double userWeightKg;
  const CardioTimerPage({super.key, required this.userWeightKg});

  @override
  State<CardioTimerPage> createState() => _CardioTimerPageState();
}

class _CardioTimerPageState extends State<CardioTimerPage> {
  final _ds = WorkoutRemoteDataSource(sl());
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  
  late Map<String, dynamic> _selectedCardio;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCardio = cardioExercises.first;
  }

  void _toggle() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _timer?.cancel();
      } else {
        _stopwatch.start();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final session = await _ds.startSession(name: _selectedCardio['name']);
      
      final minutes = _stopwatch.elapsed.inMinutes;
      final seconds = _stopwatch.elapsed.inSeconds % 60;
      final totalMinutesFloat = _stopwatch.elapsed.inSeconds / 60.0;
      
      // 🔥 Calculate Calories based on CSV multiplier and exact user weight
      final double multiplier = _selectedCardio['multiplier'];
      final calories = (totalMinutesFloat / 30.0) * multiplier * widget.userWeightKg;

      // 🔥 Store the exact stopwatch duration into the notes so history displays it
      final durationString = "${minutes}m ${seconds}s";

      await _ds.finishSession(
        session['session_id'], 
        caloriesBurned: calories,
        notes: durationString
      );
      
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Cardio Timer", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _saving 
        ? const Center(child: CircularProgressIndicator())
        : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                _selectedCardio['image'],
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 220, height: 220, color: AppColors.surface,
                  child: const Icon(Icons.directions_run, size: 100, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)
              ),
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedCardio,
                underline: const SizedBox(),
                items: cardioExercises.map((ex) => DropdownMenuItem(
                  value: ex, 
                  child: Text(ex['name'], style: const TextStyle(fontWeight: FontWeight.bold))
                )).toList(),
                onChanged: (v) => setState(() {
                  _selectedCardio = v!;
                  _stopwatch.reset(); // Reset timer when switching exercise
                }),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _stopwatch.elapsed.toString().split('.').first.padLeft(8, "0"),
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.large(
                  onPressed: _toggle,
                  backgroundColor: _stopwatch.isRunning ? Colors.orange : AppColors.primary,
                  child: Icon(_stopwatch.isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white),
                ),
                if (!_stopwatch.isRunning && _stopwatch.elapsed.inSeconds > 0) ...[
                  const SizedBox(width: 24),
                  FloatingActionButton.large(
                    onPressed: _finish,
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }
}