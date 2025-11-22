#!/usr/bin/env python3
"""
Convert edict.db to SQLite format compatible with Flutter dictionary app
Features: Progress bar, Resume capability, Parallel processing
Run: python convert_to_dword.py
"""

import sqlite3
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import json
import re
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading
import time
import sys

# Configuration
LM_STUDIO_URL = "http://localhost:1234/v1/chat/completions"
MAX_WORKERS = 1  # Use 1 worker to maintain consistent speed (avoids server throttling)
BATCH_SIZE = 200  # Words to fetch from database at once
SAVE_INTERVAL = 100  # Save progress every N words
TIMEOUT = 20  # Timeout for each request
REQUEST_DELAY = 0.0  # Delay between requests (0 = no delay, set > 0 if server throttles)
# Using 1 worker with connection reuse maintains consistent speed over time

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

def print_progress(stats):
    """Print beautiful progress bar"""
    percent = stats['percent']
    bar_length = 40
    filled = int(bar_length * percent / 100)
    bar = '█' * filled + '░' * (bar_length - filled)
    
    # Format time
    remaining_min = int(stats['remaining'] / 60)
    remaining_sec = int(stats['remaining'] % 60)
    
    sys.stdout.write(f'\r[{bar}] {percent:.1f}% | '
                    f'{stats["processed"]}/{stats["total"]} | '
                    f'✓ {stats["success"]} ✗ {stats["failed"]} | '
                    f'{stats["rate"]:.1f} words/s | '
                    f'ETA: {remaining_min}m {remaining_sec}s')
    sys.stdout.flush()

# Thread-local storage for HTTP sessions (connection reuse)
_thread_local = threading.local()

def get_session():
    """Get or create a thread-local HTTP session with connection pooling"""
    if not hasattr(_thread_local, 'session'):
        session = requests.Session()
        # Configure retry strategy
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
    """Call LM Studio AI model - optimized with connection reuse for consistent speed"""
    session = get_session()
    
    for attempt in range(retry + 1):  # retry + 1 = total attempts
        try:
            # Small delay to prevent server overload
            if attempt == 0 and REQUEST_DELAY > 0:
                time.sleep(REQUEST_DELAY)
            
            response = session.post(
                LM_STUDIO_URL,
                json={
                    "model": "google/gemma-3n-e4b",
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
                    "temperature": 0.1,  # Giảm xuống 0.1 để nhanh và deterministic hơn
                    "max_tokens": max_tokens,  # Giảm xuống 300 để nhanh hơn
                    "stream": False  # Đảm bảo không stream
                },
                timeout=TIMEOUT
            )
            
            if response.status_code == 200:
                result = response.json()
                return result['choices'][0]['message']['content']
            elif attempt < retry - 1:
                time.sleep(1)  # Wait before retry
                continue
        except Exception as e:
            if attempt < retry - 1:
                time.sleep(1)
                continue
    
    return None

def clean_html_detail(html_detail):
    """Remove HTML tags from detail"""
    text = re.sub(r'<[^>]+>', '\n', html_detail)
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def parse_word_with_ai(word, detail_html):
    """Use AI to convert dictionary entry to required JSON format - optimized prompt"""
    
    clean_text = clean_html_detail(detail_html)
    # Giới hạn độ dài text để prompt ngắn hơn, nhanh hơn
    if len(clean_text) > 500:
        clean_text = clean_text[:500] + "..."
    
    # Prompt ngắn gọn hơn để AI xử lý nhanh hơn
    prompt = f"""Word: {word}
Entry: {clean_text}

Return JSON only:
{{"en":"{word}","vi":"Vietnamese meaning","pronunciation":"IPA or empty","sentence":"English example","sentenceVi":"Vietnamese example","topic":"general","level":"INTERMEDIATE","type":"noun","difficulty":3,"isKidFriendly":true,"mnemonicTip":"","tags":[],"synonyms":[],"antonyms":[]}}"""

    ai_response = call_ai_model(prompt, max_tokens=300)  # Giảm tokens để nhanh hơn
    
    if ai_response:
        try:
            clean_response = re.sub(r'```json\s*', '', ai_response)
            clean_response = re.sub(r'```\s*', '', clean_response)
            clean_response = clean_response.strip()
            
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
                    "level": parsed.get("level", "INTERMEDIATE"),
                    "type": parsed.get("type", "word"),
                    "difficulty": int(parsed.get("difficulty", 3)),
                    "isKidFriendly": parsed.get("isKidFriendly", False),
                    "mnemonicTip": parsed.get("mnemonicTip", ""),
                    "tags": parsed.get("tags", []),
                    "synonyms": parsed.get("synonyms", []),
                    "antonyms": parsed.get("antonyms", [])
                }
                return word_data, None
        except Exception as e:
            return None, str(e)
    
    # Fallback
    return {
        "en": word,
        "vi": clean_text[:200],
        "pronunciation": "",
        "sentence": "",
        "sentenceVi": "",
        "topic": "general",
        "level": "INTERMEDIATE",
        "type": "word",
        "difficulty": 3,
        "isKidFriendly": False,
        "mnemonicTip": "",
        "tags": [],
        "synonyms": [],
        "antonyms": []
    }, "fallback"

def ensure_sqlite_type(value):
    """Convert value to SQLite-compatible type"""
    if value is None:
        return None
    if isinstance(value, (str, int, float, bytes)):
        return value
    if isinstance(value, (dict, list)):
        return json.dumps(value) if value else None
    # Convert everything else to string
    return str(value) if value else None

def process_word(word_row, target_conn, processed_words_set):
    """Process a single word (thread-safe) - skip if already processed"""
    idx, word, detail_html = word_row
    
    # Skip if already processed
    if word in processed_words_set:
        return True
    
    current_time = datetime.now().isoformat()
    
    word_data, error = parse_word_with_ai(word, detail_html)
    
    if word_data:
        cursor = target_conn.cursor()
        try:
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
            ensure_sqlite_type(word_data.get('level', 'INTERMEDIATE')),
            ensure_sqlite_type(word_data.get('type', 'word')),
            int(word_data.get('difficulty', 3)),
            1 if word_data.get('isKidFriendly', False) else 0,
            ensure_sqlite_type(word_data.get('mnemonicTip', '')),
            json.dumps(word_data.get('tags', [])),
            0,  # reviewCount
            None,  # nextReview
            0.0,  # masteryLevel
            None,  # lastReviewed
            0,  # correctAnswers
            0,  # totalAttempts
            1,  # currentInterval
            2.5,  # easeFactor
            json.dumps(word_data.get('synonyms', [])),
            json.dumps(word_data.get('antonyms', [])),
            current_time,
            current_time
            ))
            processed_words_set.add(word)  # Mark as processed
            return True
        except sqlite3.IntegrityError:
            # Word already exists, skip
            processed_words_set.add(word)
            return True
        except Exception as e:
            print(f"\nError inserting {word}: {e}")
            return False
    
    return False

def get_processed_words_set(target_conn):
    """Get set of already processed words for resume capability"""
    try:
        cursor = target_conn.cursor()
        cursor.execute('SELECT en FROM words')
        return set(row[0] for row in cursor.fetchall())
    except:
        return set()

def create_dictionary_database(input_db, output_db, resume=True):
    """Create new SQLite database with parallel processing"""
    
    # Connect to databases
    source_conn = sqlite3.connect(input_db)
    source_cursor = source_conn.cursor()
    
    target_conn = sqlite3.connect(output_db, check_same_thread=False)
    target_cursor = target_conn.cursor()
    
    # Create table
    target_cursor.execute('''
        CREATE TABLE IF NOT EXISTS words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            en TEXT NOT NULL UNIQUE,
            vi TEXT,
            pronunciation TEXT,
            sentence TEXT,
            sentenceVi TEXT,
            topic TEXT,
            level TEXT,
            type TEXT,
            difficulty INTEGER,
            isKidFriendly INTEGER,
            mnemonicTip TEXT,
            tags TEXT,
            reviewCount INTEGER DEFAULT 0,
            nextReview TEXT,
            masteryLevel REAL DEFAULT 0.0,
            lastReviewed TEXT,
            correctAnswers INTEGER DEFAULT 0,
            totalAttempts INTEGER DEFAULT 0,
            currentInterval INTEGER DEFAULT 1,
            easeFactor REAL DEFAULT 2.5,
            synonyms TEXT,
            antonyms TEXT,
            created_at TEXT,
            updated_at TEXT
        )
    ''')
    
    # Create indexes
    target_cursor.execute('CREATE INDEX IF NOT EXISTS idx_word_en ON words(en)')
    target_cursor.execute('CREATE INDEX IF NOT EXISTS idx_word_level ON words(level)')
    target_cursor.execute('CREATE INDEX IF NOT EXISTS idx_word_topic ON words(topic)')
    target_cursor.execute('CREATE INDEX IF NOT EXISTS idx_word_difficulty ON words(difficulty)')
    
    target_conn.commit()
    
    # Get counts
    source_cursor.execute('SELECT COUNT(*) FROM tbl_edict')
    total_words = source_cursor.fetchone()[0]
    
    # Get already processed words for resume
    processed_words_set = set()
    if resume:
        processed_words_set = get_processed_words_set(target_conn)
        processed_count = len(processed_words_set)
        if processed_count > 0:
            print(f"\n📌 Found {processed_count} already processed words")
            print(f"📌 Will skip duplicates and continue from where left off\n")
    
    # Initialize progress counter
    counter = ProgressCounter(total_words)
    
    print(f"Total words in source: {total_words}")
    print(f"Already processed: {len(processed_words_set)}")
    print(f"Remaining: {total_words - len(processed_words_set)}")
    print(f"Using {MAX_WORKERS} worker(s) with connection reuse for consistent speed\n")
    
    # Thread lock for database writes
    db_lock = threading.Lock()
    
    # Process all words, skip already processed ones
    source_cursor.execute('SELECT idx, word, detail FROM tbl_edict ORDER BY idx')
    
    save_counter = 0
    
    # Use ThreadPoolExecutor for parallel processing (4 workers optimal)
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        while True:
            batch = source_cursor.fetchmany(BATCH_SIZE)
            if not batch:
                break
            
            futures = []
            for word_row in batch:
                # Skip if already processed
                if word_row[1] not in processed_words_set:
                    future = executor.submit(process_word, word_row, target_conn, processed_words_set)
                    futures.append(future)
                else:
                    # Already processed, just increment counter
                    counter.increment(True)
                    print_progress(counter.get_stats())
            
            for future in as_completed(futures):
                try:
                    success = future.result()
                    counter.increment(success)
                    save_counter += 1
                    
                    # Save progress periodically
                    if save_counter >= SAVE_INTERVAL:
                        with db_lock:
                            target_conn.commit()
                        save_counter = 0
                    
                    # Update progress bar
                    print_progress(counter.get_stats())
                    
                except Exception as e:
                    print(f"\nError processing word: {e}")
                    counter.increment(False)
                    print_progress(counter.get_stats())
    
    # Final commit
    with db_lock:
        target_conn.commit()
    
    # Final statistics
    print("\n\n" + "="*60)
    target_cursor.execute('SELECT COUNT(*) FROM words')
    word_count = target_cursor.fetchone()[0]
    
    stats = counter.get_stats()
    elapsed = time.time() - counter.start_time
    
    print(f"✓ Conversion complete!")
    print(f"✓ Total words in database: {word_count}")
    print(f"✓ Processed in this run: {stats['processed']}")
    print(f"✓ Success: {stats['success']}")
    print(f"✓ Failed: {stats['failed']}")
    print(f"✓ Time taken: {int(elapsed/60)}m {int(elapsed%60)}s")
    if stats['processed'] > 0:
        print(f"✓ Average speed: {stats['rate']:.2f} words/second")
        remaining_time = (total_words - word_count) / stats['rate'] if stats['rate'] > 0 else 0
        print(f"✓ Estimated remaining time: {int(remaining_time/60)}m {int(remaining_time%60)}s")
    print(f"✓ Output: {output_db}")
    print("="*60)
    
    # Show samples
    target_cursor.execute('''
        SELECT en, vi, pronunciation, type, level 
        FROM words 
        ORDER BY RANDOM() 
        LIMIT 5
    ''')
    print("\nSample entries:")
    for row in target_cursor.fetchall():
        print(f"  [{row[4]}] {row[0]} [{row[2]}] ({row[3]})")
        print(f"    → {row[1][:60]}...")
    
    source_conn.close()
    target_conn.close()

if __name__ == '__main__':
    input_database = 'edict.db'
    output_database = 'dictionary.db'
    
    print("="*60)
    print("Dictionary Converter - Enhanced Version")
    print("="*60)
    print(f"Input:  {input_database}")
    print(f"Output: {output_database}")
    print(f"AI Model: google/gemma-3n-e4b @ {LM_STUDIO_URL}")
    print(f"Workers: {MAX_WORKERS} worker(s) with connection reuse")
    print(f"Strategy: Maintain consistent speed over time (avoid server throttling)")
    print("="*60 + "\n")
    
    # Test AI connection
    print("Testing LM Studio connection...")
    test_response = call_ai_model("Respond with only: OK", max_tokens=10)
    if test_response:
        print("✓ LM Studio connected successfully\n")
        create_dictionary_database(input_database, output_database, resume=True)
    else:
        print("✗ Cannot connect to LM Studio. Please ensure:")
        print("  1. LM Studio is running")
        print("  2. Server is started on port 1234")
        print("  3. Model google/gemma-3n-e4b is loaded")