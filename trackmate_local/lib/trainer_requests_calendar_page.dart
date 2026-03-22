import 'package:flutter/material.dart';

// --- Data Models ---
class ClientRequest {
  final String name;
  final String specialty;
  final String message;
  final String date;
  final String avatarUrl;

  ClientRequest({required this.name, required this.specialty, required this.message, required this.date, required this.avatarUrl});
}

class CalendarEvent {
  final String studentName;
  final String type; // 'Check In', 'Session', 'Milestone'
  final String date;
  final String time;
  final Color color;

  CalendarEvent({required this.studentName, required this.type, required this.date, required this.time, required this.color});
}

class TrainerRequestsCalendarPage extends StatefulWidget {
  const TrainerRequestsCalendarPage({super.key});

  @override
  State<TrainerRequestsCalendarPage> createState() => _TrainerRequestsCalendarPageState();
}

class _TrainerRequestsCalendarPageState extends State<TrainerRequestsCalendarPage> {
  // --- Dummy Data ---
  final List<ClientRequest> pendingRequests = [
    ClientRequest(
      name: 'Michael Torres',
      specialty: 'Weight Loss & Strength',
      message: "Hi! I'm looking for help with weight loss and building muscle. Can you take me on as a new student?",
      date: '2/3/2026',
      avatarUrl: 'https://images.unsplash.com/photo-1506277886164-e25aa3f4ef7f?auto=format&fit=crop&w=150&q=80',
    ),
    ClientRequest(
      name: 'Emily Parker',
      specialty: 'Marathon Training',
      message: "I'd like to work on marathon training and need a coach with running experience.",
      date: '2/4/2026',
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=150&q=80',
    ),
    ClientRequest(
      name: 'Daniel Lee',
      specialty: 'Nutrition & Fitness',
      message: "Looking for nutrition guidance and workout plans for busy professionals.",
      date: '2/4/2026',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=150&q=80',
    ),
  ];

  final List<CalendarEvent> upcomingEvents = [
    CalendarEvent(studentName: 'Sarah Johnson', type: 'Check In', date: '2/5/2026', time: '10:00 AM', color: const Color(0xFF427AFA)),
    CalendarEvent(studentName: 'Mike Chen', type: 'Session', date: '2/6/2026', time: '2:00 PM', color: const Color(0xFF00C853)),
    CalendarEvent(studentName: 'Emma Thompson', type: 'Milestone', date: '2/8/2026', time: 'All Day', color: const Color(0xFFAA00FF)),
    CalendarEvent(studentName: 'Jessica Martinez', type: 'Check In', date: '2/10/2026', time: '9:00 AM', color: const Color(0xFF427AFA)),
    CalendarEvent(studentName: 'David Kim', type: 'Session', date: '2/11/2026', time: '3:30 PM', color: const Color(0xFF00C853)),
  ];

  // Helper mapping for calendar markers (Date -> Color)
  final Map<int, Color> calendarMarkers = {
    5: const Color(0xFF427AFA),
    6: const Color(0xFF00C853),
    8: const Color(0xFFAA00FF),
    10: const Color(0xFF427AFA),
    11: const Color(0xFF00C853),
  };

  void _removeRequest(int index) {
    setState(() {
      pendingRequests.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Pending Requests Section
          _buildPendingRequestsCard(),
          const SizedBox(height: 24),
          
          // 2. Calendar Section
          _buildCalendarCard(),
          const SizedBox(height: 24),

          // 3. Upcoming Events Section
          _buildUpcomingEventsCard(),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildPendingRequestsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pending Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${pendingRequests.length} new requests', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                  child: Text('${pendingRequests.length}', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingRequests.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final request = pendingRequests[index];
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(backgroundImage: NetworkImage(request.avatarUrl), radius: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(request.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFEDF2FE), borderRadius: BorderRadius.circular(4)),
                                child: Text(request.specialty, style: const TextStyle(color: Color(0xFF427AFA), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(request.message, style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4)),
                    const SizedBox(height: 8),
                    Text('Requested ${request.date}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _removeRequest(index),
                            icon: const Icon(Icons.check, color: Colors.white, size: 16),
                            label: const Text('Accept', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _removeRequest(index),
                            icon: const Icon(Icons.close, color: Colors.red, size: 16),
                            label: const Text('Decline', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade100),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    // Days of week header
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('February 2026', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Icon(Icons.chevron_left, color: Colors.grey.shade600),
                  const SizedBox(width: 16),
                  Icon(Icons.chevron_right, color: Colors.grey.shade600),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          
          // Days Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: daysOfWeek.map((day) => Expanded(
              child: Text(day, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            )).toList(),
          ),
          const SizedBox(height: 12),

          // Custom Grid for exactly 28 days (4 weeks)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 28, // Feb 2026 has exactly 28 days starting on a Sunday!
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = day == 4; // Highlighted day from screenshot
              final markerColor = calendarMarkers[day];

              return Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEDF2FE) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? const Color(0xFF427AFA) : Colors.grey.shade200),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('$day', style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ),
                    if (markerColor != null)
                      Positioned(
                        bottom: 8, left: 8, right: 8,
                        child: Container(height: 3, decoration: BoxDecoration(color: markerColor, borderRadius: BorderRadius.circular(2))),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Legend
          Row(
            children: [
              _buildLegendItem(const Color(0xFF427AFA), 'Check-in'),
              const SizedBox(width: 16),
              _buildLegendItem(const Color(0xFF00C853), 'Training Session'),
              const SizedBox(width: 16),
              _buildLegendItem(const Color(0xFFAA00FF), 'Milestone'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        CircleAvatar(backgroundColor: color, radius: 4),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildUpcomingEventsCard() {
    return Container(
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
            child: Text('Upcoming Events', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: upcomingEvents.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = upcomingEvents[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: event.color, radius: 4),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(event.type, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(event.date, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                        Text(event.time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    )
                  ],
                ),
              );
            },
          )
        ],
      ),
    );
  }
}