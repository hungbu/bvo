#!/usr/bin/env python3
"""
Update Vietnamese meanings in dictionary.db from 1000.json
- Read Vietnamese meanings from assets/data/1000/1000.json
- Update vi column in dictionary.db for matching words
Run: python update_from_json.py
"""

import sqlite3
import json
import os
from datetime import datetime

# Configuration
JSON_FILE = "../1000/1000.json"
DATABASE_FILE = "dictionary.db"

def load_json_meanings(json_path):
    """Load word-meaning pairs from JSON file"""
    if not os.path.exists(json_path):
        print(f"✗ File not found: {json_path}")
        return {}
    
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Convert to dictionary: {word: meaning}
        meanings = {}
        for item in data:
            word = item.get('word', '').strip().lower()
            meaning = item.get('meaning', '').strip()
            if word and meaning:
                meanings[word] = meaning
        
        print(f"✓ Loaded {len(meanings)} word-meaning pairs from {json_path}")
        return meanings
    except Exception as e:
        print(f"✗ Error loading JSON file: {e}")
        return {}

def update_database_meanings(database_path, meanings_dict):
    """Update Vietnamese meanings in database"""
    
    if not os.path.exists(database_path):
        print(f"✗ Database not found: {database_path}")
        return
    
    # Connect to database
    conn = sqlite3.connect(database_path)
    cursor = conn.cursor()
    
    # Get total words in database
    cursor.execute("SELECT COUNT(*) FROM words WHERE en IS NOT NULL AND en != ''")
    total_words = cursor.fetchone()[0]
    
    print(f"\n{'='*60}")
    print("UPDATING VIETNAMESE MEANINGS")
    print(f"{'='*60}")
    print(f"Database: {database_path}")
    print(f"Total words in database: {total_words}")
    print(f"Meanings to update: {len(meanings_dict)}")
    print(f"{'='*60}\n")
    
    # Track statistics
    updated_count = 0
    not_found_words = []
    skipped_count = 0
    
    # Update each word
    for word, new_meaning in meanings_dict.items():
        try:
            # Check if word exists in database (case-insensitive)
            cursor.execute("SELECT id, en, vi FROM words WHERE LOWER(en) = ?", (word.lower(),))
            results = cursor.fetchall()
            
            if results:
                # Update all matching words (in case there are duplicates with different cases)
                for word_id, db_word, old_meaning in results:
                    cursor.execute("""
                        UPDATE words 
                        SET vi = ?, updated_at = ?
                        WHERE id = ?
                    """, (new_meaning, datetime.now().isoformat(), word_id))
                
                updated_count += 1
                
                # Show progress every 50 words
                if updated_count % 50 == 0:
                    print(f"  Updated {updated_count} words...")
            else:
                not_found_words.append(word)
                
        except Exception as e:
            print(f"✗ Error updating word '{word}': {e}")
            skipped_count += 1
    
    # Commit changes
    conn.commit()
    
    # Final statistics
    print(f"\n{'='*60}")
    print("UPDATE SUMMARY")
    print(f"{'='*60}")
    print(f"✓ Successfully updated: {updated_count}")
    print(f"⚠ Words not found in database: {len(not_found_words)}")
    if not_found_words and len(not_found_words) <= 20:
        print(f"  Not found: {', '.join(not_found_words[:20])}")
    elif not_found_words:
        print(f"  First 20 not found: {', '.join(not_found_words[:20])}...")
    print(f"✗ Errors/Skipped: {skipped_count}")
    print(f"{'='*60}\n")
    
    # Show sample updated entries
    sample_words = list(meanings_dict.keys())[:5]
    if sample_words:
        placeholders = ','.join(['?' for _ in sample_words])
        cursor.execute(f"""
            SELECT en, vi 
            FROM words 
            WHERE LOWER(en) IN ({placeholders})
            AND vi IS NOT NULL AND vi != ''
            LIMIT 5
        """, [w.lower() for w in sample_words])
        
        print("Sample updated entries:")
        for row in cursor.fetchall():
            word, meaning = row
            print(f"  {word}")
            print(f"    → {meaning[:80]}{'...' if len(meaning) > 80 else ''}")
            print()
    
    conn.close()

def main():
    """Main function"""
    # Get absolute paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(script_dir, JSON_FILE)
    db_path = os.path.join(script_dir, DATABASE_FILE)
    
    print("="*60)
    print("Update Vietnamese Meanings from JSON")
    print("="*60)
    print(f"JSON file: {json_path}")
    print(f"Database: {db_path}")
    print("="*60 + "\n")
    
    # Load meanings from JSON
    meanings = load_json_meanings(json_path)
    
    if not meanings:
        print("✗ No meanings loaded. Exiting.")
        return
    
    # Update database
    update_database_meanings(db_path, meanings)
    
    print("✓ Update complete!")

if __name__ == '__main__':
    main()

