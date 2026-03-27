import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/analytics_remote_datasource.dart';

class AnalyticsPage extends StatefulWidget {
  // 🔥 ADDED THIS PARAMETER SO EXERCISE PAGE CAN ROUTE TO IT
  final int initialView;
  const AnalyticsPage({super.key, this.initialView = 0});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final _ds = AnalyticsRemoteDataSource(sl());
  int _selectedView = 0;
  bool _loading = true;

  List<dynamic> _stepsHistory = [];
  Map<String, dynamic> _nutrition = {};
  Map<String, dynamic> _weekly = {};
  List<dynamic> _weightTrend = [];

  @override
  void initState() {
    super.initState();
    // 🔥 STARTS ON THE VIEW PASSED BY THE BUTTON (0 for Overview, 1 for Detailed)
    _selectedView = widget.initialView;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _ds.getStepsHistory(),
        _ds.getNutritionSummary(),
        _ds.getWeeklyStats(),
        _ds.getWeightTrend(),
      ]);
      setState(() {
        _stepsHistory = results[0] as List<dynamic>;
        _nutrition = results[1] as Map<String, dynamic>;
        _weekly = results[2] as Map<String, dynamic>;
        _weightTrend = results[3] as List<dynamic>;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }
@override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticatedState ? authState.user : null;
    if (user == null) return const SizedBox.shrink();

    return MainLayout(
      user: user,
      title: 'Analytics',
      child: Column(
        children: [
          // 🔥 NEW: Conditional Back Button
          if (Navigator.canPop(context))
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                  label: const Text('Back to Exercise', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, icon: Icon(Icons.grid_view), label: Text('Overview')),
                ButtonSegment(value: 1, icon: Icon(Icons.bar_chart), label: Text('Detailed')),
              ],
              selected: {_selectedView},
              onSelectionChanged: (s) => setState(() => _selectedView = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: _selectedView == 0
                          ? _buildOverview()
                          : _buildDetailed(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
 

  Widget _buildOverview() {
    return Column(
      children: [
        _ChartCard(title: 'Steps This Week', child: _buildStepsChart()),
        const SizedBox(height: 16),
        _ChartCard(title: "Today's Macros", child: _buildMacrosPie()),
        const SizedBox(height: 16),
        _ChartCard(title: 'Weekly Summary', child: _buildWeeklySummary()),
      ],
    );
  }

  Widget _buildDetailed() {
    return Column(
      children: [
        _ChartCard(title: 'Weight Trend', height: 300, child: _buildWeightChart()),
        const SizedBox(height: 16),
        _ChartCard(title: 'Steps History', height: 300, child: _buildStepsBarChart()),
      ],
    );
  }

  Widget _buildStepsChart() {
    if (_stepsHistory.isEmpty) {
      return const Center(child: Text('No step data yet', style: TextStyle(color: AppColors.textMuted)));
    }
    final spots = _stepsHistory.asMap().entries.map((e) {
      // 🔥 ADDED ?? 0 TO PREVENT NULL CRASHES
      final steps = ((e.value['steps'] ?? 0) as num).toDouble();
      return FlSpot(e.key.toDouble(), steps);
    }).toList();

    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (val, _) {
              final idx = val.toInt();
              if (idx < 0 || idx >= _stepsHistory.length) return const Text('');
              final date = (_stepsHistory[idx]['date'] as String).substring(5);
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(date, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.primary,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primary.withOpacity(0.1),
          ),
        ),
      ],
    ));
  }

  Widget _buildMacrosPie() {
    final protein = (_nutrition['total_protein_g'] ?? 0.0) as num;
    final carbs = (_nutrition['total_carbs_g'] ?? 0.0) as num;
    final fat = (_nutrition['total_fat_g'] ?? 0.0) as num;
    final total = protein + carbs + fat;

    if (total == 0) {
      return const Center(child: Text('No nutrition data today', style: TextStyle(color: AppColors.textMuted)));
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 0,
            sections: [
              PieChartSectionData(
                color: AppColors.primary,
                value: protein.toDouble(),
                title: '${(protein / total * 100).toStringAsFixed(0)}%',
                radius: 70,
                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              PieChartSectionData(
                color: AppColors.success,
                value: carbs.toDouble(),
                title: '${(carbs / total * 100).toStringAsFixed(0)}%',
                radius: 70,
                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              PieChartSectionData(
                color: Colors.orange,
                value: fat.toDouble(),
                title: '${(fat / total * 100).toStringAsFixed(0)}%',
                radius: 70,
                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          )),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legend(AppColors.primary, 'Protein', '${protein.toStringAsFixed(1)}g'),
            _legend(AppColors.success, 'Carbs', '${carbs.toStringAsFixed(1)}g'),
            _legend(Colors.orange, 'Fats', '${fat.toStringAsFixed(1)}g'),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWeeklySummary() {
    return Column(
      children: [
        _summaryRow('Workouts completed', '${_weekly['workouts_completed'] ?? 0}'),
        _summaryRow('Calories burned', '${(_weekly['calories_burned'] ?? 0).toStringAsFixed(0)} kcal'),
        _summaryRow('Total steps', '${_weekly['total_steps'] ?? 0}'),
        _summaryRow('Goal days met', '${_weekly['step_goal_days_met'] ?? 0} / 7'),
        _summaryRow('Streak', '${_weekly['streak_days'] ?? 0} days'),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    if (_weightTrend.isEmpty) {
      return const Center(child: Text('No weight data yet', style: TextStyle(color: AppColors.textMuted)));
    }
    final spots = _weightTrend.asMap().entries.map((e) {
      // 🔥 ADDED ?? 0 TO PREVENT NULL CRASHES
      final w = ((e.value['weight_kg'] ?? 0) as num).toDouble();
      return FlSpot(e.key.toDouble(), w);
    }).toList();

    return LineChart(LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (val, _) => Text(
              '${val.toStringAsFixed(0)}kg',
              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
            ),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.success,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      ],
    ));
  }

  Widget _buildStepsBarChart() {
    if (_stepsHistory.isEmpty) {
      return const Center(child: Text('No step data yet', style: TextStyle(color: AppColors.textMuted)));
    }
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (val, _) {
              final idx = val.toInt();
              if (idx < 0 || idx >= _stepsHistory.length) return const Text('');
              final date = (_stepsHistory[idx]['date'] as String).substring(8);
              return Text(date, style: const TextStyle(fontSize: 9, color: AppColors.textMuted));
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: _stepsHistory.asMap().entries.map((e) {
        // 🔥 ADDED ?? 0 TO PREVENT NULL CRASHES
        final steps = ((e.value['steps'] ?? 0) as num).toDouble();
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: steps,
              color: AppColors.primary,
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }).toList(),
    ));
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double height;

  const _ChartCard({
    required this.title,
    required this.child,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}