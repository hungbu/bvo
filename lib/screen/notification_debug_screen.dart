import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/notification_fix_service.dart';
import '../service/notification_manager.dart';
import '../repository/user_progress_repository.dart';

class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({Key? key}) : super(key: key);

  @override
  State<NotificationDebugScreen> createState() => _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  String _lastAction = '';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await NotificationFixService.getNotificationStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _stats = {'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _fixNotifications() async {
    setState(() {
      _isLoading = true;
      _lastAction = 'Fixing notifications...';
    });

    try {
      await NotificationFixService.fixNotificationIssues();
      await NotificationFixService.markFixPerformed();
      
      setState(() => _lastAction = '✅ Notifications fixed successfully!');
      
      // Reload stats
      await _loadStats();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔧 Notification issues fixed!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _lastAction = '❌ Error fixing notifications: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testNotifications() async {
    setState(() {
      _isLoading = true;
      _lastAction = 'Testing notifications...';
    });

    try {
      final healthy = await NotificationFixService.checkNotificationHealth();
      
      setState(() => _lastAction = healthy 
          ? '✅ Notifications are working!' 
          : '⚠️ Notification issues detected');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(healthy ? '✅ Test passed!' : '⚠️ Test failed!'),
          backgroundColor: healthy ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      setState(() => _lastAction = '❌ Test failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleTestReminder() async {
    setState(() {
      _isLoading = true;
      _lastAction = 'Scheduling test reminder...';
    });

    try {
      final manager = NotificationManager();
      await manager.scheduleDailyReminders();
      
      setState(() => _lastAction = '📅 Test reminders scheduled!');
      await _loadStats();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📅 Test reminders scheduled!'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      setState(() => _lastAction = '❌ Error scheduling: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            
            const SizedBox(height: 16),
            
            // Stats
            _buildStatsSection(),
            
            const SizedBox(height: 16),
            
            // Actions
            _buildActionsSection(),
            
            const SizedBox(height: 16),
            
            // Last Action
            if (_lastAction.isNotEmpty) _buildLastActionSection(),
            
            // Extra space at bottom to prevent overflow
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔧 Notification Debug Tool',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Use this tool to diagnose and fix notification issues.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Notification Statistics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isLoading ? null : _loadStats,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            if (_stats.isEmpty)
              const Text('No stats available')
            else
              ..._stats.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.value.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Debug Actions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Fix Notifications Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _fixNotifications,
                icon: const Icon(Icons.healing),
                label: const Text('Fix All Notification Issues'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Test Notifications Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _testNotifications,
                icon: const Icon(Icons.check_circle),
                label: const Text('Test Notification System'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Schedule Test Reminder Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _scheduleTestReminder,
                icon: const Icon(Icons.schedule),
                label: const Text('Schedule Test Reminders'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Debug Word Count Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _debugWordCount,
                icon: const Icon(Icons.analytics),
                label: const Text('Debug Word Count'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastActionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last Action:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  _lastAction,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _lastAction));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy to clipboard',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _debugWordCount() async {
    setState(() {
      _isLoading = true;
      _lastAction = 'Debugging word count...';
    });

    try {
      final progressRepo = UserProgressRepository();
      final debugInfo = await progressRepo.debugTodayWordCount();
      
      setState(() => _lastAction = '📊 Word Count Debug: ${debugInfo.toString()}');
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('📊 Word Count Debug'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: debugInfo.entries.map((entry) => 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(entry.value.toString()),
                        ),
                      ],
                    ),
                  ),
                ).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: debugInfo.toString()));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debug info copied!')),
                  );
                },
                child: const Text('Copy'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      setState(() => _lastAction = '❌ Debug failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
