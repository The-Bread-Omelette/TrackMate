import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../data/workout_remote_datasource.dart';

class CardioTimerPage extends StatefulWidget {
  const CardioTimerPage({super.key});

  @override
  State<CardioTimerPage> createState() => _CardioTimerPageState();
}

class _CardioTimerPageState extends State<CardioTimerPage> {
  final _ds = WorkoutRemoteDataSource(sl());
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _selectedCardio = "Running";

  String get _img => _selectedCardio.toLowerCase().replaceAll(' ', '_');

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
    try {
      final session = await _ds.startSession(name: _selectedCardio);
      final minutes = _stopwatch.elapsed.inMinutes;
      // Formula: (minutes / 30) * calories_per_kg_30min * weight
      // (Using 70kg as average fallback here)
      final calories = (minutes / 30) * 4.8 * 70;
      await _ds.finishSession(session['session_id'], caloriesBurned: calories);
      if (mounted) Navigator.pop(context);
    } catch (_) {}
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
      appBar: AppBar(title: const Text("Cardio Timer", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/$_img.jpg',
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.directions_run, size: 100, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButton<String>(
              value: _selectedCardio,
              items: ["Running", "Burpee", "Lunges", "Push-up"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedCardio = v!),
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
                  child: Icon(_stopwatch.isRunning ? Icons.pause : Icons.play_arrow),
                ),
                if (!_stopwatch.isRunning && _stopwatch.elapsed.inSeconds > 0) ...[
                  const SizedBox(width: 24),
                  FloatingActionButton.large(
                    onPressed: _finish,
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.check),
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