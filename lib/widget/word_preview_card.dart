import 'package:flutter/material.dart';
import '../model/word.dart';

class WordPreviewCard extends StatelessWidget {
  final Word word;
  final bool isRemoved;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const WordPreviewCard({
    Key? key,
    required this.word,
    required this.isRemoved,
    this.onRemove,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate progress status
    final progressLevel = word.reviewCount == 0 
        ? 'Mới' 
        : word.reviewCount < 3 
            ? 'Đang học' 
            : word.reviewCount < 5 
                ? 'Quen thuộc' 
                : 'Đã thuộc';
    
    final progressColor = word.reviewCount == 0 
        ? Colors.blue 
        : word.reviewCount < 3 
            ? Colors.orange 
            : word.reviewCount < 5 
                ? Colors.green 
                : Colors.purple;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      elevation: isRemoved ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isRemoved 
            ? BorderSide(color: Colors.grey[300]!, width: 1)
            : BorderSide.none,
      ),
      child: Opacity(
        opacity: isRemoved ? 0.4 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Word info - 2 lines layout
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Line 1: English word + Vietnamese meaning (same row)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            word.en,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isRemoved 
                                  ? Colors.grey[600] 
                                  : Colors.deepPurple,
                              decoration: isRemoved 
                                  ? TextDecoration.lineThrough 
                                  : TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            word.vi,
                            style: TextStyle(
                              fontSize: 13,
                              color: isRemoved 
                                  ? Colors.grey[500] 
                                  : Colors.grey[700],
                              fontStyle: FontStyle.italic,
                              decoration: isRemoved 
                                  ? TextDecoration.lineThrough 
                                  : TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Line 2: Progress badge + difficulty stars
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: progressColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            progressLevel,
                            style: TextStyle(
                              fontSize: 10,
                              color: progressColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (word.difficulty > 0) ...[
                          const SizedBox(width: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < word.difficulty 
                                    ? Icons.star 
                                    : Icons.star_border,
                                size: 11,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Remove button
              if (!isRemoved && onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.red[400],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: onRemove,
                  tooltip: 'Xóa khỏi quiz',
                ),
              if (isRemoved)
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.grey[400],
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

