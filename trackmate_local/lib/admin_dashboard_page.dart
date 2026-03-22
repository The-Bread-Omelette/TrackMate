import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Welcome Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFA055FA), Color(0xFF427AFA)], // Purple to Blue
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Manage users, trainers, and system settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Stats Grid
          // Using a GridView so it automatically wraps nicely on mobile vs tablet
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2, // 4 cols on web/tablet, 2 on mobile
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard(
                icon: Icons.people_alt_outlined,
                iconColor: const Color(0xFF427AFA), // Blue
                title: 'Total Users',
                value: '2,847',
                subtitle: '↑ 12% from last month',
                subtitleColor: Colors.green,
              ),
              _buildStatCard(
                icon: Icons.manage_accounts_outlined,
                iconColor: const Color(0xFFA055FA), // Purple
                title: 'Active Trainers',
                value: '124',
                subtitle: '↑ 8% from last month',
                subtitleColor: Colors.green,
              ),
              _buildStatCard(
                icon: Icons.show_chart,
                iconColor: Colors.green,
                title: 'Active Sessions',
                value: '1,523',
                subtitle: 'Today',
                subtitleColor: const Color(0xFF427AFA),
              ),
              _buildStatCard(
                icon: Icons.trending_up,
                iconColor: Colors.orange,
                title: 'Growth Rate',
                value: '23%',
                subtitle: 'This quarter',
                subtitleColor: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper widget for the stat cards
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}