// // import 'package:flutter/material.dart';
// import '../../../../core/di/injection.dart';
// import '../../../../core/constants/api_constants.dart';
// import '../../../../shared/theme/app_theme.dart';
// import '../../data/trainer_remote_datasource.dart';
//
// class CoachingHubPage extends StatefulWidget {
//   final Map<String, dynamic> trainerInfo;
//   const CoachingHubPage({super.key, required this.trainerInfo});
//
//   @override
//   State<CoachingHubPage> createState() => _CoachingHubPageState();
// }
//
// class _CoachingHubPageState extends State<CoachingHubPage> {
//   final _ds = sl<TrainerRemoteDataSource>();
//   List<dynamic> _notes = [];
//   List<dynamic> _sessions = [];
//   bool _loading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }
//
//   Future<void> _load() async {
//     setState(() => _loading = true);
//     try {
//       final sessionRes = await _ds.dio.get('${ApiConstants.apiVersion}/trainer/my-sessions');
//       final notesRes = await _ds.dio.get('${ApiConstants.apiVersion}/trainer/my-notes');
//
//       if (mounted) {
//         setState(() {
//           _sessions = sessionRes.data as List<dynamic>;
//           _notes = notesRes.data as List<dynamic>;
//         });
//       }
//     } catch (_) {}
//     if (mounted) setState(() => _loading = false);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         title: const Text('My Coaching Hub', style: TextStyle(fontWeight: FontWeight.bold)),
//         backgroundColor: AppColors.surface,
//         elevation: 0,
//       ),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : RefreshIndicator(
//               onRefresh: _load,
//               child: ListView(
//                 padding: const EdgeInsets.all(16),
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(20),
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     child: Column(
//                       children: [
//                         const CircleAvatar(
//                           radius: 32,
//                           backgroundColor: Colors.white,
//                           child: Icon(Icons.person, size: 32, color: AppColors.primary),
//                         ),
//                         const SizedBox(height: 12),
//                         Text(widget.trainerInfo['full_name'] ?? 'Trainer',
//                             style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
//                         const Text('Your Coach', style: TextStyle(color: Colors.white70)),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//
//                   const Text('Upcoming Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 12),
//                   if (_sessions.isEmpty)
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
//                       child: const Text('No sessions scheduled yet.', style: TextStyle(color: AppColors.textMuted)),
//                     )
//                   else
//                     ..._sessions.map((s) {
//                       final dt = DateTime.tryParse(s['scheduled_at'] ?? '')?.toLocal();
//                       return Container(
//                         margin: const EdgeInsets.only(bottom: 8),
//                         child: ListTile(
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
//                           tileColor: AppColors.surface,
//                           leading: const Icon(Icons.calendar_month, color: AppColors.primary),
//                           title: Text(dt != null ? '${dt.day}/${dt.month}/${dt.year}' : 'Scheduled'),
//                           subtitle: Text(dt != null ? '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} · ${s['duration_minutes']} mins' : ''),
//                         ),
//                       );
//                     }),
//
//                   const SizedBox(height: 24),
//
//                   const Text('Coaching Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 12),
//                   if (_notes.isEmpty)
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
//                       child: const Text('Your trainer hasn\'t added any notes yet.', style: TextStyle(color: AppColors.textMuted)),
//                     )
//                   else
//                     ..._notes.map((n) {
//                       final dt = DateTime.tryParse(n['created_at'] ?? '')?.toLocal();
//                       return Container(
//                         margin: const EdgeInsets.only(bottom: 12),
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: AppColors.primary.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: AppColors.primary.withOpacity(0.2)),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
//                             const SizedBox(height: 8),
//                             Text(n['content'] ?? '', style: const TextStyle(fontSize: 14)),
//                           ],
//                         ),
//                       );
//                     }),
//                 ],
//               ),
//             ),
//     );
//   }
// }