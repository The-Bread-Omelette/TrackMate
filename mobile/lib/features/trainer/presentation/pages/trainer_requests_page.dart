import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/trainer_remote_datasource.dart';

class TrainerRequestsPage extends StatefulWidget {
  const TrainerRequestsPage({super.key});

  @override
  State<TrainerRequestsPage> createState() => _TrainerRequestsPageState();
}

class _TrainerRequestsPageState extends State<TrainerRequestsPage> {
  final _ds = TrainerRemoteDataSource(sl());
  List<dynamic> _requests = [];
  List<dynamic> _calendar = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _ds.getRequests(),
        _ds.getCalendar(),
      ]);
      if (mounted) {
        setState(() {
          _requests = results[0] as List<dynamic>;
          _calendar = results[1] as List<dynamic>;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _respond(String id, bool accept) async {
    try {
      await _ds.respondToRequest(id, accept);
      await _load();
    } catch (_) {}
  }

  // --- Grouping Logic ---
  Map<String, List<dynamic>> _getGroupedSessions() {
    final now = DateTime.now();
    List<dynamic> ongoing = [];
    List<dynamic> upcoming = [];
    List<dynamic> past = [];

    for (var s in _calendar) {
      final start = DateTime.tryParse(s['scheduled_at'] ?? '')?.toLocal();
      if (start == null) continue;

      final duration = s['duration_minutes'] as int? ?? 0;
      final end = start.add(Duration(minutes: duration));

      if (now.isAfter(start) && now.isBefore(end)) {
        ongoing.add(s);
      } else if (now.isAfter(end)) {
        past.add(s);
      } else {
        upcoming.add(s);
      }
    }
    return {'Ongoing': ongoing, 'Upcoming': upcoming, 'Past': past};
  }

  // --- Edit Session Dialog ---
  void _showEditSessionDialog(Map<String, dynamic> session) {
    String type = session['session_type'] ?? 'online';
    final linkCtrl = TextEditingController(text: session['meeting_link'] ?? '');
    final locCtrl = TextEditingController(text: session['location'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Session Details'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(value: 'offline', child: Text('Offline')),
                ],
                onChanged: (v) => setDialogState(() => type = v!),
                decoration: const InputDecoration(labelText: 'Session Type', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              if (type == 'online')
                TextField(controller: linkCtrl, decoration: const InputDecoration(labelText: 'Meeting Link', border: OutlineInputBorder())),
              if (type == 'offline')
                TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location/Gym', border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Show loading feedback
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updating session...'), duration: Duration(seconds: 1)));
                  
                  await _ds.updateSession(session['session_id'], {
                    'session_type': type,
                    'meeting_link': linkCtrl.text,
                    'location': locCtrl.text,
                  });
                  
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session updated successfully!')));
                    _load(); // Refresh the list
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update. Server error.')));
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticatedState ? authState.user : null;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final grouped = _getGroupedSessions();

    return MainLayout(
      user: user,
      title: 'Requests & Calendar',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Pending Requests', _requests.length),
              const SizedBox(height: 12),
              if (_requests.isEmpty) _buildEmptyState('No pending requests')
              else ..._requests.map((r) => _buildRequestCard(r)),

              const SizedBox(height: 32),
              const Text('Schedule Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (_calendar.isEmpty) _buildEmptyState('No scheduled sessions')
              else ...[
                _buildGroupedList('Ongoing', grouped['Ongoing']!, isAlert: true),
                _buildGroupedList('Upcoming', grouped['Upcoming']!),
                _buildGroupedList('Past', grouped['Past']!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (count > 0)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
            child: Text('$count', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final trainee = req['trainee'] as Map<String, dynamic>? ?? {};
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text((trainee['full_name'] as String? ?? 'U')[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(trainee['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            ],
          ),
          const SizedBox(height: 8),
          Text(req['goal'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: () => _respond(req['request_id'], true), icon: const Icon(Icons.check, size: 16), label: const Text('Accept'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: () => _respond(req['request_id'], false), icon: const Icon(Icons.close, color: AppColors.error, size: 16), label: const Text('Decline', style: TextStyle(color: AppColors.error)), style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(String title, List<dynamic> sessions, {bool isAlert = false}) {
    if (sessions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: isAlert ? AppColors.success : AppColors.textMuted)),
        ),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = sessions[i] as Map<String, dynamic>;
              final trainee = s['trainee'] as Map<String, dynamic>? ?? {};
              final dt = DateTime.tryParse(s['scheduled_at'] ?? '')?.toLocal();
              
              // Reads the explicit backend fields
              final isOnline = s['session_type'] == 'online';
              final meetLink = s['meeting_link'] ?? '';
              final location = s['location'] ?? '';
              final isActionable = title == 'Ongoing' || title == 'Past';

              return ListTile(
                leading: Icon(
                  isOnline ? Icons.videocam : Icons.location_on,
                  color: isAlert ? AppColors.success : AppColors.primary,
                  size: 20,
                ),
                title: Text(trainee['full_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dt != null ? '${dt.day}/${dt.month} · ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}' : ''),
                    if (isOnline && meetLink.isNotEmpty)
                      Text(meetLink, style: const TextStyle(color: Colors.blue, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (!isOnline && location.isNotEmpty)
                      Text(location, style: const TextStyle(fontSize: 11)),
                  ],
                ),
                trailing: isActionable
                    ? TextButton(
                        onPressed: () => _respond(s['session_id'], true),
                        child: const Text('Complete', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                      )
                    : null
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Center(child: Text(message, style: const TextStyle(color: AppColors.textMuted))),
    );
  }
}