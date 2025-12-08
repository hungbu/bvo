#!/usr/bin/env python3
"""
Migrate word levels from txt files to database
- Read words from 1.1.txt, 1.2.txt, 1.3.txt, 1.4.txt, 1.5.txt, 2.0.txt
- Update topic column in database to match the level
Run: python migrate_levels_to_db.py
"""

import sqlite3
import os

DATABASE_FILE = "dictionary.db"

# Level file mapping
LEVEL_FILES = {
    '1.1': 'assets/data/1000/1.1.txt',
    '1.2': 'assets/data/1000/1.2.txt',
    '1.3': 'assets/data/1000/1.3.txt',
    '1.4': 'assets/data/1000/1.4.txt',
    '1.5': 'assets/data/1000/1.5.txt',
    '2.0': 'assets/data/1000/2.0.txt',
}

def load_words_from_file(filepath):
    """Load words from file (comma-separated)"""
    if not os.path.exists(filepath):
        print(f"⚠ File not found: {filepath}")
        return []
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read().strip()
        
        # Split by comma
        words = [w.strip().lower() for w in content.split(',') if w.strip()]
        return words
    except Exception as e:
        print(f"✗ Error loading words from {filepath}: {e}")
        return []

def migrate_levels_to_database(database_path):
    """Migrate word levels from txt files to database"""
    
    # Connect to database
    conn = sqlite3.connect(database_path)
    cursor = conn.cursor()
    
    print("="*60)
    print("Migrate Word Levels to Database")
    print("="*60)
    print(f"Database: {database_path}\n")
    
    total_updated = 0
    total_not_found = 0
    
    for level, filepath in LEVEL_FILES.items():
        print(f"Processing level {level} from {filepath}...")
        
        # Load words from file
        words = load_words_from_file(filepath)
        if not words:
            print(f"  ⚠ No words found in {filepath}\n")
            continue
        
        print(f"  Found {len(words)} words in file")
        
        # Update database
        updated_count = 0
        not_found_count = 0
        
        for word in words:
            # Update topic column to match level
            cursor.execute("""
                UPDATE words 
                SET topic = ?, updated_at = datetime('now')
                WHERE LOWER(en) = ?
            """, (level, word.lower()))
            
            if cursor.rowcount > 0:
                updated_count += 1
            else:
                not_found_count += 1
        
        conn.commit()
        
        print(f"  ✓ Updated: {updated_count} words")
        if not_found_count > 0:
            print(f"  ⚠ Not found in database: {not_found_count} words")
        print()
        
        total_updated += updated_count
        total_not_found += not_found_count
    
    # Summary
    print("="*60)
    print("SUMMARY")
    print("="*60)
    print(f"Total words updated: {total_updated}")
    print(f"Total words not found: {total_not_found}")
    print("="*60)
    
    # Show sample
    print("\nSample updated words:")
    cursor.execute("""
        SELECT en, topic, level 
        FROM words 
        WHERE topic IN ('1.1', '1.2', '1.3', '1.4', '1.5', '2.0')
        ORDER BY topic, en
        LIMIT 10
    """)
    for row in cursor.fetchall():
        print(f"  {row[0]} -> topic: {row[1]}, level: {row[2]}")
    
    conn.close()

if __name__ == '__main__':
    # Get script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    database_path = os.path.join(script_dir, DATABASE_FILE)
    
    # Adjust file paths to be relative to project root
    for level in LEVEL_FILES:
        filepath = LEVEL_FILES[level]
        # Try relative to script dir first
        full_path = os.path.join(script_dir, '..', '..', filepath)
        if os.path.exists(full_path):
            LEVEL_FILES[level] = full_path
        else:
            # Try relative to project root
            project_root = os.path.join(script_dir, '..', '..', '..')
            full_path = os.path.join(project_root, filepath)
            if os.path.exists(full_path):
                LEVEL_FILES[level] = full_path
    
    migrate_levels_to_database(database_path)

