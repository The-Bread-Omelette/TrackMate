import 'package:flutter/material.dart';
import 'trainer_dashboard_page.dart'; // To access the Student model

class StudentDetailPage extends StatelessWidget {
  final Student student;

  const StudentDetailPage({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    // This page needs its own Scaffold because it's pushed OVER the MainLayout
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(student.name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Stats Row
            Row(
              children: [
                _buildTopStat('Adherence', '${(student.progress * 100).toInt()}%'),
                const SizedBox(width: 12),
                _buildTopStat('Workouts', '47'),
                const SizedBox(width: 12),
                _buildTopStat('Streak', '12 days'),
              ],
            ),
            const SizedBox(height: 24),

            // Coaching Notes Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Color(0xFF427AFA), size: 18),
                      SizedBox(width: 8),
                      Text('Coaching Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Text Field
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add a coaching note or feedback...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF427AFA))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Send Button
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.send, size: 14, color: Colors.white),
                    label: const Text('Send Note', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF427AFA),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Previous Notes list
                  _buildNoteItem('Coach Marcus', '2/1/2026 at 12:00 AM', 'Great progress this week! Keep up the excellent work on your strength training.'),
                  const SizedBox(height: 12),
                  _buildNoteItem('Coach Marcus', '1/28/2026 at 12:00 AM', 'Remember to focus on form over weight. Let\'s work on proper squat technique next session.'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tabs and History Section
            DefaultTabController(
              length: 3,
              initialIndex: 2, // Default to History tab to match screenshot
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: const Color(0xFF427AFA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(icon: Icon(Icons.restaurant, size: 18), text: 'Nutrition Logs'),
                          Tab(icon: Icon(Icons.fitness_center, size: 18), text: 'Workouts'),
                          Tab(icon: Icon(Icons.calendar_today, size: 18), text: 'History'),
                        ],
                      ),
                    ),
                    
                    // Tab Content (Setting a fixed height so it scrolls nicely)
                    SizedBox(
                      height: 400,
                      child: TabBarView(
                        children: [
                          const Center(child: Text('Nutrition data...')),
                          const Center(child: Text('Workout data...')),
                          // History Tab content
                          ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildHistoryItem(Icons.fitness_center, Colors.blue, 'Completed Upper Body Strength', '2 hours ago'),
                              _buildHistoryItem(Icons.restaurant, Colors.green, 'Logged dinner - 680 calories', '5 hours ago'),
                              _buildHistoryItem(Icons.trending_up, Colors.purple, 'Achieved 12-day streak!', '1 day ago'),
                              _buildHistoryItem(Icons.fitness_center, Colors.blue, 'Completed HIIT Cardio', '1 day ago'),
                              _buildHistoryItem(Icons.restaurant, Colors.green, 'Met daily protein goal', '1 day ago'),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Top Stat Cards
  Widget _buildTopStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // Individual Note Item
  Widget _buildNoteItem(String author, String date, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF2FE), // Light blue background
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(author, style: const TextStyle(color: Color(0xFF427AFA), fontSize: 12, fontWeight: FontWeight.bold)),
              Text(date, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  // History List Item
  Widget _buildHistoryItem(IconData icon, Color color, String title, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}