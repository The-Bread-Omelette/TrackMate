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
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _ds.getRequests(),
        _ds.getCalendar(),
      ]);
      setState(() {
        _requests = results[0] as List<dynamic>;
        _calendar = results[1] as List<dynamic>;
      });
    } catch (_) {}
    setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticatedState ? authState.user : null;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
              // --- PENDING REQUESTS SECTION ---
              _buildSectionHeader('Pending Requests', _requests.length),
              const SizedBox(height: 12),
              if (_requests.isEmpty)
                _buildEmptyState('No pending requests')
              else
                ..._requests.map((r) => _buildRequestCard(r)),

              const SizedBox(height: 32),

              // --- CALENDAR SECTIONS (Ongoing, Upcoming, Past) ---
              const Text('Schedule Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (_calendar.isEmpty)
                _buildEmptyState('No scheduled sessions')
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

  // --- Helper Widgets ---

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
                child: Text((trainee['full_name'] as String? ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _respond(req['request_id'], true),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _respond(req['request_id'], false),
                  icon: const Icon(Icons.close, color: AppColors.error, size: 16),
                  label: const Text('Decline', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                ),
              ),
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
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isAlert ? AppColors.success : AppColors.textMuted,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = sessions[i] as Map<String, dynamic>;
              final trainee = s['trainee'] as Map<String, dynamic>? ?? {};
              final dt = DateTime.tryParse(s['scheduled_at'] ?? '')?.toLocal();
              final isActionable = title == 'Ongoing' || title == 'Past';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAlert ? AppColors.success : AppColors.primary,
                  radius: 4,
                ),
                title: Text(trainee['full_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(dt != null ? '${dt.day}/${dt.month} · ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}' : ''),
                trailing: isActionable
                    ? TextButton(
                  onPressed: () => _respond(s['session_id'], true),
                  child: const Text('Complete', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                )
                    : Text('${s['duration_minutes']} min', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(child: Text(message, style: const TextStyle(color: AppColors.textMuted))),
    );
  }
}