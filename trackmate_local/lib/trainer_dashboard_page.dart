import 'package:flutter/material.dart';
import 'student_detail_page.dart'; // We will create this next

// --- Data Model ---
class Student {
  final String name;
  final String avatarUrl;
  final String lastActive;
  final String status; // 'Excellent', 'On Track', 'Needs Attention'
  final double progress; // 0.0 to 1.0
  final Color statusColor;

  Student({
    required this.name,
    required this.avatarUrl,
    required this.lastActive,
    required this.status,
    required this.progress,
    required this.statusColor,
  });
}

class TrainerDashboardPage extends StatelessWidget {
  TrainerDashboardPage({super.key});

  // --- Dummy Data matching your screenshot ---
  final List<Student> students = [
    Student(
      name: 'Sarah Johnson',
      avatarUrl:
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=150&q=80',
      lastActive: '2 hours ago',
      status: 'Excellent',
      progress: 0.95,
      statusColor: Colors.green,
    ),
    Student(
      name: 'Mike Chen',
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=150&q=80',
      lastActive: '5 hours ago',
      status: 'On Track',
      progress: 0.78,
      statusColor: const Color(0xFF427AFA),
    ),
    Student(
      name: 'Jessica Martinez',
      avatarUrl:
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=150&q=80',
      lastActive: '2 days ago',
      status: 'Needs Attention',
      progress: 0.45,
      statusColor: Colors.red.shade400,
    ),
    Student(
      name: 'David Kim',
      avatarUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80',
      lastActive: '1 day ago',
      status: 'On Track',
      progress: 0.82,
      statusColor: Colors.green,
    ),
    Student(
      name: 'Emma Thompson',
      avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
      lastActive: '4 hours ago',
      status: 'Excellent',
      progress: 0.92,
      statusColor: Colors.green,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. AI Weekly Insights Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B42FA), Color(0xFFB042FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'AI Weekly Insights',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInsightText(
                  '3 students',
                  ' are exceeding their weekly goals with 90%+ adherence rates.',
                ),
                const SizedBox(height: 8),
                _buildInsightText(
                  '2 students',
                  " haven't logged activity in over 48 hours and may need check-ins.",
                ),
                const SizedBox(height: 8),
                const Text(
                  'Overall roster performance is up 12% compared to last week.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment
                      .start, // Keeps the icon at the top if text wraps to two lines
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.yellow.shade300,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      // <--- WRAP THE TEXT IN EXPANDED
                      child: Text(
                        'Jessica Martinez and Alex Rodriguez need immediate attention',
                        style: TextStyle(
                          color: Colors.yellow.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Stats Row
          Row(
            children: [
              _buildStatCard(Icons.people_outline, 'Total Students', '8'),
              const SizedBox(width: 12),
              _buildStatCard(
                Icons.trending_up,
                'Avg Adherence',
                '76%',
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                Icons.error_outline,
                'Need Attention',
                '2',
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 3. Active Students List
          const Text(
            'Active Students',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap:
                  true, // Needed because it's inside a SingleChildScrollView
              physics: const NeverScrollableScrollPhysics(),
              itemCount: students.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                return _buildStudentTile(context, students[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper for bolding parts of the insight text
  Widget _buildInsightText(String boldPart, String normalPart) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        children: [
          TextSpan(
            text: boldPart,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: normalPart),
        ],
      ),
    );
  }

  // Helper for the 3 small stat cards
  Widget _buildStatCard(
    IconData icon,
    String title,
    String value, {
    Color color = Colors.black54,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for the individual student rows
  Widget _buildStudentTile(BuildContext context, Student student) {
    return InkWell(
      onTap: () {
        // Navigate to the detail page, passing the specific student data!
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentDetailPage(student: student),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(student.avatarUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Last active: ${student.lastActive}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: student.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    student.status,
                    style: TextStyle(
                      color: student.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: student.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        student.statusColor,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(student.progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
