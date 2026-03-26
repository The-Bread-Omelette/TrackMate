// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:dio/dio.dart';
// import '../../features/auth/presentation/bloc/auth_bloc.dart';
// import '../../features/auth/presentation/bloc/auth_event.dart';
// import '../../features/auth/presentation/bloc/auth_state.dart';
// import '../../shared/widgets/main_layout.dart';
// import '../../shared/theme/app_theme.dart';
// import '../../core/di/injection.dart';
// import '../../core/constants/api_constants.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class SettingsPage extends StatefulWidget {
//   const SettingsPage({super.key});
//
//   @override
//   State<SettingsPage> createState() => _SettingsPageState();
// }
//
// class _SettingsPageState extends State<SettingsPage> {
//   final _dio = sl<Dio>();
//   bool _loading = true;
//   bool _saving = false;
//
//   final _bioCtrl = TextEditingController();
//   final _heightCtrl = TextEditingController();
//   final _weightCtrl = TextEditingController();
//   final _stepGoalCtrl = TextEditingController();
//   final _calorieGoalCtrl = TextEditingController();
//   String? _gender;
//   String? _activityLevel;
//   DateTime? _dob;
//   Map<String, bool> _notifPrefs = {
//     'friend_request': true,
//     'trainer_request': true,
//     'new_message': true,
//     'post_like': true,
//     'system': true,
//   };
//
//   final _genders = ['Male', 'Female', 'Other', 'Prefer_not_to_say'];
//   final _activityLevels = [
//     'Sedentary',
//     'Lightly_Active',
//     'Moderately_Active',
//     'Very_Active',
//     'Extra_Active'
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }
//
//   @override
//   void dispose() {
//     for (final c in [
//       _bioCtrl,
//       _heightCtrl,
//       _weightCtrl,
//       _stepGoalCtrl,
//       _calorieGoalCtrl
//     ]) {
//       c.dispose();
//     }
//     super.dispose();
//   }
//
//   Future<void> _showTrainerApplicationDialog(BuildContext context) async {
//     final phoneCtrl = TextEditingController();
//     final expCtrl = TextEditingController();
//     final aboutCtrl = TextEditingController();
//     final specCtrl = TextEditingController();
//     final certCtrl = TextEditingController();
//     final rateCtrl = TextEditingController();
//
//     await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
//       builder: (ctx) => Padding(
//         padding: EdgeInsets.fromLTRB(
//             24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text('Trainer Application',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               const SizedBox(height: 16),
//               TextField(
//                   controller: phoneCtrl,
//                   decoration: const InputDecoration(labelText: 'Phone Number')),
//               const SizedBox(height: 12),
//               TextField(
//                   controller: expCtrl,
//                   keyboardType: TextInputType.number,
//                   decoration:
//                       const InputDecoration(labelText: 'Years of Experience')),
//               const SizedBox(height: 12),
//               TextField(
//                   controller: aboutCtrl,
//                   maxLines: 3,
//                   decoration: const InputDecoration(labelText: 'About Me')),
//               const SizedBox(height: 12),
//               TextField(
//                   controller: specCtrl,
//                   decoration: const InputDecoration(
//                       labelText: 'Specializations (comma separated)')),
//               const SizedBox(height: 12),
//               TextField(
//                   controller: certCtrl,
//                   decoration: const InputDecoration(
//                       labelText: 'Certifications (comma separated)')),
//               const SizedBox(height: 12),
//               TextField(
//                   controller: rateCtrl,
//                   keyboardType: TextInputType.number,
//                   decoration:
//                       const InputDecoration(labelText: 'Hourly Rate (₹)')),
//               const SizedBox(height: 20),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () async {
//                     Navigator.pop(ctx);
//                     try {
//                       await _dio.post(ApiConstants.trainerApply, data: {
//                         'phone_number': phoneCtrl.text,
//                         'experience_years': int.tryParse(expCtrl.text),
//                         'about': aboutCtrl.text,
//                         'specializations': specCtrl.text,
//                         'certifications': certCtrl.text,
//                         'hourly_rate': double.tryParse(rateCtrl.text),
//                       });
//                       if (context.mounted) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                               content: Text(
//                                   'Application submitted! Admin will review it.')),
//                         );
//                       }
//                     } catch (_) {
//                       if (context.mounted) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                               content: Text('Failed to submit application'),
//                               backgroundColor: AppColors.error),
//                         );
//                       }
//                     }
//                   },
//                   child: const Text('Submit Application'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// String _notifLabel(String key) {
//   const labels = {
//     'friend_request': 'Friend Requests',
//     'trainer_request': 'Trainer Requests',
//     'new_message': 'New Messages',
//     'post_like': 'Post Likes',
//     'system': 'System Notifications',
//   };
//   return labels[key] ?? key;
// }
//   Future<void> _load() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       for (final key in _notifPrefs.keys) {
//         _notifPrefs[key] = prefs.getBool('notif_$key') ?? true;
//       }
//       final res = await _dio.get(ApiConstants.profile);
//       final data = res.data as Map<String, dynamic>;
//       final p = data['profile'] as Map<String, dynamic>? ?? {};
//       _bioCtrl.text = p['bio'] ?? '';
//       _heightCtrl.text = '${p['height_cm'] ?? ''}';
//       _weightCtrl.text = '${p['weight_kg'] ?? ''}';
//       _stepGoalCtrl.text = '${p['daily_step_goal'] ?? 10000}';
//       _calorieGoalCtrl.text = '${p['daily_calorie_goal'] ?? ''}';
//       _gender = p['gender'];
//       _activityLevel = p['activity_level'];
//       if (p['date_of_birth'] != null) {
//         _dob = DateTime.tryParse(p['date_of_birth']);
//       }
//     } catch (_) {}
//     setState(() => _loading = false);
//   }
//
//   Future<void> _save() async {
//     setState(() => _saving = true);
//     try {
//       await _dio.put(ApiConstants.profile, data: {
//         'bio': _bioCtrl.text.isEmpty ? null : _bioCtrl.text,
//         'gender': _gender,
//         'date_of_birth': _dob?.toIso8601String(),
//         'height_cm': double.tryParse(_heightCtrl.text),
//         'weight_kg': double.tryParse(_weightCtrl.text),
//         'daily_step_goal': int.tryParse(_stepGoalCtrl.text),
//         'daily_calorie_goal': int.tryParse(_calorieGoalCtrl.text),
//         'activity_level': _activityLevel,
//       });
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(const SnackBar(content: Text('Profile saved')));
//       }
//     } catch (_) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//             content: Text('Failed to save'), backgroundColor: AppColors.error));
//       }
//     }
//     setState(() => _saving = false);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final user =
//         (context.read<AuthBloc>().state as AuthAuthenticatedState).user;
//
//     return MainLayout(
//       user: user,
//       title: 'Settings',
//       child: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _header('Account Info'),
//                   _card([
//                     _infoTile('Email', user.email),
//                     _infoTile('Role', user.role.name),
//                     _infoTile('Verified', user.isVerified ? 'Yes' : 'No'),
//                   ]),
//                   const SizedBox(height: 20),
//                   _header('Profile'),
//                   _card([
//                     _inputTile('Bio', _bioCtrl, maxLines: 2),
//                     _dropdownTile('Gender', _gender, _genders,
//                         (v) => setState(() => _gender = v)),
//                     _dateTile(context),
//                   ]),
//                   const SizedBox(height: 20),
//                   _header('Height and Weight'),
//                   _card([
//                     Row(children: [
//                       Expanded(
//                           child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 16, vertical: 8),
//                         child: TextField(
//                             controller: _heightCtrl,
//                             keyboardType: TextInputType.number,
//                             decoration: const InputDecoration(
//                                 labelText: 'Height (cm)')),
//                       )),
//                       Expanded(
//                           child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 16, vertical: 8),
//                         child: TextField(
//                             controller: _weightCtrl,
//                             keyboardType: TextInputType.number,
//                             decoration: const InputDecoration(
//                                 labelText: 'Weight (kg)')),
//                       )),
//                     ]),
//                     const SizedBox(height: 20),
//                     _header('Notification Preferences'),
//                     _card(_notifPrefs.entries
//                         .map((e) => SwitchListTile(
//                               title: Text(_notifLabel(e.key)),
//                               value: e.value,
//                               activeColor: AppColors.primary,
//                               onChanged: (v) async {
//                                 setState(() => _notifPrefs[e.key] = v);
//                                 final prefs =
//                                     await SharedPreferences.getInstance();
//                                 await prefs.setBool('notif_${e.key}', v);
//                               },
//                             ))
//                         .toList()),
//                     Row(children: [
//                       Expanded(
//                           child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 16, vertical: 8),
//                         child: TextField(
//                             controller: _stepGoalCtrl,
//                             keyboardType: TextInputType.number,
//                             decoration:
//                                 const InputDecoration(labelText: 'Step Goal')),
//                       )),
//                       Expanded(
//                           child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 16, vertical: 8),
//                         child: TextField(
//                             controller: _calorieGoalCtrl,
//                             keyboardType: TextInputType.number,
//                             decoration: const InputDecoration(
//                                 labelText: 'Calorie Goal')),
//                       )),
//                     ]),
//                     _dropdownTile(
//                         'Activity Level',
//                         _activityLevel,
//                         _activityLevels,
//                         (v) => setState(() => _activityLevel = v)),
//                   ]),
//                   const SizedBox(height: 20),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       onPressed: _saving ? null : _save,
//                       child: _saving
//                           ? const SizedBox(
//                               width: 16,
//                               height: 16,
//                               child: CircularProgressIndicator(
//                                   strokeWidth: 2, color: Colors.white))
//                           : const Text('Save Profile'),
//                     ),
//                   ),
//                   if (user.role.name == 'trainee') ...[
//                     const SizedBox(height: 20),
//                     _header('Trainer'),
//                     _card([
//                       ListTile(
//                         leading: const Icon(Icons.fitness_center,
//                             color: AppColors.primary, size: 20),
//                         title: const Text('Apply to become a Trainer'),
//                         subtitle: const Text(
//                             'Submit your application for admin review',
//                             style: TextStyle(
//                                 fontSize: 12, color: AppColors.textSecondary)),
//                         trailing: const Icon(Icons.chevron_right,
//                             color: AppColors.textMuted),
//                         onTap: () => _showTrainerApplicationDialog(context),
//                       ),
//                     ]),
//                   ],
//                   const SizedBox(height: 20),
//                   _header('Danger Zone'),
//                   Container(
//                     decoration: BoxDecoration(
//                       color: AppColors.surface,
//                       borderRadius: BorderRadius.circular(16),
//                       border:
//                           Border.all(color: AppColors.error.withValues(alpha:0.3)),
//                     ),
//                     child: ListTile(
//                       leading: const Icon(Icons.logout, color: AppColors.error),
//                       title: const Text('Logout',
//                           style: TextStyle(
//                               color: AppColors.error,
//                               fontWeight: FontWeight.bold)),
//                       onTap: () => showDialog(
//                         context: context,
//                         builder: (ctx) => AlertDialog(
//                           title: const Text('Logout'),
//                           content: const Text('Are you sure?'),
//                           actions: [
//                             TextButton(
//                                 onPressed: () => Navigator.pop(ctx),
//                                 child: const Text('Cancel')),
//                             ElevatedButton(
//                               onPressed: () {
//                                 Navigator.pop(ctx);
//                                 context
//                                     .read<AuthBloc>()
//                                     .add(const AuthLogoutEvent());
//                               },
//                               style: ElevatedButton.styleFrom(
//                                   backgroundColor: AppColors.error),
//                               child: const Text('Logout'),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   _header('Data'),
//                   Container(
//                     decoration: BoxDecoration(
//                       color: AppColors.surface,
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(color: AppColors.border),
//                     ),
//                     child: ListTile(
//                       leading: const Icon(Icons.delete_sweep_outlined,
//                           color: AppColors.error),
//                       title: const Text('Clear All My Data',
//                           style: TextStyle(color: AppColors.error)),
//                       subtitle: const Text(
//                           'Deletes all workouts, meals, steps, and hydration logs',
//                           style: TextStyle(
//                               fontSize: 12, color: AppColors.textSecondary)),
//                       onTap: () => showDialog(
//                         context: context,
//                         builder: (ctx) => AlertDialog(
//                           title: const Text('Clear All Data'),
//                           content: const Text(
//                               'This will permanently delete all your fitness logs. This cannot be undone.'),
//                           actions: [
//                             TextButton(
//                                 onPressed: () => Navigator.pop(ctx),
//                                 child: const Text('Cancel')),
//                             ElevatedButton(
//                               onPressed: () async {
//                                 Navigator.pop(ctx);
//                                 try {
//                                   await _dio.delete(ApiConstants.clearData);
//                                   if (context.mounted) {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                         const SnackBar(
//                                             content: Text(
//                                                 'All fitness data cleared')));
//                                   }
//                                 } catch (_) {}
//                               },
//                               style: ElevatedButton.styleFrom(
//                                   backgroundColor: AppColors.error),
//                               child: const Text('Clear Data'),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//     );
//   }
//
//   Widget _header(String t) => Padding(
//         padding: const EdgeInsets.only(left: 4, bottom: 8),
//         child: Text(t,
//             style: const TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.textSecondary)),
//       );
//
//   Widget _card(List<Widget> children) => Container(
//         decoration: BoxDecoration(
//             color: AppColors.surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: AppColors.border)),
//         child: Column(children: children),
//       );
//
//   Widget _infoTile(String label, String value) => ListTile(
//         title: Text(label,
//             style:
//                 const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
//         trailing:
//             Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
//       );
//
//   Widget _inputTile(String label, TextEditingController ctrl,
//           {int maxLines = 1}) =>
//       Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: TextField(
//             controller: ctrl,
//             maxLines: maxLines,
//             decoration: InputDecoration(labelText: label)),
//       );
//
//   Widget _dropdownTile(String label, String? value, List<String> items,
//           ValueChanged<String?> onChanged) =>
//       Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: DropdownButtonFormField<String>(
//           value: value,
//           decoration: InputDecoration(labelText: label),
//           items: items
//               .map((i) => DropdownMenuItem(
//                     value: i,
//                     child: Text(i.replaceAll('_', ' ')),
//                   ))
//               .toList(),
//           onChanged: onChanged,
//         ),
//       );
//
//   Widget _dateTile(BuildContext context) => ListTile(
//         title: Text(_dob != null
//             ? 'DOB: ${_dob!.day}/${_dob!.month}/${_dob!.year}'
//             : 'Date of Birth'),
//         trailing: const Icon(Icons.calendar_today,
//             size: 18, color: AppColors.textMuted),
//         onTap: () async {
//           final picked = await showDatePicker(
//             context: context,
//             initialDate: _dob ?? DateTime(1995),
//             firstDate: DateTime(1940),
//             lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
//           );
//           if (picked != null) setState(() => _dob = picked);
//         },
//       );
// }

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

  Map<String, bool> _notifPrefs = {
    'friend_request': true,
    'trainer_request': true,
    'new_message': true,
    'post_like': true,
    'system': true,
  };

  // 🔥 FIX 1: These are now lowercase to perfectly match your backend API
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

  Future<void> _showTrainerApplicationDialog(BuildContext context) async {
    final phoneCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final aboutCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final certCtrl = TextEditingController();
    final rateCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trainer Application',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
              const SizedBox(height: 12),
              TextField(controller: expCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Years of Experience')),
              const SizedBox(height: 12),
              TextField(controller: aboutCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'About Me')),
              const SizedBox(height: 12),
              TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Specializations (comma separated)')),
              const SizedBox(height: 12),
              TextField(controller: certCtrl, decoration: const InputDecoration(labelText: 'Certifications (comma separated)')),
              const SizedBox(height: 12),
              TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hourly Rate (₹)')),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await _dio.post(ApiConstants.trainerApply, data: {
                        'phone_number': phoneCtrl.text,
                        'experience_years': int.tryParse(expCtrl.text),
                        'about': aboutCtrl.text,
                        'specializations': specCtrl.text,
                        'certifications': certCtrl.text,
                        'hourly_rate': double.tryParse(rateCtrl.text),
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted! Admin will review it.')));
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit application'), backgroundColor: AppColors.error));
                      }
                    }
                  },
                  child: const Text('Submit Application'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('local_water_goal', int.tryParse(_waterGoalCtrl.text) ?? 2500);

      await _dio.put(ApiConstants.profile, data: {
        'bio': _bioCtrl.text.isEmpty ? null : _bioCtrl.text,
        'gender': _gender,
        'date_of_birth': _dob?.toIso8601String(),
        'height_cm': double.tryParse(_heightCtrl.text),
        'weight_kg': double.tryParse(_weightCtrl.text),
        'daily_step_goal': int.tryParse(_stepGoalCtrl.text),
        'daily_calorie_goal': int.tryParse(_calorieGoalCtrl.text),
        'activity_level': _activityLevel,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save'), backgroundColor: AppColors.error));
      }
    }
    setState(() => _saving = false);
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
              _infoTile('Role', user.role.name),
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
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Profile'),
              ),
            ),

            if (user.role.name == 'trainee') ...[
              const SizedBox(height: 20),
              _header('Trainer'),
              _card([
                ListTile(
                  leading: const Icon(Icons.fitness_center, color: AppColors.primary, size: 20),
                  title: const Text('Apply to become a Trainer'),
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
            const SizedBox(height: 16),

            _header('Data'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
                title: const Text('Clear All My Data', style: TextStyle(color: AppColors.error)),
                subtitle: const Text('Deletes all workouts, meals, steps, and hydration logs', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear All Data'),
                    content: const Text('This will permanently delete all your fitness logs. This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await _dio.delete(ApiConstants.clearData);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All fitness data cleared')));
                            }
                          } catch (_) {}
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        child: const Text('Clear Data'),
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
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(labelText: label)),
      );

  // 🔥 FIX 2: Added the safe capitalization logic here!
  Widget _dropdownTile(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    // Check if the value is safely in the lowercase list
    final safeValue = items.contains(value?.toLowerCase()) ? value?.toLowerCase() : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        decoration: InputDecoration(labelText: label),
        items: items.map((i) {
          // Capitalize the first letter so it looks nice on the screen!
          String display = i;
          if (i.isNotEmpty) {
            display = i[0].toUpperCase() + i.substring(1).replaceAll('_', ' ');
          }
          return DropdownMenuItem(value: i, child: Text(display));
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
        initialDate: _dob ?? DateTime(1995),
        firstDate: DateTime(1940),
        lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      );
      if (picked != null) setState(() => _dob = picked);
    },
  );
}
