import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/trainer_remote_datasource.dart';

// 🔥 UNCOMMENT AND FIX THESE IMPORTS FOR YOUR PROJECT STRUCTURE
import '../../../messaging/data/messaging_remote_datasource.dart';
import '../../../messaging/presentation/pages/chat_page.dart';
import 'coaching_hub_page.dart';

class FindTrainerPage extends StatefulWidget {
  const FindTrainerPage({super.key});

  @override
  State<FindTrainerPage> createState() => _FindTrainerPageState();
}

class _FindTrainerPageState extends State<FindTrainerPage> {
  final _ds = TrainerRemoteDataSource(sl());
  List<dynamic> _trainers = [];
  bool _loading = true;
  
  String? _currentTrainerId;
  final Set<String> _sentRequests = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    
    try {
      _trainers = await _ds.getAvailableTrainers();
    } catch (_) {}

    try {
      final res = await sl<Dio>().get('/api/v1/trainer/my-trainer');
      if (res.data != null && res.data['trainer'] != null) {
        _currentTrainerId = res.data['trainer']['id'];
      } else {
        _currentTrainerId = null;
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  // 🔥 API Call to fire the current trainer
  Future<void> _quitTrainer() async {
    try {
      await sl<Dio>().post('/api/v1/trainer/quit');
      setState(() {
        _currentTrainerId = null; // Unlocks the request buttons
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have successfully quit your trainer.')),
        );
      }
    } catch (_) {}
  }

  void _sendRequest(BuildContext context, String trainerId) {
    final goalCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send Request',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: goalCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'What are your fitness goals?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (goalCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx); 
                  try {
                    await _ds.sendTrainerRequest(trainerId, goalCtrl.text.trim());
                    setState(() {
                      _sentRequests.add(trainerId);
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Request sent!')),
                      );
                    }
                  } catch (_) {}
                },
                child: const Text('Send Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewProfile(BuildContext context, Map<String, dynamic> t) {
    final bool isCurrentTrainer = t['id'] == _currentTrainerId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                radius: 40,
                child: Text(
                  (t['full_name'] as String? ?? 'T')[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 32),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(t['full_name'] ?? 'Trainer', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (t['experience_years'] != null)
              Text('${t['experience_years']} years experience', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            
            if (t['bio'] != null && t['bio'].toString().trim().isNotEmpty) ...[
              const Text('About Me', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(t['bio'], style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 24),
            ],
            
            if (t['certifications'] != null && t['certifications'].toString().trim().isNotEmpty) ...[
              const Text('Certifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(t['certifications'], style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
            ],

            // 🔥 DYNAMIC PROFILE CONTROLS
            if (isCurrentTrainer) ...[
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      icon: const Icon(Icons.chat_bubble, color: Colors.white),
                      label: const Text('Message', style: TextStyle(color: Colors.white)),
                      onPressed: () async {
                        try {
                          // NOTE: Ensure your MessagingRemoteDataSource & ChatPage are imported!
                          final msgDs = sl<MessagingRemoteDataSource>(); 
                          final convData = await msgDs.startConversation(t['id']);
                          if (ctx.mounted) {
                            final authState = ctx.read<AuthBloc>().state as AuthAuthenticatedState;
                            Navigator.pushReplacement(
                              ctx, 
                              MaterialPageRoute(builder: (_) => ChatPage(
                                conversationId: convData['conversation_id'], 
                                otherUserId: t['id'], 
                                otherUserName: t['full_name'], 
                                ds: msgDs, 
                                currentUserId: authState.user.id
                              ))
                            );
                          }
                        } catch (e) {
                          debugPrint("Chat error: $e");
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                      icon: const Icon(Icons.hub, color: Colors.white),
                      label: const Text('Hub', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        // NOTE: Ensure CoachingHubPage is imported!
                        Navigator.pushReplacement(
                          ctx,
                          MaterialPageRoute(builder: (_) => CoachingHubPage(trainerInfo: t)),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Quit Trainer'),
                  onPressed: () {
                    showDialog(
                      context: ctx,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Quit Trainer?'),
                        content: const Text('Are you sure you want to stop working with this trainer?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogCtx); // Close Dialog
                              Navigator.pop(ctx);       // Close Bottom Sheet
                              _quitTrainer();           // Fire Trainer
                            },
                            child: const Text('Quit', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              // Default Close Button for Non-Current Trainers
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Profile'),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticatedState).user;

    return MainLayout(
      user: user,
      title: 'Find a Trainer',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _trainers.isEmpty
                  ? const Center(
                      child: Text('No trainers available',
                          style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _trainers.length,
                      itemBuilder: (context, i) {
                        final t = _trainers[i] as Map<String, dynamic>;
                        final String trainerId = t['id'];
                        
                        final bool isCurrent = trainerId == _currentTrainerId;
                        final bool hasOtherTrainer = _currentTrainerId != null && !isCurrent;
                        final bool isSent = _sentRequests.contains(trainerId);

                        final List<String> specs = (t['specializations'] as String?)
                            ?.split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty) 
                            .toList() ?? [];

                        return InkWell(
                          onTap: () => _viewProfile(context, t),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      radius: 24,
                                      child: Text(
                                        (t['full_name'] as String? ?? 'T')[0].toUpperCase(),
                                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(t['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          if (t['experience_years'] != null)
                                            Text('${t['experience_years']} years experience', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    if (t['hourly_rate'] != null)
                                      Text(
                                        '₹${t['hourly_rate']}/hr',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                  ],
                                ),
                                if (t['bio'] != null && t['bio'].toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(t['bio'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ],
                                if (specs.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    children: specs.map((s) => Chip(
                                          label: Text(s, style: const TextStyle(fontSize: 11)),
                                          backgroundColor: AppColors.primary.withOpacity(0.08),
                                          side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                                          padding: EdgeInsets.zero,
                                        )).toList(),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: (isCurrent || hasOtherTrainer || isSent) 
                                        ? null 
                                        : () => _sendRequest(context, trainerId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isCurrent ? Colors.green : AppColors.primary,
                                      disabledBackgroundColor: AppColors.border,
                                    ),
                                    child: Text(
                                      isCurrent 
                                          ? 'Current Trainer' 
                                          : hasOtherTrainer 
                                              ? 'Please Quit Current Trainer First'
                                              : isSent
                                                  ? 'Request Sent'
                                                  : 'Request as My Trainer',
                                      style: TextStyle(
                                        color: (isCurrent || hasOtherTrainer || isSent) ? AppColors.textSecondary : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}