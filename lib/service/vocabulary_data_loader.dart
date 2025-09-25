import 'dart:convert';
import 'package:flutter/services.dart';
import '../model/word.dart';

/// Service to load vocabulary data directly from data files
class VocabularyDataLoader {
  static final VocabularyDataLoader _instance = VocabularyDataLoader._internal();
  factory VocabularyDataLoader() => _instance;
  VocabularyDataLoader._internal();

  // Cache for loaded data
  List<dWord>? _allWords;
  List<dWord>? _basicWords;
  List<dWord>? _intermediateWords;
  List<dWord>? _advancedWords;

  /// Get all vocabulary words
  Future<List<dWord>> getAllWords() async {
    if (_allWords != null) {
      print('getAllWords: returning cached list of \'${_allWords!.length}\' words');
      return _allWords!;
    }

    // Load all topic word files under assets/data/word
    print('getAllWords: loading from AssetManifest.json and assets/data/word/*.json');
    final words = await _loadAllTopicWordsFromAssets();

    // Sort by difficulty (ascending), then by English word (alphabetical)
    words.sort((a, b) {
      int difficultyComparison = a.difficulty.compareTo(b.difficulty);
      if (difficultyComparison != 0) {
        return difficultyComparison;
      }
      return a.en.toLowerCase().compareTo(b.en.toLowerCase());
    });

    print('getAllWords: loaded total \'${words.length}\' words (before caching)');
    _allWords = words;
    return _allWords!;
  }

  /// Get basic level words
  Future<List<dWord>> getBasicWords() async {
    if (_basicWords != null) {
      print('getBasicWords: returning cached list of \'${_basicWords!.length}\' words');
      return _basicWords!;
    }
    final all = await getAllWords();
    final filtered = all.where((w) => w.level == WordLevel.BASIC).toList();
    filtered.sort((a, b) {
      int difficultyComparison = a.difficulty.compareTo(b.difficulty);
      if (difficultyComparison != 0) {
        return difficultyComparison;
      }
      return a.en.toLowerCase().compareTo(b.en.toLowerCase());
    });
    _basicWords = filtered;
    print('getBasicWords: computed \'${_basicWords!.length}\' words');
    return _basicWords!;
  }

  /// Get intermediate level words
  Future<List<dWord>> getIntermediateWords() async {
    if (_intermediateWords != null) {
      print('getIntermediateWords: returning cached list of \'${_intermediateWords!.length}\' words');
      return _intermediateWords!;
    }
    final all = await getAllWords();
    final filtered = all.where((w) => w.level == WordLevel.INTERMEDIATE).toList();
    filtered.sort((a, b) {
      int difficultyComparison = a.difficulty.compareTo(b.difficulty);
      if (difficultyComparison != 0) {
        return difficultyComparison;
      }
      return a.en.toLowerCase().compareTo(b.en.toLowerCase());
    });
    _intermediateWords = filtered;
    print('getIntermediateWords: computed \'${_intermediateWords!.length}\' words');
    return _intermediateWords!;
  }

  /// Get advanced level words
  Future<List<dWord>> getAdvancedWords() async {
    if (_advancedWords != null) {
      print('getAdvancedWords: returning cached list of \'${_advancedWords!.length}\' words');
      return _advancedWords!;
    }
    final all = await getAllWords();
    final filtered = all.where((w) => w.level == WordLevel.ADVANCED).toList();
    filtered.sort((a, b) {
      int difficultyComparison = a.difficulty.compareTo(b.difficulty);
      if (difficultyComparison != 0) {
        return difficultyComparison;
      }
      return a.en.toLowerCase().compareTo(b.en.toLowerCase());
    });
    _advancedWords = filtered;
    print('getAdvancedWords: computed \'${_advancedWords!.length}\' words');
    return _advancedWords!;
  }

  /// Get words by level
  Future<List<dWord>> getWordsByLevel(WordLevel level) async {
    switch (level) {
      case WordLevel.BASIC:
        return await getBasicWords();
      case WordLevel.INTERMEDIATE:
        return await getIntermediateWords();
      case WordLevel.ADVANCED:
        return await getAdvancedWords();
    }
  }

  /// Get words by topic
  Future<List<dWord>> getWordsByTopic(String topic) async {
    final allWords = await getAllWords();
    final list = allWords.where((word) => word.topic == topic).toList();
    print('getWordsByTopic(\'$topic\'): found \'${list.length}\' words');
    return list;
  }

  /// Get words by difficulty
  Future<List<dWord>> getWordsByDifficulty(int difficulty) async {
    final allWords = await getAllWords();
    return allWords.where((word) => word.difficulty == difficulty).toList();
  }

  /// Get all available topics
  Future<List<String>> getAllTopics() async {
    final allWords = await getAllWords();
    return allWords.map((word) => word.topic).toSet().toList()..sort();
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final basic = await getBasicWords();
    final intermediate = await getIntermediateWords();
    final advanced = await getAdvancedWords();
    
    return {
      'total': basic.length + intermediate.length + advanced.length,
      'basic': basic.length,
      'intermediate': intermediate.length,
      'advanced': advanced.length,
      'topics': (await getAllTopics()).length,
    };
  }

  /// Clear cache (useful for hot reload or data updates)
  void clearCache() {
    _allWords = null;
    _basicWords = null;
    _intermediateWords = null;
    _advancedWords = null;
    print('VocabularyDataLoader: caches cleared');
  }

  /// Load words from JSON asset file and sort by difficulty
  Future<List<dWord>> _loadWordsFromAsset(String assetPath) async {
    try {
      final String jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = json.decode(jsonString);
      
      final words = jsonList.map((json) => dWord.fromJson(json as Map<String, dynamic>)).toList();
      
      // Sort by difficulty (ascending), then by English word (alphabetical)
      words.sort((a, b) {
        int difficultyComparison = a.difficulty.compareTo(b.difficulty);
        if (difficultyComparison != 0) {
          return difficultyComparison;
        }
        return a.en.toLowerCase().compareTo(b.en.toLowerCase());
      });
      
      return words;
    } catch (e) {
      print('Error loading words from $assetPath: $e');
      return [];
    }
  }

  /// Load all topic word files from the asset manifest
  Future<List<dWord>> _loadAllTopicWordsFromAssets() async {
    try {
      final String manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent) as Map<String, dynamic>;
      print('AssetManifest: top-level keys = ${manifestMap.keys.join(', ')}');

      // Support both legacy and new formats of AssetManifest
      Iterable<String> candidateKeys;
      if (manifestMap.containsKey('files') && manifestMap['files'] is Map<String, dynamic>) {
        final Map<String, dynamic> filesMap = manifestMap['files'] as Map<String, dynamic>;
        print('AssetManifest: detected new format with files=${filesMap.length}');
        candidateKeys = filesMap.keys;
      } else {
        print('AssetManifest: detected legacy format with entries=${manifestMap.length}');
        candidateKeys = manifestMap.keys;
      }

      final assetPaths = candidateKeys
          .where((key) => key.startsWith('assets/data/word/') && key.endsWith('.json'))
          .toList()
            ..sort();

      if (assetPaths.isEmpty) {
        print('No topic word JSON files found under assets/data/word/.');
        return [];
      }
      print('Found \'${assetPaths.length}\' topic word files. First few: ' + (assetPaths.isNotEmpty ? assetPaths.take(5).join(', ') : '<none>'));

      // Load sequentially to emit per-file logs
      final all = <dWord>[];
      for (final path in assetPaths) {
        final list = await _loadWordsFromAsset(path);
        print('Loaded \'${list.length}\' words from $path');
        all.addAll(list);
      }
      print('Total words aggregated from topic files: \'${all.length}\'');
      return all;
    } catch (e) {
      print('Error loading AssetManifest.json or topic word assets: $e');
      return [];
    }
  }
}