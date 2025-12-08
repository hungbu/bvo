#!/usr/bin/env python3
"""
Migrate word levels from txt files to the app's database
This script should be run to update the database that the app actually uses
(usually in Documents folder on Windows, or app data directory on mobile)
"""

import sqlite3
import os
from pathlib import Path

# Level files mapping
LEVEL_FILES = {
    '1.1': 'assets/data/1000/1.1.txt',
    '1.2': 'assets/data/1000/1.2.txt',
    '1.3': 'assets/data/1000/1.3.txt',
    '1.4': 'assets/data/1000/1.4.txt',
    '1.5': 'assets/data/1000/1.5.txt',
    '2.0': 'assets/data/1000/2.0.txt',
}

def load_words_from_file(filepath):
    """Load words from a txt file"""
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
    
    if not os.path.exists(database_path):
        print(f"❌ Database not found at: {database_path}")
        print("   Please provide the path to the database file that the app uses.")
        print("   On Windows, it's usually in: C:\\Users\\<username>\\OneDrive\\Documents\\dictionary.db")
        return
    
    # Connect to database
    conn = sqlite3.connect(database_path)
    cursor = conn.cursor()
    
    print("="*60)
    print("Migrate Word Levels to App Database")
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
        
        print(f"  ✓ Updated {updated_count} words")
        if not_found_count > 0:
            print(f"  ⚠ {not_found_count} words not found in database")
        
        total_updated += updated_count
        total_not_found += not_found_count
        print()
    
    print("="*60)
    print(f"Migration complete!")
    print(f"  Total updated: {total_updated}")
    print(f"  Total not found: {total_not_found}")
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
    import sys
    
    # Get database path from command line or use default
    if len(sys.argv) > 1:
        database_path = sys.argv[1]
    else:
        # Default Windows path (adjust for your system)
        username = os.getenv('USERNAME') or os.getenv('USER')
        if username:
            database_path = f"C:\\Users\\{username}\\OneDrive\\Documents\\dictionary.db"
        else:
            print("❌ Cannot determine database path automatically.")
            print("   Please provide the database path as an argument:")
            print("   python migrate_levels_to_app_db.py <path_to_dictionary.db>")
            sys.exit(1)
    
    # Adjust file paths to be relative to project root
    script_dir = os.path.dirname(os.path.abspath(__file__))
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

