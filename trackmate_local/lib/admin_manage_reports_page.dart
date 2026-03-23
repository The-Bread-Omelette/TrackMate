import 'package:flutter/material.dart';

// --- Data Models ---
class ChatMessage {
  final String sender;
  final String time;
  final String text;
  final bool isFlagged;

  ChatMessage({required this.sender, required this.time, required this.text, this.isFlagged = false});
}

class UserReport {
  final String type;
  final String reporterName;
  final String reporterAvatar;
  final String reporterId;
  final String trainerName;
  final String trainerAvatar;
  final String trainerId;
  final String description;
  final String date;
  String status; // 'Pending' or 'Resolved'
  final List<ChatMessage> chatHistory;

  UserReport({
    required this.type,
    required this.reporterName,
    required this.reporterAvatar,
    required this.reporterId,
    required this.trainerName,
    required this.trainerAvatar,
    required this.trainerId,
    required this.description,
    required this.date,
    required this.status,
    required this.chatHistory,
  });
}

class AdminManageReportsPage extends StatefulWidget {
  const AdminManageReportsPage({super.key});

  @override
  State<AdminManageReportsPage> createState() => _AdminManageReportsPageState();
}

class _AdminManageReportsPageState extends State<AdminManageReportsPage> {
  // --- Dummy Data ---
  final List<UserReport> reports = [
    UserReport(
      type: 'Inappropriate Language',
      reporterName: 'Sarah Johnson',
      reporterAvatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=150&q=80',
      reporterId: 'u1',
      trainerName: 'Marcus Johnson',
      trainerAvatar: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&q=80&w=150',
      trainerId: 't1',
      description: 'The trainer used unprofessional language and made me feel uncomfortable during our conversation.',
      date: '2/3/2026 at 12:00 AM',
      status: 'Pending',
      chatHistory: [],
    ),
    UserReport(
      type: 'Harassment',
      reporterName: 'Emily Parker',
      reporterAvatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=150&q=80',
      reporterId: 'u2',
      trainerName: 'Derek Thompson',
      trainerAvatar: 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?auto=format&fit=crop&q=80&w=150',
      trainerId: 't2',
      description: 'The trainer kept messaging me outside of scheduled sessions and made unwanted personal comments.',
      date: '2/4/2026 at 12:00 AM',
      status: 'Pending',
      chatHistory: [],
    ),
    UserReport(
      type: 'Spam/Solicitation',
      reporterName: 'Michael Torres',
      reporterAvatar: 'https://images.unsplash.com/photo-1506277886164-e25aa3f4ef7f?auto=format&fit=crop&w=150&q=80',
      reporterId: 'u3',
      trainerName: 'Sophia Rivera',
      trainerAvatar: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&q=80&w=150',
      trainerId: 't3',
      description: 'The trainer tried to sell me supplements and other products not related to the training service.',
      date: '2/1/2026 at 12:00 AM',
      status: 'Resolved',
      chatHistory: [
        ChatMessage(
          sender: 'Sophia Rivera',
          time: '03:00 PM',
          text: 'I have a great supplement line that can really boost your results!',
          isFlagged: true,
        ),
        ChatMessage(
          sender: 'Michael Torres',
          time: '03:10 PM',
          text: "I'm not interested in supplements right now.",
          isFlagged: false,
        ),
        ChatMessage(
          sender: 'Sophia Rivera',
          time: '03:15 PM',
          text: 'You should really consider it, I can give you a special discount.',
          isFlagged: true,
        ),
      ],
    ),
  ];

  void _resolveReport(int index) {
    setState(() {
      reports[index].status = 'Resolved';
    });
    Navigator.pop(context); // Close dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report marked as resolved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = reports.where((r) => r.status == 'Pending').length;
    final resolvedCount = reports.where((r) => r.status == 'Resolved').length;
    final totalCount = reports.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stats Row
          Row(
            children: [
              _buildStatCard('Pending', pendingCount.toString(), isAlert: true),
              const SizedBox(width: 12),
              _buildStatCard('Resolved', resolvedCount.toString()),
              const SizedBox(width: 12),
              _buildStatCard('Total', totalCount.toString()),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Reports List
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
                  child: Text('User Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reports.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _buildReportTile(reports[index], index);
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
  Widget _buildStatCard(String label, String value, {bool isAlert = false}) {
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
            Row(
              children: [
                if (isAlert) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                if (isAlert) const SizedBox(width: 4),
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // Helper for Report List Item
  Widget _buildReportTile(UserReport report, int index) {
    final isPending = report.status == 'Pending';
    
    return InkWell(
      onTap: () => _showReportDetails(report, index),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: isPending ? Colors.red : Colors.grey, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(report.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                      _buildStatusChip(report.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Reported by ${report.reporterName} against ${report.trainerName}', style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(report.description, style: const TextStyle(color: Colors.black87, fontSize: 12, height: 1.4)),
                  const SizedBox(height: 8),
                  Text(report.date, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for Status Chip
  Widget _buildStatusChip(String status) {
    final isPending = status == 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPending ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isPending ? Colors.red.shade400 : Colors.green,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- Popup Dialog ---
  void _showReportDetails(UserReport report, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isPending = report.status == 'Pending';
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Report Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.grey, size: 20),
                    )
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Red Warning Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(report.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                _buildStatusChip(report.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(report.description, style: const TextStyle(fontSize: 13, height: 1.4)),
                            const SizedBox(height: 12),
                            Text('Reported on ${report.date}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // User Info Row
                      Row(
                        children: [
                          Expanded(child: _buildUserCard('Reporter (User)', report.reporterName, report.reporterId, report.reporterAvatar)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildUserCard('Reported Trainer', report.trainerName, report.trainerId, report.trainerAvatar)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Chat History
                      if (report.chatHistory.isNotEmpty) ...[
                        const Row(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                            SizedBox(width: 8),
                            Text('Chat History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...report.chatHistory.map((msg) => _buildChatBubble(msg)),
                      ] else ...[
                        const Text('No chat history associated with this report.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
                      ],
                      const SizedBox(height: 24),

                      // Resolution Action
                      if (isPending)
                        ElevatedButton.icon(
                          onPressed: () => _resolveReport(index),
                          icon: const Icon(Icons.check, color: Colors.white, size: 18),
                          label: const Text('Resolve & Warn Trainer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          alignment: Alignment.center,
                          child: const Text('✓ Report Resolved - Trainer has been warned', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper for Reporter/Trainer Card inside Dialog
  Widget _buildUserCard(String role, String name, String id, String avatarUrl) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(radius: 14, backgroundImage: NetworkImage(avatarUrl)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('ID: $id', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // Helper for Chat Bubble inside Dialog
  Widget _buildChatBubble(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: msg.isFlagged ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: msg.isFlagged ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(msg.sender, style: TextStyle(color: const Color(0xFF427AFA), fontWeight: FontWeight.bold, fontSize: 12)),
              Text(msg.time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Text(msg.text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          if (msg.isFlagged) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                const SizedBox(width: 4),
                Text('Flagged message', style: TextStyle(color: Colors.red.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            )
          ]
        ],
      ),
    );
  }
}