import 'package:shared_preferences/shared_preferences.dart';
import '../model/practice_history.dart';

class PracticeHistoryRepository {
  static const String _historyKeyPrefix = 'practice_history_';
  static const String _historyListKey = 'practice_history_list_';

  /// Save a practice history session
  Future<void> saveHistory(PracticeHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save individual history
    final key = '$_historyKeyPrefix${history.id}';
    await prefs.setString(key, history.toJsonString());
    
    // Add to reading's history list
    final listKey = '$_historyListKey${history.readingId}';
    final existingList = prefs.getStringList(listKey) ?? [];
    if (!existingList.contains(history.id)) {
      existingList.add(history.id);
      await prefs.setStringList(listKey, existingList);
    }
  }

  /// Load history by ID
  Future<PracticeHistory?> loadHistory(String historyId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_historyKeyPrefix$historyId';
    final historyJson = prefs.getString(key);
    
    if (historyJson == null) {
      return null;
    }
    
    try {
      return PracticeHistory.fromJsonString(historyJson);
    } catch (e) {
      print('Error loading history $historyId: $e');
      return null;
    }
  }

  /// Load all histories for a reading
  Future<List<PracticeHistory>> loadHistoriesForReading(String readingId) async {
    final prefs = await SharedPreferences.getInstance();
    final listKey = '$_historyListKey$readingId';
    final historyIds = prefs.getStringList(listKey) ?? [];
    
    final List<PracticeHistory> histories = [];
    for (final historyId in historyIds) {
      final history = await loadHistory(historyId);
      if (history != null) {
        histories.add(history);
      }
    }
    
    // Sort by completedAt descending (newest first)
    histories.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    
    return histories;
  }

  /// Delete a history
  Future<void> deleteHistory(String historyId, String readingId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove from reading's history list
    final listKey = '$_historyListKey$readingId';
    final existingList = prefs.getStringList(listKey) ?? [];
    existingList.remove(historyId);
    await prefs.setStringList(listKey, existingList);
    
    // Remove individual history
    final key = '$_historyKeyPrefix$historyId';
    await prefs.remove(key);
  }

  /// Delete all histories for a reading
  Future<void> deleteAllHistoriesForReading(String readingId) async {
    final prefs = await SharedPreferences.getInstance();
    final listKey = '$_historyListKey$readingId';
    final historyIds = prefs.getStringList(listKey) ?? [];
    
    for (final historyId in historyIds) {
      final key = '$_historyKeyPrefix$historyId';
      await prefs.remove(key);
    }
    
    await prefs.remove(listKey);
  }

  /// Get latest history for a reading
  Future<PracticeHistory?> getLatestHistory(String readingId) async {
    final histories = await loadHistoriesForReading(readingId);
    return histories.isNotEmpty ? histories.first : null;
  }
}

