#!/usr/bin/env python3
"""
Extract words from database for each topic/level and save to JSON files
- Read word lists from topic files (1.1.txt, 1.2.txt, etc.)
- Query database for full word data
- Export to JSON files with full structure matching dWord model
Run: python extract_topics_to_json.py
"""

import sqlite3
import json
import os
from datetime import datetime

# Configuration
DATABASE_FILE = "dictionary.db"
TOPIC_FILES = {
    '1.1': '../1000/1.1.txt',
    '1.2': '../1000/1.2.txt',
    '1.3': '../1000/1.3.txt',
    '1.4': '../1000/1.4.txt',
    '1.5': '../1000/1.5.txt',
    '2.0': '../1000/2.0.txt',
}
OUTPUT_DIR = "../1000"

def load_words_from_file(filepath):
    """Load words from topic file (comma-separated)"""
    if not os.path.exists(filepath):
        print(f"⚠ File not found: {filepath}")
        return []
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read().strip()
        
        # Split by comma and clean
        words = [w.strip() for w in content.split(',') if w.strip()]
        return words
    except Exception as e:
        print(f"✗ Error loading words from {filepath}: {e}")
        return []

def map_level_to_word_level(level):
    """Map level string to WordLevel enum string"""
    if level.startswith('1.'):
        return 'BASIC'
    elif level.startswith('2.'):
        return 'INTERMEDIATE'
    return 'BASIC'

def get_difficulty_from_level(level):
    """Get difficulty from level"""
    if level == '1.1' or level == '1.2':
        return 1
    elif level == '1.3' or level == '1.4':
        return 2
    elif level == '1.5' or level == '2.0':
        return 3
    return 2

def parse_json_field(value):
    """Parse JSON string field to list"""
    if not value:
        return []
    if isinstance(value, str):
        try:
            return json.loads(value)
        except:
            return []
    return value if isinstance(value, list) else []

def word_to_json(word_row, topic):
    """Convert database row to JSON format matching dWord model"""
    # Database columns: id, en, vi, pronunciation, sentence, sentenceVi, topic, level, type,
    # difficulty, isKidFriendly, mnemonicTip, tags, reviewCount, nextReview, masteryLevel,
    # lastReviewed, correctAnswers, totalAttempts, currentInterval, easeFactor, synonyms, antonyms,
    # created_at, updated_at, vi_detail
    
    word_id = word_row[0]
    en = word_row[1] or ''
    vi = word_row[2] or ''
    pronunciation = word_row[3] or ''
    sentence = word_row[4] or ''
    sentenceVi = word_row[5] or ''
    db_topic = word_row[6] or topic  # Use provided topic if db topic is empty
    # Override level based on topic, not from database
    level = map_level_to_word_level(topic)
    word_type = word_row[8] or 'noun'
    # Override difficulty based on topic, not from database
    difficulty = get_difficulty_from_level(topic)
    is_kid_friendly = bool(word_row[10]) if word_row[10] is not None else True
    mnemonic_tip = word_row[11] or None
    tags = parse_json_field(word_row[12])
    review_count = word_row[13] or 0
    next_review = word_row[14] or datetime.now().isoformat()
    mastery_level = float(word_row[15]) if word_row[15] is not None else 0.0
    last_reviewed = word_row[16] if word_row[16] else None
    correct_answers = word_row[17] or 0
    total_attempts = word_row[18] or 0
    current_interval = word_row[19] if word_row[19] is not None else 1
    ease_factor = float(word_row[20]) if word_row[20] is not None else 2.5
    synonyms = parse_json_field(word_row[21])
    antonyms = parse_json_field(word_row[22])
    
    # Build JSON object matching dWord.toJson() structure
    word_json = {
        'id': word_id,
        'en': en,
        'vi': vi,
        'sentence': sentence,
        'sentenceVi': sentenceVi,
        'topic': topic,  # Use topic from file, not from database
        'pronunciation': pronunciation,
        'audioUrl': None,  # Not in database
        'level': level if isinstance(level, str) else 'BASIC',
        'type': word_type if isinstance(word_type, str) else 'noun',
        'synonyms': synonyms,
        'antonyms': antonyms,
        'imageUrl': None,  # Not in database
        'difficulty': difficulty,
        'tags': tags,
        'reviewCount': review_count,
        'nextReview': next_review if isinstance(next_review, str) else datetime.now().isoformat(),
        'masteryLevel': mastery_level,
        'lastReviewed': last_reviewed,
        'correctAnswers': correct_answers,
        'totalAttempts': total_attempts,
        'currentInterval': current_interval,
        'easeFactor': ease_factor,
        'isKidFriendly': is_kid_friendly,
        'mnemonicTip': mnemonic_tip,
        'culturalNote': None,  # Not in database
    }
    
    return word_json

def extract_topic_words(database_path, topic, word_list):
    """Extract words from database for a specific topic"""
    if not os.path.exists(database_path):
        print(f"✗ Database not found: {database_path}")
        return []
    
    conn = sqlite3.connect(database_path)
    cursor = conn.cursor()
    
    # Build query to get all words in one go (case-insensitive)
    placeholders = ','.join(['?' for _ in word_list])
    cursor.execute(f"""
        SELECT id, en, vi, pronunciation, sentence, sentenceVi, topic, level, type,
               difficulty, isKidFriendly, mnemonicTip, tags, reviewCount, nextReview,
               masteryLevel, lastReviewed, correctAnswers, totalAttempts, currentInterval,
               easeFactor, synonyms, antonyms, created_at, updated_at
        FROM words
        WHERE LOWER(en) IN ({placeholders})
    """, [w.lower() for w in word_list])
    
    rows = cursor.fetchall()
    
    # Create a map of found words
    found_words_map = {}
    for row in rows:
        en_lower = row[1].lower() if row[1] else ''
        found_words_map[en_lower] = row
    
    # Build result list maintaining order from word_list
    result = []
    not_found = []
    
    for word in word_list:
        word_lower = word.lower()
        if word_lower in found_words_map:
            word_json = word_to_json(found_words_map[word_lower], topic)
            result.append(word_json)
        else:
            # Create minimal word object if not found
            not_found.append(word)
            result.append({
                'id': None,
                'en': word,
                'vi': '',
                'sentence': '',
                'sentenceVi': '',
                'topic': topic,
                'pronunciation': '',
                'audioUrl': None,
                'level': map_level_to_word_level(topic),
                'type': 'noun',
                'synonyms': [],
                'antonyms': [],
                'imageUrl': None,
                'difficulty': get_difficulty_from_level(topic),
                'tags': [],
                'reviewCount': 0,
                'nextReview': datetime.now().isoformat(),
                'masteryLevel': 0.0,
                'lastReviewed': None,
                'correctAnswers': 0,
                'totalAttempts': 0,
                'currentInterval': 1,
                'easeFactor': 2.5,
                'isKidFriendly': True,
                'mnemonicTip': None,
                'culturalNote': None,
            })
    
    conn.close()
    
    if not_found:
        print(f"  ⚠ {len(not_found)} words not found in database: {', '.join(not_found[:10])}{'...' if len(not_found) > 10 else ''}")
    
    return result

def main():
    """Main function"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    db_path = os.path.join(script_dir, DATABASE_FILE)
    output_dir = os.path.join(script_dir, OUTPUT_DIR)
    
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    print("="*60)
    print("Extract Topic Words to JSON")
    print("="*60)
    print(f"Database: {db_path}")
    print(f"Output directory: {output_dir}")
    print("="*60 + "\n")
    
    total_words = 0
    total_extracted = 0
    
    for topic, file_path in TOPIC_FILES.items():
        topic_file = os.path.join(script_dir, file_path)
        
        print(f"\nProcessing topic {topic}...")
        print(f"  File: {topic_file}")
        
        # Load words from topic file
        word_list = load_words_from_file(topic_file)
        if not word_list:
            print(f"  ⚠ No words found in {topic_file}")
            continue
        
        print(f"  ✓ Loaded {len(word_list)} words from file")
        
        # Extract words from database
        words_json = extract_topic_words(db_path, topic, word_list)
        
        if words_json:
            # Save to JSON file
            output_file = os.path.join(output_dir, f"{topic}.json")
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(words_json, f, ensure_ascii=False, indent=2)
            
            found_count = len([w for w in words_json if w.get('id') is not None])
            print(f"  ✓ Extracted {found_count}/{len(word_list)} words from database")
            print(f"  ✓ Saved to {output_file}")
            
            total_words += len(word_list)
            total_extracted += found_count
        else:
            print(f"  ✗ No words extracted for topic {topic}")
    
    print(f"\n{'='*60}")
    print("EXTRACTION SUMMARY")
    print(f"{'='*60}")
    print(f"Total topics processed: {len(TOPIC_FILES)}")
    print(f"Total words in files: {total_words}")
    print(f"Total words extracted from database: {total_extracted}")
    print(f"Success rate: {(total_extracted/total_words*100) if total_words > 0 else 0:.1f}%")
    print(f"{'='*60}\n")
    
    print("✓ Extraction complete!")
    print(f"JSON files saved in: {output_dir}")

if __name__ == '__main__':
    main()

