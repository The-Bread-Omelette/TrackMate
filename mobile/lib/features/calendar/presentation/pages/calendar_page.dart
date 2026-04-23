import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart'; // 🔥 NEW: For clickable links
import '../../../../core/di/injection.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../trainer/data/trainer_remote_datasource.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _ds = TrainerRemoteDataSource(sl());
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _ds.dio.get('/api/v1/trainer/my-sessions');
      _sessions = res.data as List<dynamic>;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // 🔥 NEW: Safe URL Launcher
  Future<void> _launchUrl(String urlString) async {
    if (urlString.isEmpty) return;
    
    // Ensure it has a scheme so the OS knows it's a web link
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }

    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the meeting link.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticatedState).user;

    return MainLayout(
      user: user,
      title: 'My Schedule',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _sessions.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No sessions scheduled.\nRequest a trainer to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (_, i) {
                        final s = _sessions[i] as Map<String, dynamic>;
                        final trainer = s['trainer'] as Map<String, dynamic>? ?? {};
                        final dt = DateTime.tryParse(s['scheduled_at'] ?? '')?.toLocal();
                        final isPast = dt != null && dt.isBefore(DateTime.now());

                        // 🔥 PARSER: Extract packed data from notes
                        String rawNotes = s['notes'] ?? '';
                        String type = 'online';
                        String meetLink = '';
                        String location = '';
                        String cleanNotes = rawNotes;

                        final typeMatch = RegExp(r'\[Type:(.*?)\]').firstMatch(rawNotes);
                        if (typeMatch != null) {
                          type = typeMatch.group(1) ?? 'online';
                          cleanNotes = cleanNotes.replaceAll(typeMatch.group(0)!, '');
                        }

                        final linkMatch = RegExp(r'\[Link:(.*?)\]').firstMatch(rawNotes);
                        if (linkMatch != null) {
                          meetLink = linkMatch.group(1) ?? '';
                          cleanNotes = cleanNotes.replaceAll(linkMatch.group(0)!, '');
                        }

                        final locMatch = RegExp(r'\[Loc:(.*?)\]').firstMatch(rawNotes);
                        if (locMatch != null) {
                          location = locMatch.group(1) ?? '';
                          cleanNotes = cleanNotes.replaceAll(locMatch.group(0)!, '');
                        }

                        cleanNotes = cleanNotes.trim();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPast ? AppColors.border : AppColors.primary.withOpacity(0.3),
                              width: isPast ? 1 : 1.5,
                            ),
                            boxShadow: isPast ? [] : [
                              BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                            ]
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date Block
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isPast ? AppColors.border : AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      dt != null ? '${dt.day}' : '--',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isPast ? AppColors.textMuted : AppColors.primary),
                                    ),
                                    Text(
                                      dt != null ? _monthAbbr(dt.month) : '',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isPast ? AppColors.textMuted : AppColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Main Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title & Status Pill
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Session with ${trainer['full_name'] ?? ''}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                        ),
                                        if (!isPast)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                            child: const Text('Upcoming', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    
                                    // Time & Duration
                                    Text(
                                      dt != null ? '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} • ${s['duration_minutes']} min' : '',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 12),

                                    // 🔥 THE FANCY TAGS (Online/Offline & Location)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(type == 'online' ? Icons.videocam : Icons.location_on, size: 12, color: Colors.black54),
                                              const SizedBox(width: 4),
                                              Text(type.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
                                            ],
                                          ),
                                        ),
                                        if (type == 'offline' && location.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.place, size: 12, color: Colors.black54),
                                                const SizedBox(width: 4),
                                                Flexible(child: Text(location, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),

                                    // 🔥 THE FANCY BLUE MEET LINK
                                    if (type == 'online' && meetLink.isNotEmpty)
                                      GestureDetector(
                                        onTap: () => _launchUrl(meetLink),
                                        child: Container(
                                          margin: const EdgeInsets.only(top: 12),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.video_call, size: 18, color: Colors.blue.shade700),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Join Meeting',
                                                  style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ),
                                              Icon(Icons.open_in_new, size: 14, color: Colors.blue.shade700),
                                            ],
                                          ),
                                        ),
                                      ),

                                    // 🔥 THE FANCY YELLOW STICKY NOTE
                                    if (cleanNotes.isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(top: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF9C4), // Light Yellow
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFFFF176)), // Slightly darker yellow border
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.sticky_note_2, size: 16, color: Color(0xFFFBC02D)), // Dark Yellow Icon
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                cleanNotes,
                                                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _monthAbbr(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }
}