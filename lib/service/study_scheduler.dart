import 'dart:math';

import 'package:bvo/model/word.dart';
import 'package:bvo/repository/user_progress_repository.dart';
import 'package:bvo/repository/word_repository.dart';

class StudySchedulerConfig {
  final int sessionSize; // total words per session
  final int newWordsCap; // max new words introduced in a session
  final bool prioritizeOverdue; // prioritize words overdue longer

  const StudySchedulerConfig({
    this.sessionSize = 20,
    this.newWordsCap = 6,
    this.prioritizeOverdue = true,
  });
}

class StudySchedulerResult {
  final List<dWord> words;
  final int dueCount;
  final int newCount;
  final int reviewCount;

  const StudySchedulerResult({
    required this.words,
    required this.dueCount,
    required this.newCount,
    required this.reviewCount,
  });
}

/// Picks a balanced set of words per session for a topic using spaced repetition signals
/// from UserProgressRepository. Selection order:
/// 1) Due reviews (overdue first)
/// 2) Difficult reviews (low accuracy, 3+ attempts)
/// 3) Low-exposure words (1-2 reviews)
/// 4) New words (up to newWordsCap)
class StudyScheduler {
  final WordRepository _wordRepository = WordRepository();
  final UserProgressRepository _progressRepository = UserProgressRepository();

  Future<StudySchedulerResult> selectSessionWords({
    required String topic,
    StudySchedulerConfig config = const StudySchedulerConfig(),
  }) async {
    final allTopicWords = await _wordRepository.getWordsByTopic(topic);
    final now = DateTime.now();

    // Attach progress to each word
    final progressList = <_WordProgressView>[];
    for (final w in allTopicWords) {
      final p = await _progressRepository.getWordProgress(topic, w.en);
      final totalAttempts = (p['totalAttempts'] ?? 0) as int;
      final correct = (p['correctAnswers'] ?? 0) as int;
      final reviewCount = (p['reviewCount'] ?? 0) as int;
      final nextReviewStr = p['nextReview'] as String?;
      final nextReview = nextReviewStr != null ? DateTime.tryParse(nextReviewStr) : null;
      final accuracy = totalAttempts > 0 ? correct / totalAttempts : 0.0;
      final isDue = nextReview == null || !nextReview.isAfter(now);
      progressList.add(_WordProgressView(word: w, reviewCount: reviewCount, totalAttempts: totalAttempts, accuracy: accuracy, nextReview: nextReview, isDue: isDue));
    }

    // Buckets
    final due = progressList.where((e) => e.totalAttempts > 0 && e.isDue).toList();
    final difficult = progressList.where((e) => e.totalAttempts >= 3 && e.accuracy < 0.7).toList();
    final lowExposure = progressList.where((e) => e.reviewCount > 0 && e.reviewCount <= 2).toList();
    final newCandidates = progressList.where((e) => e.totalAttempts == 0 && e.reviewCount == 0).toList();

    // Sort within buckets
    if (config.prioritizeOverdue) {
      due.sort((a, b) {
        final aOverBy = _overdueDays(a.nextReview, now);
        final bOverBy = _overdueDays(b.nextReview, now);
        if (aOverBy != bOverBy) return bOverBy.compareTo(aOverBy); // more overdue first
        // tie-break by lower accuracy, then higher difficulty
        final acc = a.accuracy.compareTo(b.accuracy);
        if (acc != 0) return acc;
        return a.word.difficulty.compareTo(b.word.difficulty);
      });
    } else {
      due.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    }

    difficult.sort((a, b) {
      final acc = a.accuracy.compareTo(b.accuracy); // lower first
      if (acc != 0) return acc;
      return b.totalAttempts.compareTo(a.totalAttempts); // more history first
    });

    lowExposure.sort((a, b) {
      final rc = a.reviewCount.compareTo(b.reviewCount); // 1 then 2
      if (rc != 0) return rc;
      return a.word.difficulty.compareTo(b.word.difficulty);
    });

    newCandidates.sort((a, b) {
      final d = a.word.difficulty.compareTo(b.word.difficulty);
      if (d != 0) return d;
      return a.word.en.toLowerCase().compareTo(b.word.en.toLowerCase());
    });

    // Assemble session
    final selected = <_WordProgressView>[];
    void takeFrom(List<_WordProgressView> source, int count) {
      for (final e in source) {
        if (selected.length >= config.sessionSize) break;
        if (selected.any((x) => x.word.en == e.word.en)) continue;
        selected.add(e);
        if (selected.length >= count) {
          // continue outer selection logic
        }
      }
    }

    // 1) Due reviews first
    takeFrom(due, config.sessionSize);

    // 2) Difficult reviews next
    if (selected.length < config.sessionSize) {
      takeFrom(difficult, config.sessionSize);
    }

    // 3) Low exposure
    if (selected.length < config.sessionSize) {
      takeFrom(lowExposure, config.sessionSize);
    }

    // Count how many new we can still introduce
    final currentNew = selected.where((e) => e.totalAttempts == 0 && e.reviewCount == 0).length;
    final remainingNewQuota = max(0, config.newWordsCap - currentNew);

    // 4) New words up to cap
    for (final e in newCandidates) {
      if (selected.length >= config.sessionSize) break;
      if (selected.any((x) => x.word.en == e.word.en)) continue;
      if (remainingNewQuota <= selected.where((x) => x.totalAttempts == 0 && x.reviewCount == 0).length) break;
      selected.add(e);
    }

    // If still underfilled, top up with remaining reviews (mix of buckets)
    if (selected.length < config.sessionSize) {
      final pool = [
        ...due,
        ...difficult,
        ...lowExposure,
      ];
      for (final e in pool) {
        if (selected.length >= config.sessionSize) break;
        if (selected.any((x) => x.word.en == e.word.en)) continue;
        selected.add(e);
      }
    }

    final words = selected.map((e) => e.word).toList();
    final dueCount = selected.where((e) => e.totalAttempts > 0 && e.isDue).length;
    final newCount = selected.where((e) => e.totalAttempts == 0 && e.reviewCount == 0).length;
    final reviewCount = words.length - newCount;

    return StudySchedulerResult(
      words: words,
      dueCount: dueCount,
      newCount: newCount,
      reviewCount: reviewCount,
    );
  }

  int _overdueDays(DateTime? nextReview, DateTime now) {
    if (nextReview == null) return 9999; // treat null as most overdue
    return now.difference(nextReview).inDays;
  }
}

class _WordProgressView {
  final dWord word;
  final int reviewCount;
  final int totalAttempts;
  final double accuracy;
  final DateTime? nextReview;
  final bool isDue;

  _WordProgressView({
    required this.word,
    required this.reviewCount,
    required this.totalAttempts,
    required this.accuracy,
    required this.nextReview,
    required this.isDue,
  });
}


