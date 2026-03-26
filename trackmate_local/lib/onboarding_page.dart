import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/widgets/main_layout.dart'; // Correct relative path based on your tree

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;
  final Dio _dio = sl<Dio>();

  // Data fields matching FastAPI ProfileUpdateRequest
  String _gender = 'male'; 
  DateTime? _dob = DateTime(1995, 1, 1); // Defaulted so you don't get blocked
  final TextEditingController _heightCtrl = TextEditingController(text: '170');
  final TextEditingController _weightCtrl = TextEditingController(text: '70');
  final TextEditingController _stepGoalCtrl = TextEditingController(text: '10000');
  final TextEditingController _calorieGoalCtrl = TextEditingController(text: '2000');
  String _activityLevel = 'moderately_active';

  // Mappings for the UI Dropdowns to Backend Enums
  final Map<String, String> _genderOptions = {
    'Male': 'male',
    'Female': 'female',
    'Other': 'other',
    'Prefer not to say': 'prefer_not_to_say'
  };

  final Map<String, String> _activityOptions = {
    'Sedentary (Little/No Exercise)': 'sedentary',
    'Lightly Active (1-3 days/week)': 'lightly_active',
    'Moderately Active (3-5 days/week)': 'moderately_active',
    'Very Active (6-7 days/week)': 'very_active',
    'Extra Active (Physical Job)': 'extra_active',
  };

  @override
  void dispose() {
    _pageController.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _stepGoalCtrl.dispose();
    _calorieGoalCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    final height = double.tryParse(_heightCtrl.text) ?? 0;
    final weight = double.tryParse(_weightCtrl.text) ?? 0;
    
    if (height < 50 || height > 300 || weight < 20 || weight > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter realistic height and weight values.")));
      return;
    }

    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select your Date of Birth.")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // API Call matching backend schema
      await _dio.put(
        ApiConstants.profile, // Assuming this is "/profile/me"
        data: {
          'gender': _gender,
          'date_of_birth': _dob?.toIso8601String(),
          'height_cm': height,
          'weight_kg': weight,
          'daily_step_goal': int.tryParse(_stepGoalCtrl.text) ?? 10000,
          'daily_calorie_goal': int.tryParse(_calorieGoalCtrl.text) ?? 2000,
          'activity_level': _activityLevel,
        }
      );

      // Success! Navigate to Main Layout
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Setup Complete! Ready to track.")));
      }

    } on DioException catch (e) {
      // FORCE POP-UP FOR API ERRORS
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Backend Error 🚨'),
            content: Text('Status: ${e.response?.statusCode}\n\nData: ${e.response?.data}\n\nMessage: ${e.message}'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      // FORCE POP-UP FOR APP/CORS ERRORS
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('App Error 🚨'),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submitProfile();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center( 
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Progress Bar Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TRACKMATE',
                          style: TextStyle(
                              color: Color(0xFF427AFA),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: (_currentPage + 1) / 3,
                        backgroundColor: Colors.grey.shade200,
                        valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF427AFA)),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text('Step ${_currentPage + 1} of 3',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                // Swipeable Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    children: [
                      _buildStepOne(),
                      _buildStepTwo(),
                      _buildStepThree(),
                    ],
                  ),
                ),

                // Navigation Buttons
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _currentPage == 0 || _isSaving ? null : _prevPage,
                        icon: const Icon(Icons.chevron_left, color: Colors.grey),
                        label: const Text('Back',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 140, // Strict constraint to prevent Web crashes
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF427AFA),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSaving 
                            ? const SizedBox(
                                height: 20, width: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                              )
                            : Text(_currentPage == 2 ? 'Complete' : 'Next >',
                                style: const TextStyle(color: Colors.white)),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- STEP 1: Basic Info ---
  Widget _buildStepOne() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Let's get started",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Tell us about yourself",
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),

          // Gender Dropdown
          const Text('Gender',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _gender,
                isExpanded: true,
                items: _genderOptions.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.value,
                    child: Text(entry.key),
                  );
                }).toList(),
                onChanged: (newValue) => setState(() => _gender = newValue!),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Date of Birth Selector
          const Text('Date of Birth',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dob ?? DateTime(1995),
                firstDate: DateTime(1940),
                lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
              );
              if (picked != null) setState(() => _dob = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : 'Select Date',
                    style: TextStyle(color: _dob != null ? Colors.black87 : Colors.grey.shade600, fontSize: 16),
                  ),
                  const Icon(Icons.calendar_today, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: Biometrics ---
  Widget _buildStepTwo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Your measurements",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Used to calculate your daily calorie needs",
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),

          // Height Field
          const Text('Height (cm)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _heightCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              hintText: 'e.g. 175',
            ),
          ),
          const SizedBox(height: 24),

          // Weight Field
          const Text('Weight (kg)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _weightCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              hintText: 'e.g. 70',
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 3: Goals & Activity ---
  Widget _buildStepThree() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Set your goals",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("We'll track your progress towards these metrics",
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),

          // Activity Level Dropdown
          const Text('Activity Level',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _activityLevel,
                isExpanded: true,
                items: _activityOptions.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.value,
                    child: Text(entry.key, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (newValue) => setState(() => _activityLevel = newValue!),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Steps Field
          const Text('Daily Step Goal',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _stepGoalCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),

          // Calorie Field
          const Text('Daily Calorie Goal',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _calorieGoalCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}