import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../shared/widgets/main_layout.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/di/injection.dart';
import '../../core/constants/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _dio = sl<Dio>();
  bool _loading = true;
  bool _saving = false;

  final _bioCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _stepGoalCtrl = TextEditingController();
  final _calorieGoalCtrl = TextEditingController();
  final _waterGoalCtrl = TextEditingController();

  String? _gender;
  String? _activityLevel;
  DateTime? _dob;

  // 🔥 Track Trainer Status
  bool _hasTrainer = false;
  Map<String, dynamic>? _savedApplication;

  Map<String, bool> _notifPrefs = {
    'friend_request': true,
    'trainer_request': true,
    'new_message': true,
    'post_like': true,
    'system': true,
  };

  final _genders = ['male', 'female', 'other', 'prefer_not_to_say'];
  final _activityLevels = [
    'sedentary',
    'lightly_active',
    'moderately_active',
    'very_active',
    'extra_active'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _bioCtrl,
      _heightCtrl,
      _weightCtrl,
      _stepGoalCtrl,
      _calorieGoalCtrl,
      _waterGoalCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // 🔥 Helper to beautifully capitalize strings (e.g., "moderately_active" -> "Moderately Active")
  String _capitalize(String s) {
    return s.split('_').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }

  String _notifLabel(String key) {
    const labels = {
      'friend_request': 'Friend Requests',
      'trainer_request': 'Trainer Requests',
      'new_message': 'New Messages',
      'post_like': 'Post Likes',
      'system': 'System Notifications',
    };
    return labels[key] ?? key;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _notifPrefs.keys) {
        _notifPrefs[key] = prefs.getBool('notif_$key') ?? true;
      }

      _waterGoalCtrl.text = (prefs.getInt('local_water_goal') ?? 2500).toString();

      // Fetch saved application if exists
      final appJson = prefs.getString('trainer_application');
      if (appJson != null) {
        _savedApplication = jsonDecode(appJson);
      }

      final res = await _dio.get(ApiConstants.profile);
      final data = res.data as Map<String, dynamic>;
      final p = data['profile'] as Map<String, dynamic>? ?? {};

      _bioCtrl.text = p['bio'] ?? '';
      _heightCtrl.text = '${p['height_cm'] ?? ''}';
      _weightCtrl.text = '${p['weight_kg'] ?? ''}';
      _stepGoalCtrl.text = '${p['daily_step_goal'] ?? 10000}';
      _calorieGoalCtrl.text = '${p['daily_calorie_goal'] ?? ''}';
      _gender = p['gender'];
      _activityLevel = p['activity_level'];

      if (p['date_of_birth'] != null) {
        _dob = DateTime.tryParse(p['date_of_birth']);
      }

      // Sync latest weight from Analytics Trend
      try {
        final weightRes = await _dio.get('/api/v1/fitness/weight/trend', queryParameters: {'days': 30});
        final trendData = weightRes.data as List<dynamic>;
        if (trendData.isNotEmpty) {
          _weightCtrl.text = '${trendData.last['weight_kg']}';
        }
      } catch (_) {}

      // Check if user has an active trainer
      try {
        final trainerRes = await _dio.get('/api/v1/trainer/my-trainer');
        if (trainerRes.data != null && trainerRes.data['trainer'] != null) {
          _hasTrainer = true;
        }
      } catch (_) {}

    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final double? w = double.tryParse(_weightCtrl.text);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('local_water_goal', int.tryParse(_waterGoalCtrl.text) ?? 2500);

      await _dio.put(ApiConstants.profile, data: {
        'bio': _bioCtrl.text.isEmpty ? null : _bioCtrl.text,
        'gender': _gender,
        'date_of_birth': _dob?.toIso8601String(),
        'height_cm': double.tryParse(_heightCtrl.text),
        'weight_kg': w,
        'daily_step_goal': int.tryParse(_stepGoalCtrl.text),
        'daily_calorie_goal': int.tryParse(_calorieGoalCtrl.text),
        'activity_level': _activityLevel,
      });

      // Log weight to Analytics backend so charts update instantly
      if (w != null) {
        try {
          await _dio.post('/api/v1/fitness/weight', data: {'weight_kg': w});
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved successfully')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save profile'), backgroundColor: AppColors.error));
      }
    }
    setState(() => _saving = false);
  }

  // 🔥 View and Withdraw existing application
  void _showApplicationDetails(BuildContext context) {
    if (_savedApplication == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your Application', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Pending Review', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            ),
            const SizedBox(height: 24),
            _infoTile('Phone Number', _savedApplication!['phone_number']),
            _infoTile('Experience', '${_savedApplication!['experience_years']} years'),
            _infoTile('Hourly Rate', '₹${_savedApplication!['hourly_rate']}'),
            const SizedBox(height: 12),
            const Text('About You', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_savedApplication!['about'], style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            const Text('Specializations', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_savedApplication!['specializations'], style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            const Text('Certifications', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_savedApplication!['certifications'], style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh, color: Colors.orange),
                label: const Text('Withdraw & Re-apply', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('trainer_application');
                  setState(() {
                    _savedApplication = null;
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application withdrawn. You can now submit a new one.')));
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Window'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTrainerApplicationDialog(BuildContext context) async {
    final phoneCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final aboutCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final certCtrl = TextEditingController();
    final rateCtrl = TextEditingController();

    List<String> specializations = [];
    List<String> certifications = [];
    
    final formKey = GlobalKey<FormState>();
    bool autoValidate = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          
          Widget buildTags(List<String> tags, Function(String) onDeleted) {
            return Wrap(
              spacing: 8,
              runSpacing: 4,
              children: tags.map((tag) => Chip(
                label: Text(tag, style: const TextStyle(fontSize: 12)),
                backgroundColor: AppColors.primary.withOpacity(0.1),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setModalState(() => onDeleted(tag)),
              )).toList(),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Form(
              key: formKey,
              autovalidateMode: autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trainer Application', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('All fields are mandatory.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixText: '+91 ',
                        prefixStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                        counterText: '',
                      ),
                      validator: (val) => (val == null || val.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(val)) 
                          ? 'Enter a valid 10-digit number' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: expCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      decoration: const InputDecoration(labelText: 'Years of Experience'),
                      validator: (val) => int.tryParse(val?.trim() ?? '') == null ? 'Must be a valid number' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: aboutCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'About Me (No limits)', alignLabelWithHint: true),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please write a short bio' : null,
                    ),
                    const SizedBox(height: 16),

                    if (specializations.isNotEmpty) buildTags(specializations, (tag) => specializations.remove(tag)),
                    TextFormField(
                      controller: specCtrl,
                      decoration: const InputDecoration(labelText: 'Specializations (Type comma "," to add)'),
                      onChanged: (val) {
                        if (val.endsWith(',')) {
                          final tag = val.substring(0, val.length - 1).trim();
                          if (tag.isNotEmpty && !specializations.contains(tag)) {
                            setModalState(() { specializations.add(tag); specCtrl.clear(); });
                          } else {
                            specCtrl.clear();
                          }
                        }
                      },
                    ),
                    if (autoValidate && specializations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 12),
                        child: Text('Add at least one specialization', style: TextStyle(color: AppColors.error, fontSize: 12)),
                      ),
                    const SizedBox(height: 16),

                    if (certifications.isNotEmpty) buildTags(certifications, (tag) => certifications.remove(tag)),
                    TextFormField(
                      controller: certCtrl,
                      decoration: const InputDecoration(labelText: 'Certifications (Type comma "," to add)'),
                      onChanged: (val) {
                        if (val.endsWith(',')) {
                          final tag = val.substring(0, val.length - 1).trim();
                          if (tag.isNotEmpty && !certifications.contains(tag)) {
                            setModalState(() { certifications.add(tag); certCtrl.clear(); });
                          } else {
                            certCtrl.clear();
                          }
                        }
                      },
                    ),
                    if (autoValidate && certifications.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 12),
                        child: Text('Add at least one certification', style: TextStyle(color: AppColors.error, fontSize: 12)),
                      ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Hourly Rate (₹)', prefixText: '₹ '),
                      validator: (val) => double.tryParse(val?.trim() ?? '') == null ? 'Must be a valid number' : null,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (specCtrl.text.trim().isNotEmpty) {
                            if (!specializations.contains(specCtrl.text.trim())) specializations.add(specCtrl.text.trim());
                            specCtrl.clear();
                          }
                          if (certCtrl.text.trim().isNotEmpty) {
                            if (!certifications.contains(certCtrl.text.trim())) certifications.add(certCtrl.text.trim());
                            certCtrl.clear();
                          }

                          if (!formKey.currentState!.validate() || specializations.isEmpty || certifications.isEmpty) {
                            setModalState(() { autoValidate = true; }); 
                            return; 
                          }

                          Navigator.pop(ctx); 
                          
                          final payload = {
                            'phone_number': '+91${phoneCtrl.text.trim()}',
                            'experience_years': int.tryParse(expCtrl.text.trim()),
                            'about': aboutCtrl.text.trim(),
                            'specializations': specializations.join(', '),
                            'certifications': certifications.join(', '),
                            'hourly_rate': double.tryParse(rateCtrl.text.trim()),
                          };

                          try {
                            await _dio.post(ApiConstants.trainerApply, data: payload);
                            
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('trainer_application', jsonEncode(payload));
                            
                            setState(() { _savedApplication = payload; });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted! Admin will review it.')));
                            }
                          } on DioException catch (e) {
                            if (e.response?.statusCode == 409) {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('trainer_application', jsonEncode(payload));
                              setState(() { _savedApplication = payload; });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('You already have a pending application! View it below.'),
                                  backgroundColor: Colors.orange,
                                ));
                              }
                            }
                          }
                        },
                        child: const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticatedState).user;

    return MainLayout(
      user: user,
      title: 'Settings',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('Account Info'),
            _card([
              _infoTile('Email', user.email),
              _infoTile('Role', _capitalize(user.role.name)),
              _infoTile('Verified', user.isVerified ? 'Yes' : 'No'),
            ]),
            const SizedBox(height: 20),

            _header('Profile'),
            _card([
              _inputTile('Bio', _bioCtrl, maxLines: 2),
              _dropdownTile('Gender', _gender, _genders, (v) => setState(() => _gender = v)),
              _dateTile(context),
            ]),
            const SizedBox(height: 20),

            _header('Body Metrics'),
            _card([
              Row(children: [
                Expanded(child: _inputTile('Height (cm)', _heightCtrl, isNumber: true)),
                Expanded(child: _inputTile('Weight (kg)', _weightCtrl, isNumber: true)),
              ]),
            ]),
            const SizedBox(height: 20),

            _header('Notification Preferences'),
            _card(_notifPrefs.entries.map((e) => SwitchListTile(
              title: Text(_notifLabel(e.key), style: const TextStyle(fontSize: 14)),
              value: e.value,
              activeColor: AppColors.primary,
              onChanged: (v) async {
                setState(() => _notifPrefs[e.key] = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notif_${e.key}', v);
              },
            )).toList()),
            const SizedBox(height: 20),

            _header('Fitness Goals'),
            _card([
              Row(children: [
                Expanded(child: _inputTile('Step Goal', _stepGoalCtrl, isNumber: true)),
                Expanded(child: _inputTile('Calorie Goal', _calorieGoalCtrl, isNumber: true)),
              ]),
              _inputTile('Water Goal (ml)', _waterGoalCtrl, isNumber: true),
              _dropdownTile('Activity Level', _activityLevel, _activityLevels, (v) => setState(() => _activityLevel = v)),
            ]),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            if (user.role.name == 'trainee') ...[
              const SizedBox(height: 20),
              _header('Trainer Center'),
              _card([
                if (_hasTrainer)
                  ListTile(
                    leading: const Icon(Icons.lock, color: AppColors.textMuted, size: 24),
                    title: const Text('Apply to become a Trainer', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    subtitle: const Text('Please quit your current trainer first.', style: TextStyle(fontSize: 12, color: AppColors.error)),
                  )
                else if (_savedApplication != null)
                  ListTile(
                    leading: const Icon(Icons.assignment, color: Colors.orange, size: 24),
                    title: const Text('View Trainer Application', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Status: Pending Review', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => _showApplicationDetails(context),
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.fitness_center, color: AppColors.primary, size: 24),
                    title: const Text('Apply to become a Trainer', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Submit your application for admin review', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => _showTrainerApplicationDialog(context),
                  ),
              ]),
            ],
            const SizedBox(height: 20),

            _header('Danger Zone'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withValues(alpha:0.3)),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.read<AuthBloc>().add(const AuthLogoutEvent());
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _header(String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
  );

  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(children: children),
  );

  Widget _infoTile(String label, String value) => ListTile(
    title: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
  );

  Widget _inputTile(String label, TextEditingController ctrl, {int maxLines = 1, bool isNumber = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(labelText: label)),
      );

  Widget _dropdownTile(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    final safeValue = items.contains(value?.toLowerCase()) ? value?.toLowerCase() : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        decoration: InputDecoration(labelText: label),
        items: items.map((i) {
          return DropdownMenuItem(value: i, child: Text(_capitalize(i)));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dateTile(BuildContext context) => ListTile(
    title: Text(_dob != null ? 'DOB: ${_dob!.day}/${_dob!.month}/${_dob!.year}' : 'Date of Birth'),
    trailing: const Icon(Icons.calendar_today, size: 18, color: AppColors.textMuted),
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: _dob ?? DateTime(2000),
        firstDate: DateTime(1940),
        lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      );
      if (picked != null) setState(() => _dob = picked);
    },
  );
}