import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:collection';

/// Audio item in queue
class _AudioItem {
  final String text;
  final String language;
  final double speechRate;
  final double pitch;
  final Completer<void> completer;

  _AudioItem({
    required this.text,
    required this.language,
    required this.speechRate,
    required this.pitch,
    required this.completer,
  });
}

/// Service to manage audio playback with queue
/// Ensures audio plays sequentially without interruption
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final Queue<_AudioItem> _queue = Queue<_AudioItem>();
  bool _isPlaying = false;
  bool _isInitialized = false;

  /// Initialize TTS
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      
      // Listen for completion
      _flutterTts.setCompletionHandler(() {
        print('📢 Completion handler called');
        _onSpeechComplete();
      });
      
      // Also listen for errors
      _flutterTts.setErrorHandler((msg) {
        print('❌ TTS Error: $msg');
        _onSpeechComplete(); // Continue queue even on error
      });
      
      _isInitialized = true;
      print('✅ AudioService initialized');
    } catch (e) {
      print('❌ Error initializing AudioService: $e');
    }
  }

  /// Speak text with normal speed
  Future<void> speakNormal(String text, {String language = 'en-US'}) async {
    await _addToQueue(
      text: text,
      language: language,
      speechRate: 0.5,
      pitch: 1.0,
    );
  }

  /// Speak text with slow speed
  Future<void> speakSlowly(String text, {String language = 'en-US'}) async {
    await _addToQueue(
      text: text,
      language: language,
      speechRate: 0.1,
      pitch: 1.0,
    );
  }

  /// Speak text with custom settings
  Future<void> speak({
    required String text,
    String language = 'en-US',
    double speechRate = 0.5,
    double pitch = 1.0,
  }) async {
    await _addToQueue(
      text: text,
      language: language,
      speechRate: speechRate,
      pitch: pitch,
    );
  }

  /// Add audio to queue
  Future<void> _addToQueue({
    required String text,
    required String language,
    required double speechRate,
    required double pitch,
  }) async {
    final completer = Completer<void>();
    final item = _AudioItem(
      text: text,
      language: language,
      speechRate: speechRate,
      pitch: pitch,
      completer: completer,
    );

    _queue.add(item);
    print('📢 Added to queue: "$text" (rate: $speechRate)');
    
    // Start processing if not already playing
    if (!_isPlaying) {
      _processQueue();
    }

    return completer.future;
  }

  /// Process queue
  Future<void> _processQueue() async {
    if (_queue.isEmpty) {
      print('⏸️ Queue is empty, nothing to process');
      return;
    }
    
    if (_isPlaying) {
      print('⏸️ Already playing, queue length: ${_queue.length}');
      return;
    }

    _isPlaying = true;
    final item = _queue.removeFirst();
    print('🔄 Processing queue item: "${item.text}" (queue remaining: ${_queue.length})');

    try {
      await initialize();
      
      // Ensure completion handler is set (in case it was lost)
      _flutterTts.setCompletionHandler(() {
        print('📢 Completion handler called');
        _onSpeechComplete();
      });
      
      // Ensure error handler is set
      _flutterTts.setErrorHandler((msg) {
        print('❌ TTS Error: $msg');
        _onSpeechComplete(); // Continue queue even on error
      });
      
      // Set TTS parameters
      await _flutterTts.setLanguage(item.language);
      await _flutterTts.setPitch(item.pitch);
      await _flutterTts.setSpeechRate(item.speechRate);
      
      print('🔊 Playing: "${item.text}" (rate: ${item.speechRate}, language: ${item.language})');
      
      // Store current item completer for completion handler
      _currentItemCompleter = item.completer;
      
      // Speak
      final result = await _flutterTts.speak(item.text);
      
      if (result != 1) {
        // If speak returns error, complete immediately
        print('⚠️ TTS speak returned error code: $result');
        _onSpeechComplete();
        return;
      }
      
      // Set a timeout to ensure we don't get stuck if completion handler doesn't fire
      // For very short words, use shorter timeout; for longer text, use longer timeout
      final estimatedDuration = (item.text.length * 100 / item.speechRate).ceil();
      final timeoutDuration = Duration(milliseconds: (estimatedDuration * 2).clamp(1000, 10000));
      
      _speechTimeoutTimer = Timer(timeoutDuration, () {
        print('⏰ Speech timeout after ${timeoutDuration.inMilliseconds}ms, forcing completion');
        _onSpeechComplete();
      });
      
      // Wait for completion (handled by completion handler)
      // The completer will be completed in _onSpeechComplete
      
    } catch (e) {
      print('❌ Error playing audio: $e');
      _speechTimeoutTimer?.cancel();
      _speechTimeoutTimer = null;
      if (item.completer.isCompleted == false) {
        item.completer.completeError(e);
      }
      _isPlaying = false;
      _currentItemCompleter = null;
      // Continue with next item
      _processQueue();
    }
  }

  Completer<void>? _currentItemCompleter;
  Timer? _speechTimeoutTimer;

  /// Called when speech completes
  void _onSpeechComplete() {
    // Cancel timeout timer if exists
    _speechTimeoutTimer?.cancel();
    _speechTimeoutTimer = null;
    print('✅ Speech completed (queue remaining: ${_queue.length}, isPlaying: $_isPlaying)');
    
    // Complete the current item's completer
    if (_currentItemCompleter != null && !_currentItemCompleter!.isCompleted) {
      _currentItemCompleter!.complete();
      _currentItemCompleter = null;
    }
    
    _isPlaying = false;
    
    // Reset to normal speed after slow speech
    if (_queue.isEmpty) {
      _flutterTts.setSpeechRate(0.5);
    }
    
    // Process next item in queue
    _processQueue();
  }

  /// Stop all audio and clear queue
  Future<void> stop() async {
    try {
      _speechTimeoutTimer?.cancel();
      _speechTimeoutTimer = null;
      await _flutterTts.stop();
      _queue.clear();
      _isPlaying = false;
      // Complete current item if exists
      if (_currentItemCompleter != null && !_currentItemCompleter!.isCompleted) {
        _currentItemCompleter!.complete();
        _currentItemCompleter = null;
      }
      print('🛑 AudioService stopped and queue cleared');
    } catch (e) {
      print('❌ Error stopping audio: $e');
    }
  }

  /// Check if audio is currently playing
  bool get isPlaying => _isPlaying;

  /// Get queue length
  int get queueLength => _queue.length;
}

