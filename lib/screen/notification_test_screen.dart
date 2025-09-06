import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../service/notification_service.dart';
import '../service/local_notification_service.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({Key? key}) : super(key: key);

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  String? _fcmToken;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getFCMToken();
  }

  Future<void> _getFCMToken() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final token = await NotificationService.getToken();
      setState(() {
        _fcmToken = token;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting FCM token: $e')),
      );
    }
  }

  Future<void> _copyTokenToClipboard() async {
    if (_fcmToken != null) {
      await Clipboard.setData(ClipboardData(text: _fcmToken!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FCM Token copied to clipboard!')),
      );
    }
  }

  Future<void> _subscribeToTopic() async {
    try {
      await NotificationService.subscribeToTopic('vocabulary_updates');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscribed to vocabulary_updates topic!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error subscribing to topic: $e')),
      );
    }
  }

  Future<void> _unsubscribeFromTopic() async {
    try {
      await NotificationService.unsubscribeFromTopic('vocabulary_updates');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsubscribed from vocabulary_updates topic!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unsubscribing from topic: $e')),
      );
    }
  }

  Future<void> _showLocalNotification() async {
    try {
      await LocalNotificationService.showNotification(
        id: 1,
        title: 'Test Local Notification',
        body: 'This is a test local notification from your vocabulary app!',
        payload: 'test_payload',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local notification sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending local notification: $e')),
      );
    }
  }

  Future<void> _scheduleNotification() async {
    try {
      final scheduledTime = DateTime.now().add(const Duration(seconds: 10));
      await LocalNotificationService.scheduleNotification(
        id: 2,
        title: 'Scheduled Notification',
        body: 'This notification was scheduled 10 seconds ago!',
        scheduledDate: scheduledTime,
        payload: 'scheduled_payload',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification scheduled for 10 seconds from now!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling notification: $e')),
      );
    }
  }

  Future<void> _showVocabularyReminder() async {
    try {
      await LocalNotificationService.showVocabularyReminder(
        word: 'Serendipity',
        meaning: 'A pleasant surprise',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vocabulary reminder sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending vocabulary reminder: $e')),
      );
    }
  }

  Future<void> _requestLocalNotificationPermissions() async {
    try {
      final granted = await LocalNotificationService.requestPermissions();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted 
            ? 'Local notification permissions granted!' 
            : 'Local notification permissions denied'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error requesting permissions: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notifications'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM Token',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_fcmToken != null)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _fcmToken!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _copyTokenToClipboard,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy Token'),
                          ),
                        ],
                      )
                    else
                      const Text('Failed to get FCM token'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Topic Subscription',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Subscribe to receive vocabulary updates and learning reminders.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _subscribeToTopic,
                            child: const Text('Subscribe'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _unsubscribeFromTopic,
                            child: const Text('Unsubscribe'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Local Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Test local notifications that work offline.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _requestLocalNotificationPermissions,
                          child: const Text('Request Permissions'),
                        ),
                        ElevatedButton(
                          onPressed: _showLocalNotification,
                          child: const Text('Show Now'),
                        ),
                        ElevatedButton(
                          onPressed: _scheduleNotification,
                          child: const Text('Schedule (10s)'),
                        ),
                        ElevatedButton(
                          onPressed: _showVocabularyReminder,
                          child: const Text('Vocabulary Reminder'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to Test',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Firebase Cloud Messaging:\n'
                      '1. Copy the FCM token above\n'
                      '2. Go to Firebase Console > Cloud Messaging\n'
                      '3. Create a new campaign or send a test message\n'
                      '4. Paste the token to send to this device\n\n'
                      'Local Notifications:\n'
                      '1. Request permissions first\n'
                      '2. Test immediate notifications\n'
                      '3. Test scheduled notifications\n'
                      '4. Test vocabulary-specific notifications',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
