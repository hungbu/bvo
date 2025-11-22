import 'dart:async';
import 'package:flutter/material.dart';
import '../service/dialog_manager.dart';

/// A Text widget that allows word selection via long press or right click
class SelectableTextWithWordLookup extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Function(String selectedText) onWordSelected;

  const SelectableTextWithWordLookup({
    Key? key,
    required this.text,
    this.style,
    required this.onWordSelected,
  }) : super(key: key);

  @override
  State<SelectableTextWithWordLookup> createState() => _SelectableTextWithWordLookupState();
}

class _SelectableTextWithWordLookupState extends State<SelectableTextWithWordLookup> {
  final DialogManager _dialogManager = DialogManager();
  Timer? _debounceTimer;
  String? _lastSelectedWord;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleWordSelection(String word) {
    // Cancel previous timer if exists
    _debounceTimer?.cancel();

    // Check if dialog is already open
    if (!_dialogManager.canOpenWordDetailDialog()) {
      return;
    }

    // Check if same word is selected again
    if (_lastSelectedWord == word) {
      return; // Ignore duplicate selection
    }

    _lastSelectedWord = word;

    // Debounce: wait a bit before processing
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_dialogManager.canOpenWordDetailDialog()) {
        widget.onWordSelected(word);
      }
      _lastSelectedWord = null; // Reset after processing
    });
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      widget.text,
      style: widget.style,
      onSelectionChanged: (selection, cause) {
        // Only handle when exactly one word is selected
        if (selection.isValid && !selection.isCollapsed) {
          // Get selected text
          final selectedText = widget.text.substring(
            selection.start,
            selection.end,
          ).trim();
          
          // Extract all words from selection
          final wordPattern = RegExp(r"[a-zA-Z]+(?:'[a-zA-Z]+)?(?:-[a-zA-Z]+)?");
          final matches = wordPattern.allMatches(selectedText);
          final words = matches.map((m) => m.group(0)!).toList();
          
          // Only process if exactly one word is selected
          if (words.length == 1) {
            final word = words.first;
            _handleWordSelection(word);
          }
        }
      },
    );
  }
}

/// A GestureDetector wrapper that detects word selection on long press or right click
class TextWithWordLookup extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Function(String word) onWordSelected;

  const TextWithWordLookup({
    Key? key,
    required this.text,
    this.style,
    required this.onWordSelected,
  }) : super(key: key);

  @override
  State<TextWithWordLookup> createState() => _TextWithWordLookupState();
}

class _TextWithWordLookupState extends State<TextWithWordLookup> {
  final DialogManager _dialogManager = DialogManager();
  Timer? _debounceTimer;
  String? _lastSelectedWord;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleWordSelection(String word) {
    // Cancel previous timer if exists
    _debounceTimer?.cancel();

    // Check if dialog is already open
    if (!_dialogManager.canOpenWordDetailDialog()) {
      return;
    }

    // Check if same word is selected again
    if (_lastSelectedWord == word) {
      return; // Ignore duplicate selection
    }

    _lastSelectedWord = word;

    // Debounce: wait a bit before processing
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_dialogManager.canOpenWordDetailDialog()) {
        widget.onWordSelected(word);
      }
      _lastSelectedWord = null; // Reset after processing
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        // On long press, show word selection menu
        _showWordSelectionMenu(context);
      },
      onSecondaryTap: () {
        // On right click (secondary tap), show word selection menu
        _showWordSelectionMenu(context);
      },
      child: SelectableText(
        widget.text,
        style: widget.style,
        onSelectionChanged: (selection, cause) {
          // Only handle when exactly one word is selected
          if (selection.isValid && !selection.isCollapsed) {
            // Get selected text
            final selectedText = widget.text.substring(
              selection.start,
              selection.end,
            ).trim();
            
            // Extract all words from selection
            final wordPattern = RegExp(r"[a-zA-Z]+(?:'[a-zA-Z]+)?(?:-[a-zA-Z]+)?");
            final matches = wordPattern.allMatches(selectedText);
            final words = matches.map((m) => m.group(0)!).toList();
            
            // Only process if exactly one word is selected
            if (words.length == 1) {
              final word = words.first;
              _handleWordSelection(word);
            }
          }
        },
      ),
    );
  }

  void _showWordSelectionMenu(BuildContext context) {
    // Extract all words from text
    final wordPattern = RegExp(r"[a-zA-Z]+(?:'[a-zA-Z]+)?(?:-[a-zA-Z]+)?");
    final matches = wordPattern.allMatches(widget.text);
    final words = matches.map((m) => m.group(0)!).toSet().toList()..sort();
    
    if (words.isEmpty) return;
    
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 100, 100),
      items: words.map((word) {
        return PopupMenuItem<String>(
          value: word,
          child: Text(word),
        );
      }).toList(),
    ).then((selectedWord) {
      if (selectedWord != null) {
        widget.onWordSelected(selectedWord);
      }
    });
  }
}

