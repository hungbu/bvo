import 'package:flutter/material.dart';

/// A Text widget that allows word selection via long press or right click
class SelectableTextWithWordLookup extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: style,
      onTap: () {
        // Allow text selection
      },
    );
  }
}

/// A GestureDetector wrapper that detects word selection on long press or right click
class TextWithWordLookup extends StatelessWidget {
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
        text,
        style: style,
        onSelectionChanged: (selection, cause) {
          if (selection.isValid && !selection.isCollapsed) {
            // Get selected text
            final selectedText = text.substring(
              selection.start,
              selection.end,
            );
            
            // Extract word from selection (handle punctuation)
            final wordPattern = RegExp(r"[a-zA-Z]+(?:'[a-zA-Z]+)?(?:-[a-zA-Z]+)?");
            final match = wordPattern.firstMatch(selectedText.trim());
            
            if (match != null) {
              final word = match.group(0)!;
              // Show word detail after a short delay to allow selection to complete
              Future.delayed(const Duration(milliseconds: 300), () {
                onWordSelected(word);
              });
            }
          }
        },
      ),
    );
  }

  void _showWordSelectionMenu(BuildContext context) {
    // Extract all words from text
    final wordPattern = RegExp(r"[a-zA-Z]+(?:'[a-zA-Z]+)?(?:-[a-zA-Z]+)?");
    final matches = wordPattern.allMatches(text);
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
        onWordSelected(selectedWord);
      }
    });
  }
}

