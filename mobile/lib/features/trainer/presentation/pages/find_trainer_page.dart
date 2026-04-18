import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/trainer_remote_datasource.dart';
import '../../../messaging/data/messaging_remote_datasource.dart';
import '../../../messaging/presentation/pages/chat_page.dart';
import 'coaching_hub_page.dart';

enum TrainerSortOption { none, rateAsc, rateDesc, expDesc }

class FindTrainerPage extends StatefulWidget {
  const FindTrainerPage({super.key});

  @override
  State<FindTrainerPage> createState() => _FindTrainerPageState();
}

class _FindTrainerPageState extends State<FindTrainerPage> {
  final _ds = TrainerRemoteDataSource(sl());

  List<dynamic> _allTrainers = [];
  List<dynamic> _filteredTrainers = [];

  bool _loading = true;
  String? _currentTrainerId;
  final Set<String> _sentRequests = {};

  late final TextEditingController _searchController;
  TrainerSortOption _currentSort = TrainerSortOption.none;

  String _selectedSpeciality = 'All';

  static const List<String> _preMadeSpecialities = [
    'All', 'Weight Loss', 'Muscle Gain', 'Bodybuilding', 'Powerlifting', 'CrossFit',
    'Yoga', 'Pilates', 'HIIT', 'Calisthenics', 'Marathon Training', 'Boxing',
    'MMA', 'Nutrition Coaching', 'Injury Rehabilitation', 'Senior Fitness',
    'Pre-natal Fitness', 'Post-natal Fitness', 'Mobility & Flexibility',
    'Kettlebell Training', 'TRX', 'Swimming', 'Cycling', 'Endurance Training',
    'Functional Training', 'Athletic Performance', 'Power & Agility'
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      _allTrainers = await _ds.getAvailableTrainers();
    } catch (_) {}

    try {
      final res = await sl<Dio>().get('/api/v1/trainer/my-trainer');
      if (res.data != null && res.data['trainer'] != null) {
        _currentTrainerId = res.data['trainer']['id']?.toString();
      } else {
        _currentTrainerId = null;
      }
    } catch (_) {}

    if (mounted) {
      _applyFilters();
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    List<dynamic> temp = List.from(_allTrainers);
    final query = _searchController.text.trim().toLowerCase();

    // 1. Text Search Filtering
    if (query.isNotEmpty) {
      temp = temp.where((t) {
        final name = (t['full_name']?.toString() ?? '').toLowerCase();
        final specs = (t['specializations']?.toString() ?? '').toLowerCase();
        final bio = (t['bio']?.toString() ?? '').toLowerCase();

        return name.contains(query) || specs.contains(query) || bio.contains(query);
      }).toList();
    }

    // 2. Speciality Dropdown Filtering
    if (_selectedSpeciality != 'All') {
      temp = temp.where((t) {
        final specs = (t['specializations']?.toString() ?? '').toLowerCase();
        return specs.contains(_selectedSpeciality.toLowerCase());
      }).toList();
    }

    // 3. Sorting
    if (_currentSort != TrainerSortOption.none) {
      temp.sort((a, b) {
        num getRate(dynamic r) {
          if (r is num) return r;
          if (r is String) return num.tryParse(r) ?? double.infinity;
          return double.infinity;
        }

        num getExp(dynamic e) {
          if (e is num) return e;
          if (e is String) return num.tryParse(e) ?? 0;
          return 0;
        }

        switch (_currentSort) {
          case TrainerSortOption.rateAsc:
            return getRate(a['hourly_rate']).compareTo(getRate(b['hourly_rate']));
          case TrainerSortOption.rateDesc:
            num rateA = a['hourly_rate'] == null ? -1 : getRate(a['hourly_rate']);
            num rateB = b['hourly_rate'] == null ? -1 : getRate(b['hourly_rate']);
            return rateB.compareTo(rateA);
          case TrainerSortOption.expDesc:
            return getExp(b['experience_years']).compareTo(getExp(a['experience_years']));
          case TrainerSortOption.none:
            return 0;
        }
      });
    }

    setState(() {
      _filteredTrainers = temp;
    });
  }

  Future<void> _quitTrainer() async {
    try {
      await sl<Dio>().post('/api/v1/trainer/quit');
      setState(() {
        _currentTrainerId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have successfully quit your trainer.')),
        );
      }
    } catch (_) {}
  }

  String _formatExperience(dynamic exp) {
    if (exp == null) return 'N/A';
    int val = 0;
    if (exp is int) {
      val = exp;
    } else if (exp is String) {
      val = int.tryParse(exp) ?? 0;
    } else if (exp is num) {
      val = exp.toInt();
    }
    if (val > 60) return '60+';
    return val.toString();
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
              maxLength: 1000,
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
    final String trainerId = t['id']?.toString() ?? '';
    final bool isCurrentTrainer = trainerId == _currentTrainerId;

    final fullName = t['full_name']?.toString() ?? 'Trainer';
    final email = t['email']?.toString() ?? '';
    final phone = t['phone_number']?.toString() ?? '';
    final bio = t['bio']?.toString() ?? '';
    final specializations = t['specializations']?.toString() ?? '';
    final certifications = t['certifications']?.toString() ?? '';
    final hourlyRate = t['hourly_rate']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.5,
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
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'T',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 32),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(fullName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

            const SizedBox(height: 4),
            Text(
              [email, phone].where((e) => e.isNotEmpty).join('  •  '),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text('Experience', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${_formatExperience(t['experience_years'])} yrs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Container(width: 1, height: 40, color: AppColors.border),
                Column(
                  children: [
                    const Text('Hourly Rate', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(hourlyRate != null ? '₹$hourlyRate/hr' : 'Contact', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (bio.trim().isNotEmpty) ...[
              const Text('About Me', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(bio, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 24),
            ],

            if (specializations.trim().isNotEmpty) ...[
              const Text('Specializations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: specializations.split(',').map((s) => Chip(
                  label: Text(s.trim(), style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  side: BorderSide.none,
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],

            if (certifications.trim().isNotEmpty) ...[
              const Text('Certifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: certifications.split(',').map((s) => Chip(
                  label: Text(s.trim(), style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.blueGrey.withOpacity(0.1),
                  side: BorderSide.none,
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],

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
                          final msgDs = sl<MessagingRemoteDataSource>();
                          final convData = await msgDs.startConversation(trainerId);
                          if (ctx.mounted) {
                            final authState = ctx.read<AuthBloc>().state as AuthAuthenticatedState;
                            Navigator.pushReplacement(
                                ctx,
                                MaterialPageRoute(builder: (_) => ChatPage(
                                    conversationId: convData['conversation_id'],
                                    otherUserId: trainerId,
                                    otherUserName: fullName,
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
                              Navigator.pop(dialogCtx);
                              Navigator.pop(ctx);
                              _quitTrainer();
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: 'Search by name, specialty, bio...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        );
                      },
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),

                const SizedBox(height: 12),

                // Specialty Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSpeciality,
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedSpeciality = newValue;
                          });
                          _applyFilters();
                        }
                      },
                      items: _preMadeSpecialities.map((String spec) {
                        return DropdownMenuItem<String>(
                          value: spec,
                          child: Text(spec == 'All' ? 'All Specialties' : spec),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_filteredTrainers.length} Result${_filteredTrainers.length != 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TrainerSortOption>(
                          value: _currentSort,
                          icon: const Icon(Icons.sort, size: 18),
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          onChanged: (TrainerSortOption? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _currentSort = newValue;
                              });
                              _applyFilters();
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: TrainerSortOption.none, child: Text('Default Sort')),
                            DropdownMenuItem(value: TrainerSortOption.rateAsc, child: Text('Rate: Low to High')),
                            DropdownMenuItem(value: TrainerSortOption.rateDesc, child: Text('Rate: High to Low')),
                            DropdownMenuItem(value: TrainerSortOption.expDesc, child: Text('Experience: Highest')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _load,
              child: _filteredTrainers.isEmpty
                  ? const Center(
                  child: Text('No trainers match your criteria',
                      style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredTrainers.length,
                itemBuilder: (context, i) {
                  final t = _filteredTrainers[i] as Map<String, dynamic>;
                  final String trainerId = t['id']?.toString() ?? '';

                  final bool isCurrent = trainerId == _currentTrainerId;
                  final bool hasOtherTrainer = _currentTrainerId != null && !isCurrent;
                  final bool isSent = _sentRequests.contains(trainerId);

                  final fullName = t['full_name']?.toString() ?? 'Trainer';
                  final phone = t['phone_number']?.toString() ?? '';
                  final hourlyRate = t['hourly_rate']?.toString();
                  final bio = t['bio']?.toString() ?? '';
                  final specsStr = t['specializations']?.toString() ?? '';
                  final certsStr = t['certifications']?.toString() ?? '';

                  final List<String> specs = specsStr.isNotEmpty
                      ? specsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                      : [];

                  final List<String> certs = certsStr.isNotEmpty
                      ? certsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                      : [];

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
                                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'T',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

                                    const SizedBox(height: 2),
                                    Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          if (t['experience_years'] != null)
                                            Text('${_formatExperience(t['experience_years'])} yrs exp', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                          if (t['experience_years'] != null && phone.isNotEmpty)
                                            const Text('  •  ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                          if (phone.isNotEmpty)
                                            Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                        ]
                                    )
                                  ],
                                ),
                              ),
                              if (hourlyRate != null)
                                Text(
                                  '₹$hourlyRate/hr',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                            ],
                          ),
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                          if (specs.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: specs.map((s) => Chip(
                                label: Text(s, style: const TextStyle(fontSize: 11)),
                                backgroundColor: AppColors.primary.withOpacity(0.08),
                                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                                padding: EdgeInsets.zero,
                              )).toList(),
                            ),
                          ],
                          if (certs.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: certs.map((s) => Chip(
                                label: Text(s, style: const TextStyle(fontSize: 10)),
                                backgroundColor: Colors.blueGrey.withOpacity(0.08),
                                side: BorderSide(color: Colors.blueGrey.withOpacity(0.3)),
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
          ),
        ],
      ),
    );
  }
}