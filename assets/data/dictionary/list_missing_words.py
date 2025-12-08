#!/usr/bin/env python3
"""
List words from 1000.txt that are missing in dictionary.db
Run: python list_missing_words.py
"""

import sqlite3
import os

WORDS_FILE = "1000.txt"
DATABASE_FILE = "dictionary.db"

def load_words_from_file(filepath):
    """Load words from file (comma-separated or one per line)"""
    if not os.path.exists(filepath):
        print(f"⚠ File not found: {filepath}")
        return []
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read().strip()
        
        # Try comma-separated first
        if ',' in content:
            words = [w.strip().lower() for w in content.split(',') if w.strip()]
        else:
            # Try line-separated
            words = [w.strip().lower() for w in content.split('\n') if w.strip()]
        
        # Remove duplicates and sort
        words = sorted(list(set(words)))
        return words
    except Exception as e:
        print(f"✗ Error loading words: {e}")
        return []

def find_missing_words(conn, words):
    """Find words that are not in database"""
    cursor = conn.cursor()
    missing_words = []
    existing_words = []
    
    for word in words:
        cursor.execute("SELECT COUNT(*) FROM words WHERE LOWER(en) = ?", (word.lower(),))
        count = cursor.fetchone()[0]
        if count == 0:
            missing_words.append(word)
        else:
            existing_words.append(word)
    
    return missing_words, existing_words

if __name__ == '__main__':
    # Get script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    database_path = os.path.join(script_dir, DATABASE_FILE)
    words_file = os.path.join(script_dir, WORDS_FILE)
    
    print("="*60)
    print("List Missing Words from 1000.txt")
    print("="*60)
    print(f"Database: {database_path}")
    print(f"Words file: {words_file}")
    print("="*60 + "\n")
    
    # Check if files exist
    if not os.path.exists(database_path):
        print(f"✗ Database not found: {database_path}")
        exit(1)
    
    if not os.path.exists(words_file):
        print(f"✗ Words file not found: {words_file}")
        exit(1)
    
    # Connect to database
    conn = sqlite3.connect(database_path)
    
    # Load words
    print("Loading words from file...")
    words = load_words_from_file(words_file)
    print(f"✓ Loaded {len(words)} words from file\n")
    
    # Find missing words
    print("Checking database...")
    missing_words, existing_words = find_missing_words(conn, words)
    
    # Print results
    print(f"\n{'='*60}")
    print("RESULTS")
    print(f"{'='*60}")
    print(f"Total words in file: {len(words)}")
    print(f"Words in database: {len(existing_words)}")
    print(f"Missing words: {len(missing_words)}")
    print(f"{'='*60}\n")
    
    if missing_words:
        print("MISSING WORDS:")
        print("-" * 60)
        for i, word in enumerate(missing_words, 1):
            print(f"{i:4d}. {word}")
        print("-" * 60)
        print(f"\nTotal: {len(missing_words)} missing words")
        print("\nTo add these words, run: python add_missing_words.py")
    else:
        print("✓ All words are already in database!")
    
    conn.close()

