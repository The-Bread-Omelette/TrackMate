import 'package:flutter/material.dart';

// --- Data Model ---
class TrainerApplication {
  final String name;
  final String email;
  final String phone;
  final String imageUrl;
  final List<String> specialties;
  final List<String> certifications;
  final String experience;
  final String about;
  final int hourlyRate;
  final String date;
  String status; // 'Pending', 'Approved', or 'Rejected'

  TrainerApplication({
    required this.name,
    required this.email,
    required this.phone,
    required this.imageUrl,
    required this.specialties,
    required this.certifications,
    required this.experience,
    required this.about,
    required this.hourlyRate,
    required this.date,
    required this.status,
  });
}

class AdminManageTrainersPage extends StatefulWidget {
  const AdminManageTrainersPage({super.key});

  @override
  State<AdminManageTrainersPage> createState() => _AdminManageTrainersPageState();
}

class _AdminManageTrainersPageState extends State<AdminManageTrainersPage> {
  // --- Dummy Data ---
  final List<TrainerApplication> applications = [
    TrainerApplication(
      name: 'Marcus Johnson',
      email: 'marcus.j@email.com',
      phone: '+1 (555) 123-4567',
      imageUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&q=80&w=400',
      specialties: ['Strength Training', 'HIIT', 'Bodybuilding'],
      certifications: ['NASM-CPT', 'CrossFit Level 1'],
      experience: '10 years of experience',
      about: 'Dedicated strength coach helping clients build muscle and increase overall power output.',
      hourlyRate: 85,
      date: '2/1/2026',
      status: 'Pending',
    ),
    TrainerApplication(
      name: 'Sophia Rivera',
      email: 'sophia.r@email.com',
      phone: '+1 (555) 234-5678',
      imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&q=80&w=400',
      specialties: ['Weight Loss', 'Nutrition', 'Cardio'],
      certifications: ['ACE-CPT', 'Certified Nutritionist', 'Behavioral Change Specialist'],
      experience: '8 years of experience',
      about: 'Results-driven trainer focusing on holistic wellness. I combine nutrition coaching with personalized training to help clients lose weight and develop healthier habits for life.',
      hourlyRate: 95,
      date: '2/2/2026',
      status: 'Pending',
    ),
    TrainerApplication(
      name: 'Lily Anderson',
      email: 'lily.a@email.com',
      phone: '+1 (555) 345-6789',
      imageUrl: 'https://images.unsplash.com/photo-1518611012118-696072aa579a?auto=format&fit=crop&q=80&w=400',
      specialties: ['Yoga', 'Meditation', 'Flexibility'],
      certifications: ['RYT 500', 'Mindfulness Coach'],
      experience: '6 years of experience',
      about: 'Focused on mobility, flexibility, and mind-body connection through advanced yoga practices.',
      hourlyRate: 70,
      date: '2/3/2026',
      status: 'Pending',
    ),
    TrainerApplication(
      name: 'Derek Thompson',
      email: 'derek.t@email.com',
      phone: '+1 (555) 456-7890',
      imageUrl: 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?auto=format&fit=crop&q=80&w=400',
      specialties: ['CrossFit', 'Olympic Lifting', 'Conditioning'],
      certifications: ['CSCS', 'USA Weightlifting Level 2'],
      experience: '12 years of experience',
      about: 'Former athlete specializing in high-intensity conditioning and olympic lifts.',
      hourlyRate: 90,
      date: '2/4/2026',
      status: 'Approved',
    ),
  ];

  // Logic to update status
  void _updateStatus(int index, String newStatus) {
    setState(() {
      applications[index].status = newStatus;
    });
    Navigator.pop(context); // Close the dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Application $newStatus')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically calculate stats based on the current list
    final pendingCount = applications.where((app) => app.status == 'Pending').length;
    final approvedCount = applications.where((app) => app.status == 'Approved').length;
    final totalCount = applications.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Stats Row
          Row(
            children: [
              _buildStatCard('Pending', pendingCount.toString()),
              const SizedBox(width: 12),
              _buildStatCard('Approved', approvedCount.toString()),
              const SizedBox(width: 12),
              _buildStatCard('Total', totalCount.toString()),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Applications List
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('Trainer Applications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: applications.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _buildApplicationTile(applications[index], index);
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Helper for Top Stats
  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // Helper for List Item
  Widget _buildApplicationTile(TrainerApplication app, int index) {
    final isPending = app.status == 'Pending';

    return InkWell(
      onTap: () => _showApplicationDetails(app, index),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(app.imageUrl),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(app.email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: app.specialties.map((s) => _buildChip(s, isBlue: true)).toList(),
                  )
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusChip(app.status),
                const SizedBox(height: 12),
                Text(app.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Helper for Status Chip
  Widget _buildStatusChip(String status) {
    final isPending = status == 'Pending';
    final isApproved = status == 'Approved';
    
    Color bgColor = Colors.grey.shade100;
    Color textColor = Colors.grey;

    if (isPending) {
      bgColor = Colors.amber.shade50;
      textColor = Colors.amber.shade700;
    } else if (isApproved) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green;
    } else if (status == 'Rejected') {
      bgColor = Colors.red.shade50;
      textColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Reusable Blue Chip
  Widget _buildChip(String label, {bool isBlue = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isBlue ? const Color(0xFFEDF2FE) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isBlue ? const Color(0xFF427AFA) : Colors.black54,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // --- Popup Dialog ---
  void _showApplicationDetails(TrainerApplication app, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Image
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        app.imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 12, left: 12,
                      child: _buildStatusChip(app.status),
                    ),
                    Positioned(
                      top: 12, right: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 18, color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      
                      // Contact Info
                      Row(children: [
                        const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(app.email, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(app.phone, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(app.experience, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      ]),
                      
                      const SizedBox(height: 24),
                      const Text('About', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(app.about, style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.5)),
                      
                      const SizedBox(height: 24),
                      const Text('Specializations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: app.specialties.map((s) => _buildChip(s, isBlue: true)).toList(),
                      ),

                      const SizedBox(height: 24),
                      const Text('Certifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      ...app.certifications.map((cert) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Color(0xFF427AFA), fontWeight: FontWeight.bold, fontSize: 16)),
                            Expanded(child: Text(cert, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                          ],
                        ),
                      )),

                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Requested Hourly Rate', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('\$${app.hourlyRate}/hour', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Action Buttons (Only show if pending)
                      if (app.status == 'Pending')
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateStatus(index, 'Approved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C853), // Green
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Approve Application', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _updateStatus(index, 'Rejected'),
                                icon: const Icon(Icons.close, color: Colors.red, size: 16),
                                label: const Text('Reject', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: Colors.red.shade200),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}