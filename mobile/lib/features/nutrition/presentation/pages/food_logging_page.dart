import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/nutrition_remote_datasource.dart';

class FoodLoggingPage extends StatefulWidget {
  const FoodLoggingPage({super.key});

  @override
  State<FoodLoggingPage> createState() => _FoodLoggingPageState();
}

class _FoodLoggingPageState extends State<FoodLoggingPage> {
  final _ds = NutritionRemoteDataSource(sl());
  final _searchCtrl = TextEditingController();

  Map<String, dynamic> _hydration = {};
  List<dynamic> _searchResults = [];
  List<dynamic> _loggedMeals = [];
  Map<String, dynamic> _summary = {};
  Map<String, dynamic>? _selectedFood;
  int _servings = 1;
  bool _searching = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _ds.getNutritionSummary(),
        _ds.getMeals(),
        _ds.getHydrationSummary(),
      ]);
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _loggedMeals = results[1] as List<dynamic>;
        _hydration = results[2] as Map<String, dynamic>;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await _ds.searchFoods(q);
      setState(() => _searchResults = results);
    } catch (_) {}
    setState(() => _searching = false);
  }

  Future<void> _logFood() async {
    if (_selectedFood == null) return;
    final f = _selectedFood!;
    try {
      await _ds.logMeal({
        'food_id': f['id'] ?? '',
        'food_name': f['name'],
        'calories_per_100g': f['calories_per_100g'] ?? 0,
        'protein_per_100g': f['protein_per_100g'] ?? 0,
        'carbs_per_100g': f['carbs_per_100g'] ?? 0,
        'fat_per_100g': f['fat_per_100g'] ?? 0,
        'serving_size_g': f['serving_size_g'] ?? 100,
        'serving_label': f['serving_label'] ?? '100g',
        'servings': _servings.toDouble(),
      });
      setState(() {
        _selectedFood = null;
        _servings = 1;
        _searchCtrl.clear();
        _searchResults = [];
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food logged successfully')),
        );
      }
    } catch (_) {}
  }

  Future<void> _deleteLog(String id) async {
    try {
      await _ds.deleteMeal(id);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticatedState ? authState.user : null;
    if (user == null) return const SizedBox.shrink();

    return MainLayout(
      user: user,
      title: 'Food Logging',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MacrosCard(summary: _summary),
                    const SizedBox(height: 16),
                    _WaterSection(
                      hydration: _hydration,
                      onLog: (ml) async {
                        await _ds.logWater(ml);
                        await _load();
                      },
                    ),
                    const SizedBox(height: 16),
                    _SearchBar(
                      controller: _searchCtrl,
                      onChanged: _search,
                      searching: _searching,
                    ),
                    const SizedBox(height: 12),
                    if (_searchResults.isNotEmpty && _selectedFood == null)
                      _SearchResults(
                        results: _searchResults,
                        onSelect: (food) => setState(() {
                          _selectedFood = food;
                          _servings = 1;
                        }),
                      ),
                    if (_selectedFood != null) ...[
                      const SizedBox(height: 12),
                      _AddFoodCard(
                        food: _selectedFood!,
                        servings: _servings,
                        onServingsChanged: (v) => setState(() => _servings = v),
                        onLog: _logFood,
                        onCancel: () => setState(() => _selectedFood = null),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _LoggedFoodsCard(
                      meals: _loggedMeals,
                      onDelete: _deleteLog,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Components ──────────────────────────────────────────────────────────────

class _WaterSection extends StatelessWidget {
  final Map<String, dynamic> hydration;
  final ValueChanged<int> onLog;

  const _WaterSection({required this.hydration, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final totalMl = (hydration['total_ml'] ?? 0) as num;
    final goalMl = (hydration['goal_ml'] ?? 2500) as num;
    final pct = (hydration['percentage'] ?? 0.0) as num;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.water_drop, color: Colors.blue, size: 18),
                const SizedBox(width: 6),
                const Text('Water Intake',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
              Text('${totalMl.toStringAsFixed(0)} / ${goalMl.toInt()} ml',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [250, 350, 500]
                .map((ml) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        onPressed: () => onLog(ml),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: Colors.blue),
                          foregroundColor: Colors.blue,
                        ),
                        child: Text('+${ml}ml',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MacrosCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _MacrosCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final protein = (summary['total_protein_g'] ?? 0.0) as num;
    final carbs = (summary['total_carbs_g'] ?? 0.0) as num;
    final fat = (summary['total_fat_g'] ?? 0.0) as num;
    final calories = (summary['total_calories'] ?? 0.0) as num;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Today's Macros",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${calories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _macroBar('Protein', protein.toDouble(), 150, AppColors.primary),
          const SizedBox(height: 12),
          _macroBar('Carbs', carbs.toDouble(), 200, AppColors.success),
          const SizedBox(height: 12),
          _macroBar('Fats', fat.toDouble(), 65, Colors.orange),
        ],
      ),
    );
  }

  Widget _macroBar(String label, double current, double goal, Color color) {
    final progress = (current / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text('${current.toStringAsFixed(1)}g / ${goal.toInt()}g',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 12,
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool searching;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.searching,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search for foods...',
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        suffixIcon: searching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<dynamic> results;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _SearchResults({required this.results, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Search Results',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary)),
          ),
          ...results.take(8).map((f) {
            final food = f as Map<String, dynamic>;
            final String name = food['name'] ?? '';
            final String imgName = name.toLowerCase().replaceAll(' ', '_');

            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/$imgName.jpg',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    color: AppColors.background,
                    child: const Icon(Icons.restaurant,
                        size: 20, color: AppColors.textMuted),
                  ),
                ),
              ),
              title: Text(name),
              subtitle: Text(
                '${(food['calories_per_100g'] ?? 0).toStringAsFixed(0)} kcal · ${food['serving_label'] ?? '100g'}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.add_circle_outline,
                  color: AppColors.primary),
              onTap: () => onSelect(food),
            );
          }),
        ],
      ),
    );
  }
}

class _AddFoodCard extends StatelessWidget {
  final Map<String, dynamic> food;
  final int servings;
  final ValueChanged<int> onServingsChanged;
  final VoidCallback onLog;
  final VoidCallback onCancel;

  const _AddFoodCard({
    required this.food,
    required this.servings,
    required this.onServingsChanged,
    required this.onLog,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final String name = food['name'] ?? '';
    final String imgName = name.toLowerCase().replaceAll(' ', '_');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/$imgName.jpg',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add to Log',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                    Text(name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Per 100g: ${(food['calories_per_100g'] ?? 0).toStringAsFixed(0)} kcal · P: ${(food['protein_per_100g'] ?? 0).toStringAsFixed(1)}g · C: ${(food['carbs_per_100g'] ?? 0).toStringAsFixed(1)}g',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Servings'),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: servings > 1
                          ? () => onServingsChanged(servings - 1)
                          : null,
                    ),
                    Text('$servings',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => onServingsChanged(servings + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onLog,
                  child: const Text('Log Food'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoggedFoodsCard extends StatelessWidget {
  final List<dynamic> meals;
  final ValueChanged<String> onDelete;

  const _LoggedFoodsCard({required this.meals, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Foods Eaten Today',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (meals.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No food logged yet',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ...meals.map((m) {
              final meal = m as Map<String, dynamic>;
              final String name = meal['food_name'] ?? '';
              final String imgName = name.toLowerCase().replaceAll(' ', '_');

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/images/$imgName.jpg',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.restaurant,
                              size: 20,
                              color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                              '${(meal['calories'] ?? 0).toStringAsFixed(0)} kcal · ${meal['servings']}x ${meal['serving_label']}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error, size: 20),
                        onPressed: () => onDelete(meal['id']),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}