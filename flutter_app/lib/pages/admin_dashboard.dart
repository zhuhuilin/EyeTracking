import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showAdminSettings,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsOverview(),
            const SizedBox(height: 24),
            _buildUserManagement(),
            const SizedBox(height: 24),
            _buildSystemConfiguration(),
            const SizedBox(height: 24),
            _buildDataAnalytics(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total Users', '1,247', Icons.people),
                _buildStatCard('Active Tests', '23', Icons.visibility),
                _buildStatCard('Storage Used', '2.3 GB', Icons.storage),
                _buildStatCard('Accuracy Avg', '78.5%', Icons.trending_up),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.purple),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildUserManagement() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'User Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addUser,
                  icon: const Icon(Icons.add),
                  label: const Text('Add User'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView(
                children: [
                  _buildUserItem('John Doe', 'john@example.com', 'User', true),
                  _buildUserItem(
                    'Jane Smith',
                    'jane@example.com',
                    'User',
                    false,
                  ),
                  _buildUserItem(
                    'Admin User',
                    'admin@example.com',
                    'Admin',
                    true,
                  ),
                  _buildUserItem('Test User', 'test@example.com', 'User', true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(String name, String email, String role, bool active) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.purple[100],
        child: Text(name[0]),
      ),
      title: Text(name),
      subtitle: Text('$email • $role'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle : Icons.remove_circle,
            color: active ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit User')),
              const PopupMenuItem(
                value: 'reset',
                child: Text('Reset Password'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete User')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemConfiguration() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Cloud Storage'),
              subtitle: const Text('Store data in cloud instead of local'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: const Text('Enable Analytics'),
              subtitle: const Text('Collect usage statistics and analytics'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: const Text('Auto Backup'),
              subtitle: const Text('Automatically backup data daily'),
              value: false,
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showStorageMigration,
              child: const Text('Manage Data Migration'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataAnalytics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportData,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Data'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _viewReports,
                    icon: const Icon(Icons.analytics),
                    label: const Text('View Reports'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Recent Activity',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildActivityItem('User registration', '2 minutes ago'),
            _buildActivityItem('Test completed', '5 minutes ago'),
            _buildActivityItem('Data backup', '1 hour ago'),
            _buildActivityItem('System update', '2 hours ago'),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String activity, String time) {
    return ListTile(
      leading: const Icon(Icons.circle, size: 8, color: Colors.green),
      title: Text(activity),
      trailing: Text(time, style: const TextStyle(color: Colors.grey)),
      dense: true,
    );
  }

  void _showAdminSettings() {
    // Show admin settings dialog
  }

  void _logout(BuildContext context) {
    Provider.of<AppState>(context, listen: false).setUser(null);
  }

  void _addUser() {
    // Show add user dialog
  }

  void _showStorageMigration() {
    // Show storage migration dialog
  }

  void _exportData() {
    // Export data functionality
  }

  void _viewReports() {
    // View reports functionality
  }
}
