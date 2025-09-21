import 'package:flutter/material.dart';
import 'package:bvo/service/difficult_words_service.dart';
import 'package:bvo/service/vocabulary_reminder_service.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final DifficultWordsService _difficultWordsService = DifficultWordsService();
  final VocabularyReminderService _reminderService = VocabularyReminderService();
  
  ReminderSettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await _difficultWordsService.getReminderSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _difficultWordsService.updateReminderSettings(_settings!);
      
      // Cập nhật lịch nhắc nhở
      if (_settings!.isEnabled) {
        final hasPermission = await _reminderService.checkNotificationPermission();
        if (hasPermission) {
          await _reminderService.scheduleVocabularyReminders();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã lưu cài đặt và lên lịch nhắc nhở!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng cấp quyền thông báo để sử dụng tính năng nhắc nhở.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await _reminderService.cancelAllReminders();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tắt nhắc nhở từ vựng.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu cài đặt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt nhắc nhở'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && _settings != null)
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Lưu',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _settings == null
              ? const Center(child: Text('Không thể tải cài đặt'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMainToggle(),
                      const SizedBox(height: 24),
                      if (_settings!.isEnabled) ...[
                        _buildTimeSettings(),
                        const SizedBox(height: 24),
                        _buildContentSettings(),
                        const SizedBox(height: 24),
                        _buildPreview(),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildMainToggle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Nhắc nhở từ vựng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhận thông báo nhắc nhở ôn tập từ vựng khó 3 lần mỗi ngày',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Bật nhắc nhở'),
              subtitle: Text(_settings!.isEnabled ? 'Đang bật' : 'Đang tắt'),
              value: _settings!.isEnabled,
              onChanged: (value) {
                setState(() {
                  _settings = ReminderSettings(
                    isEnabled: value,
                    morningTime: _settings!.morningTime,
                    afternoonTime: _settings!.afternoonTime,
                    eveningTime: _settings!.eveningTime,
                    wordsPerReminder: _settings!.wordsPerReminder,
                    onlyDifficultWords: _settings!.onlyDifficultWords,
                    minimumErrorRate: _settings!.minimumErrorRate,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Thời gian nhắc nhở',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimePicker('Buổi sáng', _settings!.morningTime, (time) {
              setState(() {
                _settings = ReminderSettings(
                  isEnabled: _settings!.isEnabled,
                  morningTime: time,
                  afternoonTime: _settings!.afternoonTime,
                  eveningTime: _settings!.eveningTime,
                  wordsPerReminder: _settings!.wordsPerReminder,
                  onlyDifficultWords: _settings!.onlyDifficultWords,
                  minimumErrorRate: _settings!.minimumErrorRate,
                );
              });
            }),
            _buildTimePicker('Buổi trưa', _settings!.afternoonTime, (time) {
              setState(() {
                _settings = ReminderSettings(
                  isEnabled: _settings!.isEnabled,
                  morningTime: _settings!.morningTime,
                  afternoonTime: time,
                  eveningTime: _settings!.eveningTime,
                  wordsPerReminder: _settings!.wordsPerReminder,
                  onlyDifficultWords: _settings!.onlyDifficultWords,
                  minimumErrorRate: _settings!.minimumErrorRate,
                );
              });
            }),
            _buildTimePicker('Buổi tối', _settings!.eveningTime, (time) {
              setState(() {
                _settings = ReminderSettings(
                  isEnabled: _settings!.isEnabled,
                  morningTime: _settings!.morningTime,
                  afternoonTime: _settings!.afternoonTime,
                  eveningTime: time,
                  wordsPerReminder: _settings!.wordsPerReminder,
                  onlyDifficultWords: _settings!.onlyDifficultWords,
                  minimumErrorRate: _settings!.minimumErrorRate,
                );
              });
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, String currentTime, Function(String) onTimeChanged) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentTime,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final timeParts = currentTime.split(':');
              final initialTime = TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              );
              
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: initialTime,
              );
              
              if (pickedTime != null) {
                final formattedTime = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                onTimeChanged(formattedTime);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContentSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Nội dung nhắc nhở',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Số từ mỗi lần nhắc'),
              subtitle: Text('${_settings!.wordsPerReminder} từ'),
              trailing: SizedBox(
                width: 100,
                child: Slider(
                  value: _settings!.wordsPerReminder.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: _settings!.wordsPerReminder.toString(),
                  onChanged: (value) {
                    setState(() {
                      _settings = ReminderSettings(
                        isEnabled: _settings!.isEnabled,
                        morningTime: _settings!.morningTime,
                        afternoonTime: _settings!.afternoonTime,
                        eveningTime: _settings!.eveningTime,
                        wordsPerReminder: value.round(),
                        onlyDifficultWords: _settings!.onlyDifficultWords,
                        minimumErrorRate: _settings!.minimumErrorRate,
                      );
                    });
                  },
                ),
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Tỷ lệ sai tối thiểu'),
              subtitle: Text('${(_settings!.minimumErrorRate * 100).toStringAsFixed(0)}% - Chỉ nhắc từ có tỷ lệ sai >= mức này'),
              trailing: SizedBox(
                width: 100,
                child: Slider(
                  value: _settings!.minimumErrorRate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '${(_settings!.minimumErrorRate * 100).toStringAsFixed(0)}%',
                  onChanged: (value) {
                    setState(() {
                      _settings = ReminderSettings(
                        isEnabled: _settings!.isEnabled,
                        morningTime: _settings!.morningTime,
                        afternoonTime: _settings!.afternoonTime,
                        eveningTime: _settings!.eveningTime,
                        wordsPerReminder: _settings!.wordsPerReminder,
                        onlyDifficultWords: _settings!.onlyDifficultWords,
                        minimumErrorRate: value,
                      );
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Xem trước thông báo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
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
                  Row(
                    children: [
                      Icon(Icons.notifications, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      const Text(
                        'Ôn từ vựng buổi sáng 🌅',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Từ cần ôn: example, difficult, vocabulary...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Thời gian: ${_settings!.morningTime}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
