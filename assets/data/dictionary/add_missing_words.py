#!/usr/bin/env python3
"""
Add missing words from 1000.txt to dictionary.db using AI
- Check which words from 1000.txt are missing in database
- Generate word data using AI
- Insert into database
Run: python add_missing_words.py
"""

import sqlite3
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import json
import re
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading
import time
import sys
import os

# Configuration
LM_STUDIO_URL = "http://localhost:1234/v1/chat/completions"
MAX_WORKERS = 1  # Use 1 worker to maintain consistent speed
BATCH_SIZE = 10  # Words per batch
SAVE_INTERVAL = 20  # Save progress every N words
TIMEOUT = 20  # Timeout for each request
REQUEST_DELAY = 0.0  # Delay between requests
MODEL_NAME = "qwen/qwen3-4b-2507"
WORDS_FILE = "1000.txt"  # File containing words to check
DATABASE_FILE = "dictionary.db"

# Thread-safe counter
class ProgressCounter:
    def __init__(self, total):
        self.lock = threading.Lock()
        self.processed = 0
        self.success = 0
        self.failed = 0
        self.total = total
        self.start_time = time.time()
    
    def increment(self, success=True):
        with self.lock:
            self.processed += 1
            if success:
                self.success += 1
            else:
                self.failed += 1
    
    def get_stats(self):
        with self.lock:
            elapsed = time.time() - self.start_time
            rate = self.processed / elapsed if elapsed > 0 else 0
            remaining = (self.total - self.processed) / rate if rate > 0 else 0
            return {
                'processed': self.processed,
                'success': self.success,
                'failed': self.failed,
                'total': self.total,
                'percent': (self.processed / self.total * 100) if self.total > 0 else 0,
                'rate': rate,
                'remaining': remaining
            }

def print_progress(stats, phase=""):
    """Print beautiful progress bar"""
    percent = stats['percent']
    bar_length = 40
    filled = int(bar_length * percent / 100)
    bar = '█' * filled + '░' * (bar_length - filled)
    
    # Format time
    remaining_min = int(stats['remaining'] / 60)
    remaining_sec = int(stats['remaining'] % 60)
    
    phase_str = f"{phase} | " if phase else ""
    sys.stdout.write(f'\r{phase_str}[{bar}] {percent:.1f}% | '
                    f'{stats["processed"]}/{stats["total"]} | '
                    f'✓ {stats["success"]} ✗ {stats["failed"]} | '
                    f'{stats["rate"]:.1f} words/s | '
                    f'ETA: {remaining_min}m {remaining_sec}s')
    sys.stdout.flush()

# Thread-local storage for HTTP sessions
_thread_local = threading.local()

def get_session():
    """Get or create a thread-local HTTP session with connection pooling"""
    if not hasattr(_thread_local, 'session'):
        session = requests.Session()
        retry_strategy = Retry(
            total=2,
            backoff_factor=0.3,
            status_forcelist=[429, 500, 502, 503, 504],
        )
        adapter = HTTPAdapter(
            max_retries=retry_strategy,
            pool_connections=1,
            pool_maxsize=1,
            pool_block=False
        )
        session.mount("http://", adapter)
        session.mount("https://", adapter)
        _thread_local.session = session
    return _thread_local.session

def call_ai_model(prompt, max_tokens=300, retry=1):
    """Call LM Studio AI model"""
    session = get_session()
    
    for attempt in range(retry + 1):
        try:
            if attempt == 0 and REQUEST_DELAY > 0:
                time.sleep(REQUEST_DELAY)
            
            response = session.post(
                LM_STUDIO_URL,
                json={
                    "model": MODEL_NAME,
                    "messages": [
                        {
                            "role": "system",
                            "content": "Convert to JSON only. No markdown."
                        },
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ],
                    "temperature": 0.1,
                    "max_tokens": max_tokens,
                    "stream": False
                },
                timeout=TIMEOUT
            )
            
            if response.status_code == 200:
                result = response.json()
                return result['choices'][0]['message']['content']
            elif attempt < retry - 1:
                time.sleep(1)
                continue
        except Exception as e:
            if attempt < retry - 1:
                time.sleep(1)
                continue
    
    return None

def generate_word_data(word):
    """Use AI to generate complete word data"""
    
    # Prompt to generate word data
    prompt = f"""Word: {word}

Generate complete dictionary entry in JSON format:
{{
  "en": "{word}",
  "vi": "Vietnamese meaning (concise, max 50 words)",
  "pronunciation": "IPA pronunciation or empty",
  "sentence": "Example sentence in English",
  "sentenceVi": "Vietnamese translation of example sentence",
  "topic": "general",
  "level": "BASIC",
  "type": "noun/verb/adjective/adverb/preposition/conjunction/interjection/pronoun/determiner/phrase",
  "difficulty": 1-5,
  "isKidFriendly": true/false,
  "mnemonicTip": "Memory tip in Vietnamese (optional)",
  "tags": ["tag1", "tag2"],
  "synonyms": ["synonym1", "synonym2"],
  "antonyms": ["antonym1", "antonym2"]
}}

Return JSON only, no markdown."""

    ai_response = call_ai_model(prompt, max_tokens=400)
    
    if ai_response:
        try:
            # Clean response
            clean_response = re.sub(r'```json\s*', '', ai_response)
            clean_response = re.sub(r'```\s*', '', clean_response)
            clean_response = clean_response.strip()
            
            # Extract JSON
            json_match = re.search(r'\{.*\}', clean_response, re.DOTALL)
            if json_match:
                parsed = json.loads(json_match.group())
                
                word_data = {
                    "en": word,
                    "vi": parsed.get("vi", ""),
                    "pronunciation": parsed.get("pronunciation", ""),
                    "sentence": parsed.get("sentence", ""),
                    "sentenceVi": parsed.get("sentenceVi", ""),
                    "topic": parsed.get("topic", "general"),
                    "level": parsed.get("level", "BASIC"),
                    "type": parsed.get("type", "word"),
                    "difficulty": int(parsed.get("difficulty", 1)),
                    "isKidFriendly": bool(parsed.get("isKidFriendly", True)),
                    "mnemonicTip": parsed.get("mnemonicTip", ""),
                    "tags": parsed.get("tags", []),
                    "synonyms": parsed.get("synonyms", []),
                    "antonyms": parsed.get("antonyms", [])
                }
                return word_data, None
        except Exception as e:
            return None, str(e)
    
    # Fallback: minimal word data
    return {
        "en": word,
        "vi": f"Meaning of {word}",
        "pronunciation": "",
        "sentence": f"This is {word}.",
        "sentenceVi": f"Đây là {word}.",
        "topic": "general",
        "level": "BASIC",
        "type": "word",
        "difficulty": 1,
        "isKidFriendly": True,
        "mnemonicTip": "",
        "tags": [],
        "synonyms": [],
        "antonyms": []
    }, "fallback"

def ensure_sqlite_type(value):
    """Convert value to SQLite-compatible type"""
    if value is None:
        return None
    if isinstance(value, bool):
        return 1 if value else 0
    if isinstance(value, (list, dict)):
        return json.dumps(value) if value else None
    return str(value) if value else None

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
        print(f"✓ Loaded {len(words)} words from {filepath}")
        return words
    except Exception as e:
        print(f"✗ Error loading words: {e}")
        return []

def find_missing_words(conn, words):
    """Find words that are not in database"""
    cursor = conn.cursor()
    missing_words = []
    
    for word in words:
        cursor.execute("SELECT COUNT(*) FROM words WHERE LOWER(en) = ?", (word.lower(),))
        count = cursor.fetchone()[0]
        if count == 0:
            missing_words.append(word)
    
    return missing_words

def insert_word(conn, word_data, db_lock):
    """Insert word into database (thread-safe)"""
    with db_lock:
        cursor = conn.cursor()
        try:
            current_time = datetime.now().isoformat()
            next_review = (datetime.now() + timedelta(days=1)).isoformat()
            
            cursor.execute('''
                INSERT OR IGNORE INTO words 
                (en, vi, pronunciation, sentence, sentenceVi, topic, level, type, 
                 difficulty, isKidFriendly, mnemonicTip, tags, reviewCount, nextReview,
                 masteryLevel, lastReviewed, correctAnswers, totalAttempts, 
                 currentInterval, easeFactor, synonyms, antonyms, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                ensure_sqlite_type(word_data.get('en', '')),
                ensure_sqlite_type(word_data.get('vi', '')),
                ensure_sqlite_type(word_data.get('pronunciation', '')),
                ensure_sqlite_type(word_data.get('sentence', '')),
                ensure_sqlite_type(word_data.get('sentenceVi', '')),
                ensure_sqlite_type(word_data.get('topic', 'general')),
                ensure_sqlite_type(word_data.get('level', 'BASIC')),
                ensure_sqlite_type(word_data.get('type', 'word')),
                ensure_sqlite_type(word_data.get('difficulty', 1)),
                ensure_sqlite_type(word_data.get('isKidFriendly', True)),
                ensure_sqlite_type(word_data.get('mnemonicTip', '')),
                ensure_sqlite_type(word_data.get('tags', [])),
                0,  # reviewCount
                next_review,  # nextReview
                0.0,  # masteryLevel
                None,  # lastReviewed
                0,  # correctAnswers
                0,  # totalAttempts
                1,  # currentInterval
                2.5,  # easeFactor
                ensure_sqlite_type(word_data.get('synonyms', [])),
                ensure_sqlite_type(word_data.get('antonyms', [])),
                current_time,  # created_at
                current_time  # updated_at
            ))
            return True
        except Exception as e:
            print(f"\n✗ Error inserting word {word_data.get('en', 'unknown')}: {e}")
            return False

def process_word_batch(word_batch, conn, counter, db_lock):
    """Process a batch of words (thread-safe)"""
    results = []
    
    for word in word_batch:
        try:
            # Generate word data from AI
            word_data, error = generate_word_data(word)
            
            if word_data:
                # Insert into database
                success = insert_word(conn, word_data, db_lock)
                results.append((word, success))
            else:
                results.append((word, False))
                
        except Exception as e:
            print(f"\n✗ Error processing {word}: {e}")
            results.append((word, False))
    
    # Update counter
    for word, success in results:
        counter.increment(success)
    
    return len([r for r in results if r[1]])

def add_missing_words(database_path, words_file):
    """Main function to add missing words"""
    
    # Connect to database
    conn = sqlite3.connect(database_path, check_same_thread=False)
    
    # Load words from file
    print(f"\n{'='*60}")
    print("STEP 1: Loading words from file")
    print(f"{'='*60}")
    words = load_words_from_file(words_file)
    
    if not words:
        print("✗ No words to process")
        conn.close()
        return
    
    # Find missing words
    print(f"\n{'='*60}")
    print("STEP 2: Checking database for missing words")
    print(f"{'='*60}")
    missing_words = find_missing_words(conn, words)
    
    total_words = len(words)
    existing_words = total_words - len(missing_words)
    
    print(f"Total words in file: {total_words}")
    print(f"Words in database: {existing_words}")
    print(f"Missing words: {len(missing_words)}")
    
    if not missing_words:
        print("\n✓ All words are already in database!")
        conn.close()
        return
    
    # List missing words
    print(f"\n{'='*60}")
    print("MISSING WORDS LIST")
    print(f"{'='*60}")
    for i, word in enumerate(missing_words, 1):
        print(f"{i:4d}. {word}")
    print(f"{'='*60}\n")
    
    # Ask for confirmation
    response = input(f"Add {len(missing_words)} missing words to database? (y/n): ")
    if response.lower() != 'y':
        print("Cancelled.")
        conn.close()
        return
    
    # Process missing words
    print(f"\n{'='*60}")
    print("STEP 3: Generating word data and adding to database")
    print(f"{'='*60}")
    
    total_missing = len(missing_words)
    counter = ProgressCounter(total_missing)
    db_lock = threading.Lock()
    
    print(f"Words to add: {total_missing}")
    print(f"Batch size: {BATCH_SIZE} | Workers: {MAX_WORKERS}\n")
    
    save_counter = 0
    
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = []
        
        # Submit batches
        for i in range(0, total_missing, BATCH_SIZE):
            batch = missing_words[i:i + BATCH_SIZE]
            future = executor.submit(process_word_batch, batch, conn, counter, db_lock)
            futures.append(future)
        
        # Process completed batches
        for future in as_completed(futures):
            try:
                success_count = future.result()
                save_counter += success_count
                
                # Save progress periodically
                if save_counter >= SAVE_INTERVAL:
                    with db_lock:
                        conn.commit()
                    save_counter = 0
                
                # Update progress bar
                print_progress(counter.get_stats(), "Adding words")
                
            except Exception as e:
                print(f"\n✗ Error processing batch: {e}")
                print_progress(counter.get_stats(), "Adding words")
    
    # Final commit
    with db_lock:
        conn.commit()
    
    # Final statistics
    stats = counter.get_stats()
    elapsed = time.time() - counter.start_time
    
    print(f"\n\n{'='*60}")
    print("FINAL SUMMARY")
    print(f"{'='*60}")
    print(f"✓ Processed: {stats['processed']} | Success: {stats['success']} | Failed: {stats['failed']}")
    print(f"✓ Time: {int(elapsed/60)}m {int(elapsed%60)}s | Speed: {stats['rate']:.2f} words/s")
    
    # Verify
    final_missing = find_missing_words(conn, words)
    print(f"✓ Remaining missing words: {len(final_missing)}")
    print(f"{'='*60}\n")
    
    conn.close()

if __name__ == '__main__':
    # Get script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    database_path = os.path.join(script_dir, DATABASE_FILE)
    words_file = os.path.join(script_dir, WORDS_FILE)
    
    print("="*60)
    print("Add Missing Words to Dictionary Database")
    print("="*60)
    print(f"Database: {database_path}")
    print(f"Words file: {words_file}")
    print(f"AI Model: {MODEL_NAME} @ {LM_STUDIO_URL}")
    print(f"Workers: {MAX_WORKERS} | Batch size: {BATCH_SIZE}")
    print("="*60)
    
    # Test AI connection
    print("\nTesting LM Studio connection...")
    test_response = call_ai_model("Respond with only: OK", max_tokens=10)
    if test_response:
        print("✓ LM Studio connected successfully\n")
        add_missing_words(database_path, words_file)
    else:
        print("✗ Cannot connect to LM Studio. Please ensure:")
        print("  1. LM Studio is running")
        print("  2. Server is started on port 1234")
        print(f"  3. Model {MODEL_NAME} is loaded")

