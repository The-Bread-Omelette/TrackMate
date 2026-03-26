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

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticatedState ? authState.user : null;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pending Requests',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Text('${_requests.length}',
                              style: const TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_requests.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text('No pending requests',
                              style:
                                  TextStyle(color: AppColors.textMuted)),
                        ),
                      )
                    else
                      ..._requests.map((r) {
                        final req = r as Map<String, dynamic>;
                        final trainee =
                            req['trainee'] as Map<String, dynamic>? ?? {};
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
                                    backgroundColor:
                                        AppColors.primary.withOpacity(0.1),
                                    child: Text(
                                      (trainee['full_name'] as String? ??
                                              'U')[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      trainee['full_name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(req['goal'] ?? '',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _respond(
                                          req['request_id'], true),
                                      icon: const Icon(Icons.check,
                                          size: 16),
                                      label: const Text('Accept'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.success),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _respond(
                                          req['request_id'], false),
                                      icon: const Icon(Icons.close,
                                          color: AppColors.error, size: 16),
                                      label: const Text('Decline',
                                          style: TextStyle(
                                              color: AppColors.error)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: AppColors.error),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 24),
                    const Text('Upcoming Sessions',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_calendar.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text('No scheduled sessions',
                              style:
                                  TextStyle(color: AppColors.textMuted)),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _calendar.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final s = _calendar[i] as Map<String, dynamic>;
                            final trainee = s['trainee']
                                as Map<String, dynamic>? ?? {};
                            final dt = DateTime.tryParse(
                                    s['scheduled_at'] ?? '')
                                ?.toLocal();
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.primary,
                                radius: 4,
                              ),
                              title: Text(trainee['full_name'] ?? ''),
                              subtitle: Text(dt != null
                                  ? '${dt.day}/${dt.month} · ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'
                                  : ''),
                              trailing: Text(
                                  '${s['duration_minutes']} min',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}