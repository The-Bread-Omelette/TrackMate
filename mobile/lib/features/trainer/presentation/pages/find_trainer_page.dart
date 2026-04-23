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
  final FocusNode _searchFocus = FocusNode();
  
  TrainerSortOption _currentSort = TrainerSortOption.none;
  String _selectedSpeciality = 'All';

  // 🔥 Strictly holds our allowed active tags
  final List<Map<String, String>> _searchTokens = [];

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
    _searchFocus.addListener(() => setState(() {})); // Rebuilds UI to show/hide the Discord overlay
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
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

  num _getRate(dynamic r) {
    if (r == null) return double.infinity; 
    if (r is num) return r;
    if (r is String) return num.tryParse(r) ?? double.infinity;
    return double.infinity;
  }

  num _getExp(dynamic e) {
    if (e == null) return 0;
    if (e is num) return e;
    if (e is String) return num.tryParse(e) ?? 0;
    return 0;
  }

  // 🔥 THE SMART REGEX TOKENIZER
  void _onSearchChanged(String text) {
    // Looks for exactly "name: something ", "exp: 5 ", or "rate: 500 " (with or without spaces after the colon)
    final regex = RegExp(r'(name|exp|rate):\s*([^\s]+)\s', caseSensitive: false);
    final match = regex.firstMatch(text);

    if (match != null) {
      String key = match.group(1)!.toLowerCase();
      String val = match.group(2)!;

      if (!_searchTokens.any((t) => t['key'] == key && t['value'] == val)) {
        _searchTokens.add({"key": key, "value": val});
      }

      // Strip the matched bubble out of the text field
      String newText = text.replaceFirst(match.group(0)!, '');
      _searchController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    
    _applyFilters();
    setState(() {}); 
  }

  void _applyFilters() {
    List<dynamic> temp = List.from(_allTrainers);
    final rawQuery = _searchController.text.trim().toLowerCase();

    // 1. Tag Filters (Strictly name, exp, rate)
    for (var token in _searchTokens) {
      final key = token['key']!.toLowerCase();
      final val = token['value']!.toLowerCase();

      temp = temp.where((t) {
        if (key == 'name') return (t['full_name']?.toString() ?? '').toLowerCase().contains(val);
        if (key == 'exp') return _getExp(t['experience_years']) >= (num.tryParse(val) ?? 0);
        if (key == 'rate') return _getRate(t['hourly_rate']) <= (num.tryParse(val) ?? double.infinity);
        return true;
      }).toList();
    }

    // 2. Powerful Multi-Word Text Search Fallback
    if (rawQuery.isNotEmpty) {
      // Split the search into words so "yoga john" finds John who teaches Yoga
      List<String> searchWords = rawQuery.split(' ').where((w) => w.isNotEmpty).toList();
      
      temp = temp.where((t) {
        final name = (t['full_name']?.toString() ?? '').toLowerCase();
        final specs = (t['specializations']?.toString() ?? '').toLowerCase();
        final bio = (t['bio']?.toString() ?? '').toLowerCase();
        
        final combinedText = '$name $specs $bio';
        
        // Every word typed must exist SOMEWHERE in the profile
        return searchWords.every((word) => combinedText.contains(word));
      }).toList();
    }

    // 3. Specialty Dropdown
    if (_selectedSpeciality != 'All') {
      temp = temp.where((t) {
        return (t['specializations']?.toString() ?? '').toLowerCase().contains(_selectedSpeciality.toLowerCase());
      }).toList();
    }

    // 4. Sorting
    if (_currentSort != TrainerSortOption.none) {
      temp.sort((a, b) {
        switch (_currentSort) {
          case TrainerSortOption.rateAsc: return _getRate(a['hourly_rate']).compareTo(_getRate(b['hourly_rate']));
          case TrainerSortOption.rateDesc: return _getRate(b['hourly_rate']).compareTo(_getRate(a['hourly_rate']));
          case TrainerSortOption.expDesc: return _getExp(b['experience_years']).compareTo(_getExp(a['experience_years']));
          case TrainerSortOption.none: return 0;
        }
      });
    }

    setState(() => _filteredTrainers = temp);
  }

  // 🔥 Injects the key perfectly and ensures the keyboard stays up
  void _injectFilterKey(String key) {
    String current = _searchController.text;
    // Strip out any trailing spaces
    if (current.endsWith(' ')) current = current.trimRight();
    
    String prefix = current.isEmpty ? '' : '$current ';
    
    _searchController.value = TextEditingValue(
      text: '$prefix$key: ', // Automatically add the space after the colon for typing ease
      selection: TextSelection.collapsed(offset: ('$prefix$key: ').length),
    );
    
    _searchFocus.requestFocus();
    setState(() {});
    _applyFilters();
  }

  Future<void> _quitTrainer() async {
    try {
      await sl<Dio>().post('/api/v1/trainer/quit');
      setState(() => _currentTrainerId = null);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have successfully quit your trainer.')));
    } catch (_) {}
  }

  String _formatExperience(dynamic exp) {
    int val = _getExp(exp).toInt();
    if (val == 0) return 'N/A';
    if (val > 60) return '60+';
    return val.toString();
  }

  void _sendRequest(BuildContext context, String trainerId) {
    final goalCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Send Request', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Tell the trainer a bit about your goals.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            TextField(
              controller: goalCtrl,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'e.g., I want to lose 5kg...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () async {
                  if (goalCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await _ds.sendTrainerRequest(trainerId, goalCtrl.text.trim());
                    setState(() => _sentRequests.add(trainerId));
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent successfully!')));
                  } catch (_) {}
                },
                child: const Text('Send Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.8), AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 24),
                    CircleAvatar(backgroundColor: Colors.white, radius: 46, child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'T', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 36))),
                    const SizedBox(height: 16),
                    Text(fullName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (email.isNotEmpty || phone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text([email, phone].where((e) => e.isNotEmpty).join('  •  '), textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    ]
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _ProfileStatCard(title: 'Experience', value: '${_formatExperience(t['experience_years'])} yrs', icon: Icons.workspace_premium)),
                        const SizedBox(width: 16),
                        Expanded(child: _ProfileStatCard(title: 'Hourly Rate', value: hourlyRate != null ? '₹$hourlyRate' : 'Contact', icon: Icons.payments_outlined)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (bio.trim().isNotEmpty) ...[
                      const Text('About Me', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(bio, style: const TextStyle(color: AppColors.textSecondary, height: 1.6, fontSize: 14)),
                      const SizedBox(height: 32),
                    ],
                    if (specializations.trim().isNotEmpty) ...[
                      const Text('Specializations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: specializations.split(',').map((s) => _PremiumChip(label: s.trim(), color: AppColors.primary)).toList()),
                      const SizedBox(height: 32),
                    ],
                    if (certifications.trim().isNotEmpty) ...[
                      const Text('Certifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: certifications.split(',').map((s) => _PremiumChip(label: s.trim(), color: Colors.teal)).toList()),
                      const SizedBox(height: 32),
                    ],
                    if (isCurrentTrainer) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              icon: const Icon(Icons.chat_bubble, color: Colors.white),
                              label: const Text('Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                try {
                                  final msgDs = sl<MessagingRemoteDataSource>();
                                  final convData = await msgDs.startConversation(trainerId);
                                  if (ctx.mounted) {
                                    final authState = ctx.read<AuthBloc>().state as AuthAuthenticatedState;
                                    Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (_) => ChatPage(conversationId: convData['conversation_id'], otherUserId: trainerId, otherUserName: fullName, ds: msgDs, currentUserId: authState.user.id)));
                                  }
                                } catch (e) { debugPrint("Chat error: $e"); }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              icon: const Icon(Icons.hub, color: Colors.white),
                              label: const Text('Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () => Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (_) => CoachingHubPage(trainerInfo: t))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 16)),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Quit Trainer', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            showDialog(
                              context: ctx,
                              builder: (dialogCtx) => AlertDialog(
                                title: const Text('Quit Trainer?'),
                                content: const Text('Are you sure you want to stop working with this trainer?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                                  TextButton(onPressed: () { Navigator.pop(dialogCtx); Navigator.pop(ctx); _quitTrainer(); }, child: const Text('Quit', style: TextStyle(color: AppColors.error))),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: const BorderSide(color: AppColors.border, width: 2)),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close Profile', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 THE DISCORD OVERLAY CONTENT
  Widget _buildDiscordDropdownContent() {
    // If they are actively typing a parameter (e.g. "rate: 50"), hide the menu to let them type
    final activeKeyMatch = RegExp(r'(name|exp|rate):\s*([^\s]*)', caseSensitive: false).firstMatch(_searchController.text);
    
    if (activeKeyMatch != null) {
      String key = activeKeyMatch.group(1)!;
      String val = activeKeyMatch.group(2)!;
      
      // If they haven't finished typing the value yet, show a helpful hint
      if (val.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Type a value for $key and press Space to apply', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
        );
      } else {
        // If they are typing the value, hide the overlay completely so it's not distracting
        return const SizedBox.shrink();
      }
    }

    // Default Filters Menu
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4), 
          child: Text('FILTERS', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.2))
        ),
        _DiscordFilterTile(icon: Icons.person, title: 'From a specific trainer', subtitle: 'name:', onTap: () => _injectFilterKey('name')),
        _DiscordFilterTile(icon: Icons.star, title: 'Minimum experience years', subtitle: 'exp:', onTap: () => _injectFilterKey('exp')),
        _DiscordFilterTile(icon: Icons.payments, title: 'Maximum hourly rate', subtitle: 'rate:', onTap: () => _injectFilterKey('rate')),
        const SizedBox(height: 8),
      ],
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Discord-Style Search Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border.withOpacity(0.5))),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.search, color: AppColors.primary, size: 20),
                      
                      ..._searchTokens.map((token) => InputChip(
                        label: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: '${token["key"]}: ', style: const TextStyle(fontWeight: FontWeight.normal, color: AppColors.primary, fontSize: 13)),
                              TextSpan(text: token["value"], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                            ]
                          )
                        ),
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        deleteIconColor: AppColors.primary,
                        onDeleted: () {
                          setState(() => _searchTokens.remove(token));
                          _applyFilters();
                        },
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
                      )),
                      
                      SizedBox(
                        width: 180,
                        child: TextField(
                          focusNode: _searchFocus,
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search...',
                            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedSpeciality,
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() => _selectedSpeciality = newValue);
                                _applyFilters();
                              }
                            },
                            items: _preMadeSpecialities.map((String spec) {
                              return DropdownMenuItem<String>(value: spec, child: Text(spec == 'All' ? 'All Specialties' : spec));
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<TrainerSortOption>(
                            isExpanded: true,
                            value: _currentSort,
                            icon: const Icon(Icons.sort, size: 16),
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                            onChanged: (TrainerSortOption? newValue) {
                              if (newValue != null) {
                                setState(() => _currentSort = newValue);
                                _applyFilters();
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: TrainerSortOption.none, child: Text('Sort By')),
                              DropdownMenuItem(value: TrainerSortOption.rateAsc, child: Text('Rate: Low-High')),
                              DropdownMenuItem(value: TrainerSortOption.rateDesc, child: Text('Rate: High-Low')),
                              DropdownMenuItem(value: TrainerSortOption.expDesc, child: Text('Exp: Highest')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_filteredTrainers.length} Result${_filteredTrainers.length != 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    if (_searchTokens.isNotEmpty || _searchController.text.isNotEmpty || _selectedSpeciality != 'All')
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchTokens.clear();
                            _searchController.clear();
                            _selectedSpeciality = 'All';
                            _currentSort = TrainerSortOption.none;
                          });
                          _applyFilters();
                        },
                        child: const Text('Clear All', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
              ],
            ),
          ),

          // 🔥 STACK LAYOUT: Overlay floats safely over the list!
          Expanded(
            child: Stack(
              children: [
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                  onRefresh: _load,
                  child: _filteredTrainers.isEmpty
                      ? const Center(child: Text('No trainers match your criteria', style: TextStyle(color: AppColors.textMuted)))
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

                      final List<String> specs = specsStr.isNotEmpty
                          ? specsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                          : [];

                      return InkWell(
                        onTap: () => _viewProfile(context, t),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border.withOpacity(0.5)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    radius: 28,
                                    child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'T', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            if (t['experience_years'] != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                                                child: Text('${_formatExperience(t['experience_years'])} yrs exp', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                            if (t['experience_years'] != null && phone.isNotEmpty) const SizedBox(width: 8),
                                            if (phone.isNotEmpty) Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                          ]
                                        )
                                      ],
                                    ),
                                  ),
                                  if (hourlyRate != null)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('₹$hourlyRate', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18)),
                                        const Text('per hour', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                      ],
                                    ),
                                ],
                              ),
                              if (bio.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                              ],
                              if (specs.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8, runSpacing: 6,
                                  children: specs.take(3).map((s) => _PremiumChip(label: s, color: AppColors.primary)).toList(),
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: (isCurrent || hasOtherTrainer || isSent) ? null : () => _sendRequest(context, trainerId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isCurrent ? Colors.green : AppColors.primary,
                                    disabledBackgroundColor: Colors.grey.shade200,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: isCurrent || hasOtherTrainer || isSent ? 0 : 2,
                                  ),
                                  child: Text(
                                    isCurrent ? 'Current Trainer' : hasOtherTrainer ? 'Quit Current Trainer First' : isSent ? 'Request Sent' : 'Request as My Trainer',
                                    style: TextStyle(color: (isCurrent || hasOtherTrainer || isSent) ? AppColors.textMuted : Colors.white, fontWeight: FontWeight.bold),
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
                
                // 🔥 THE FIX: Using GestureDetector with HitTestBehavior so clicks register instantly without losing focus
                if (_searchFocus.hasFocus)
                  Positioned(
                    top: 8, left: 16, right: 16,
                    child: Builder(builder: (context) {
                      final content = _buildDiscordDropdownContent();
                      if (content is SizedBox) return content; // Don't draw shadow if empty
                      
                      return Material(
                        elevation: 12,
                        shadowColor: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.surface,
                        child: content,
                      );
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🔥 FIXED: Uses onPanDown so it registers immediately before the keyboard can close and destroy the widget
class _DiscordFilterTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DiscordFilterTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) => onTap(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const _ProfileStatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}

class _PremiumChip extends StatelessWidget {
  final String label;
  final Color color;
  const _PremiumChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}