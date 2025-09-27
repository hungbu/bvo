
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bvo/model/word.dart';
import 'package:bvo/screen/flashcard/flashcard.dart';
import 'package:bvo/service/study_scheduler.dart';
import 'package:bvo/repository/user_progress_repository.dart';

class NewPairFlashcardScreen extends StatefulWidget {
  final String topic;
  final StudySchedulerConfig config;

  const NewPairFlashcardScreen({
    super.key,
    required this.topic,
    this.config = const StudySchedulerConfig(),
  });

  @override
  State<NewPairFlashcardScreen> createState() => _NewPairFlashcardScreenState();
}

class _NewPairFlashcardScreenState extends State<NewPairFlashcardScreen> {
  final StudyScheduler _scheduler = StudyScheduler();
  final UserProgressRepository _progressRepository = UserProgressRepository();
  final CarouselSliderController _carouselController = CarouselSliderController();
  final FlutterTts _flutterTts = FlutterTts();
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  List<dWord> _words = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String _feedback = '';
  bool _hideEnglish = false;

  // Pair study mode
  static const int _pairSize = 2;
  int _pairStartIndex = 0;
  String _stage = 'learn'; // learn -> recall
  bool _flipped = false;

  // Session stats
  int _correct = 0;
  int _attempts = 0;
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() { _isLoading = true; });
    final res = await _scheduler.selectSessionWords(topic: widget.topic, config: widget.config);
    setState(() {
      _words = res.words;
      _isLoading = false;
      _currentIndex = 0;
      _pairStartIndex = 0;
      _stage = 'learn';
      _sessionStart = DateTime.now();
    });
    if (_words.isNotEmpty) {
      await _speak(_words.first.en);
    }
    _inputFocusNode.requestFocus();
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _flip() {
    setState(() { _flipped = true; });
  }

  Future<void> _checkAnswerRealtime() async {
    if (_stage == 'learn') return; // only in recall
    final answer = _controller.text.trim().toLowerCase();
    final correct = _words[_currentIndex].en.trim().toLowerCase().replaceAll('-', ' ');
    if (answer.length == correct.length) {
      await _checkAnswer();
    } else {
      setState(() { _feedback = ''; });
    }
  }

  Future<void> _checkAnswer() async {
    if (_stage == 'learn') return;
    final answer = _controller.text.trim().toLowerCase();
    final word = _words[_currentIndex];
    final correct = word.en.trim().toLowerCase().replaceAll('-', ' ');
    _attempts += 1;
    final ok = answer == correct;
    await _progressRepository.updateWordProgress(widget.topic, word, ok);
    if (ok) {
      _correct += 1;
      setState(() { _feedback = 'Correct!'; });
      await _speak(word.en);
      _flip();
    } else {
      setState(() { _feedback = 'Try again.'; });
    }
  }

  void _next() {
    final pairEnd = (_pairStartIndex + _pairSize - 1).clamp(0, _words.length - 1);
    if (_stage == 'learn') {
      if (_currentIndex < pairEnd) {
        setState(() { _flipped = false; });
        _carouselController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.linear);
      } else {
        setState(() {
          _stage = 'recall';
          _feedback = '';
          _flipped = false;
        });
        _controller.clear();
        _carouselController.animateToPage(_pairStartIndex, duration: const Duration(milliseconds: 200), curve: Curves.linear);
      }
    } else {
      if (_currentIndex < pairEnd) {
        setState(() { _flipped = false; });
        _controller.clear();
        _carouselController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.linear);
      } else {
        _pairStartIndex += _pairSize;
        if (_pairStartIndex >= _words.length) {
          _finishSession();
          return;
        }
        setState(() {
          _stage = 'learn';
          _feedback = '';
          _flipped = false;
        });
        _controller.clear();
        _carouselController.animateToPage(_pairStartIndex, duration: const Duration(milliseconds: 200), curve: Curves.linear);
      }
    }
  }

  Future<void> _finishSession() async {
    final prefs = await SharedPreferences.getInstance();
    final duration = _sessionStart != null ? DateTime.now().difference(_sessionStart!) : Duration.zero;
    final accuracy = _attempts > 0 ? (_correct / _attempts) * 100 : 0.0;
    // minimal session log
    final now = DateTime.now();
    final sessionKey = 'newpair_${now.millisecondsSinceEpoch}';
    await prefs.setString('${sessionKey}_topic', widget.topic);
    await prefs.setInt('${sessionKey}_words', _words.length);
    await prefs.setInt('${sessionKey}_correct', _correct);
    await prefs.setInt('${sessionKey}_attempts', _attempts);
    await prefs.setDouble('${sessionKey}_accuracy', accuracy);
    await prefs.setInt('${sessionKey}_duration', duration.inSeconds);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Hoàn thành'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số từ: ${_words.length}'),
            Text('Độ chính xác: ${accuracy.toStringAsFixed(1)}%'),
            Text('Thời gian: ${duration.inMinutes}m ${duration.inSeconds % 60}s'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop('completed'); },
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () { Navigator.of(context).pop(); _loadSession(); },
            child: const Text('Học tiếp'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Flashcard (${_isLoading ? 0 : _words.length})'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() { _hideEnglish = !_hideEnglish; });
            },
            icon: Icon(_hideEnglish ? Icons.visibility_off : Icons.visibility),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? const Center(child: Text('Không có từ cho phiên học'))
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        flex: 4,
                        child: CarouselSlider.builder(
                          carouselController: _carouselController,
                          itemCount: _words.length,
                          options: CarouselOptions(
                            height: double.infinity,
                            enlargeCenterPage: true,
                            viewportFraction: 0.8,
                            enableInfiniteScroll: false,
                            onPageChanged: (index, reason) {
                              setState(() {
                                if (_stage == 'learn') {
                                  final pairEnd = (_pairStartIndex + _pairSize - 1).clamp(0, _words.length - 1);
                                  if (index < _pairStartIndex) {
                                    _currentIndex = _pairStartIndex;
                                    _carouselController.animateToPage(_pairStartIndex, duration: const Duration(milliseconds: 120), curve: Curves.linear);
                                  } else if (index > pairEnd) {
                                    _currentIndex = pairEnd;
                                    _carouselController.animateToPage(pairEnd, duration: const Duration(milliseconds: 120), curve: Curves.linear);
                                  } else {
                                    _currentIndex = index;
                                  }
                                } else {
                                  _currentIndex = index;
                                }
                                _controller.clear();
                                _feedback = '';
                                _flipped = false;
                              });

                              if (_stage == 'learn') {
                                final pairEnd = (_pairStartIndex + _pairSize - 1).clamp(0, _words.length - 1);
                                if (_currentIndex >= pairEnd) {
                                  setState(() { _stage = 'recall'; _feedback = ''; });
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _carouselController.animateToPage(_pairStartIndex, duration: const Duration(milliseconds: 150), curve: Curves.linear);
                                  });
                                }
                              }
                            },
                          ),
                          itemBuilder: (context, index, realIdx) {
                            return Flashcard(
                              word: _words[index],
                              sessionHideEnglishText: _hideEnglish,
                              isFlipped: index == _currentIndex ? _flipped : false,
                              onAnswerSubmitted: (_) {},
                            );
                          },
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _stage == 'learn' ? _buildLearnControls() : _buildRecallInputs(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLearnControls() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: const Text('Xem 2 thẻ, sau đó nhập lại để ôn.', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        _buildNextButton(alwaysEnabled: true),
      ],
    );
  }

  Widget _buildRecallInputs() {
    final pairEnd = (_pairStartIndex + _pairSize - 1).clamp(0, _words.length - 1);
    final inputs = <Widget>[];
    for (int i = _pairStartIndex; i <= pairEnd; i++) {
      final active = i == _currentIndex;
      inputs.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.green : Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${(i - _pairStartIndex) + 1}', style: TextStyle(color: active ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: active ? _controller : TextEditingController(text: ''),
                  focusNode: active ? _inputFocusNode : null,
                  readOnly: !active,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: active ? 'Nhập từ tiếng Anh #${(i - _pairStartIndex) + 1}' : 'Chờ... (#${(i - _pairStartIndex) + 1})',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _checkAnswer(),
                  onChanged: (_) => _checkAnswerRealtime(),
                ),
              ),
              const SizedBox(width: 10),
              if (active) _buildNextButton(alwaysEnabled: _stage == 'learn'),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        ...inputs,
        const SizedBox(height: 8),
        if (_feedback.isNotEmpty)
          Text(
            _feedback,
            style: TextStyle(color: _feedback == 'Correct!' ? Colors.green : Colors.orange, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  Widget _buildNextButton({bool alwaysEnabled = false}) {
    final canProceed = alwaysEnabled || _flipped;
    return GestureDetector(
      onTap: canProceed ? _next : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: canProceed ? Colors.green : Colors.grey[400],
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_forward, color: canProceed ? Colors.white : Colors.grey[600], size: 20),
            const SizedBox(width: 6),
            Text('Next', style: TextStyle(color: canProceed ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}


