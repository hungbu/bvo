#!/usr/bin/env python3
"""
Update Vietnamese meanings in dictionary.db using AI
- Backup old vi to vi_detail
- Generate new concise Vietnamese meanings using AI
- Process in batches for optimal speed
Run: python update_vi_meanings.py
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
MAX_WORKERS = 1  # Use 1 worker to maintain consistent speed
BATCH_SIZE = 15  # Words per batch (10-20 for optimal speed)
SAVE_INTERVAL = 50  # Save progress every N words
TIMEOUT = 20  # Timeout for each request
REQUEST_DELAY = 0.0  # Delay between requests
MODEL_NAME = "qwen/qwen3-4b-2507"

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

def call_ai_model(prompt, max_tokens=200, retry=1):
    """Call LM Studio AI model - optimized with connection reuse"""
    session = get_session()
    
    for attempt in range(retry + 1):  # retry + 1 = total attempts
        try:
            # Small delay to prevent server overload
            if attempt == 0 and REQUEST_DELAY > 0:
                time.sleep(REQUEST_DELAY)
            
            response = session.post(
                LM_STUDIO_URL,
                json={
                    "model": MODEL_NAME,
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are a Vietnamese dictionary assistant. Return only the Vietnamese meaning, concise and clear. No markdown, no JSON, just plain text."
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
                time.sleep(1)  # Wait before retry
                continue
        except Exception as e:
            if attempt < retry - 1:
                time.sleep(1)
                continue
    
    return None

def generate_new_vi_meaning(word, old_vi, sentence=None, sentence_vi=None):
    """Use AI to generate new concise Vietnamese meaning"""
    
    # Build context
    context_parts = []
    if old_vi:
        # Limit old meaning length
        old_vi_short = old_vi[:300] + "..." if len(old_vi) > 300 else old_vi
        context_parts.append(f"Nghĩa cũ (quá dài): {old_vi_short}")
    
    if sentence:
        context_parts.append(f"Ví dụ tiếng Anh: {sentence}")
    
    if sentence_vi:
        context_parts.append(f"Ví dụ tiếng Việt: {sentence_vi}")
    
    context = "\n".join(context_parts)
    
    # Prompt ngắn gọn để AI tạo nghĩa mới ngắn gọn hơn
    prompt = f"""Từ tiếng Anh: {word}

{context}

Hãy tạo nghĩa tiếng Việt NGẮN GỌN, SÚC TÍCH (tối đa 50 từ) cho từ này. Chỉ trả về nghĩa tiếng Việt, không giải thích thêm."""

    ai_response = call_ai_model(prompt, max_tokens=150)
    
    if ai_response:
        # Clean response - remove markdown, extra whitespace
        clean_response = re.sub(r'```[a-z]*\s*', '', ai_response)
        clean_response = re.sub(r'```\s*', '', clean_response)
        clean_response = re.sub(r'\s+', ' ', clean_response)
        clean_response = clean_response.strip()
        
        # Remove common prefixes AI might add
        prefixes_to_remove = [
            r'^Nghĩa tiếng Việt:\s*',
            r'^Nghĩa:\s*',
            r'^Vietnamese meaning:\s*',
            r'^Meaning:\s*',
        ]
        for prefix in prefixes_to_remove:
            clean_response = re.sub(prefix, '', clean_response, flags=re.IGNORECASE)
        
        # Limit length to 200 characters
        if len(clean_response) > 200:
            clean_response = clean_response[:200].rsplit(' ', 1)[0] + "..."
        
        if clean_response:
            return clean_response
    
    # Fallback: use first 100 chars of old meaning
    if old_vi:
        return old_vi[:100] + "..." if len(old_vi) > 100 else old_vi
    
    return ""

def ensure_column_exists(conn, column_name):
    """Ensure column exists in words table"""
    cursor = conn.cursor()
    try:
        # Check if column exists
        cursor.execute(f"PRAGMA table_info(words)")
        columns = [row[1] for row in cursor.fetchall()]
        
        if column_name not in columns:
            print(f"Adding column {column_name}...")
            cursor.execute(f"ALTER TABLE words ADD COLUMN {column_name} TEXT")
            conn.commit()
            print(f"✓ Column {column_name} added")
            return True
        return False
    except Exception as e:
        print(f"Error checking/adding column {column_name}: {e}")
        return False

def backup_old_meanings(conn):
    """Backup old vi to vi_detail for all words"""
    cursor = conn.cursor()
    
    # Ensure vi_detail column exists
    ensure_column_exists(conn, "vi_detail")
    
    # Check if backup already done
    cursor.execute("SELECT COUNT(*) FROM words WHERE vi_detail IS NOT NULL AND vi_detail != ''")
    backed_up_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM words WHERE vi IS NOT NULL AND vi != ''")
    total_with_vi = cursor.fetchone()[0]
    
    if backed_up_count == total_with_vi and backed_up_count > 0:
        print(f"✓ Backup already exists: {backed_up_count} words")
        return backed_up_count
    
    print(f"Backing up old meanings to vi_detail...")
    cursor.execute("""
        UPDATE words 
        SET vi_detail = vi 
        WHERE vi IS NOT NULL AND vi != '' 
        AND (vi_detail IS NULL OR vi_detail = '')
    """)
    backed_up = cursor.rowcount
    conn.commit()
    
    print(f"✓ Backed up {backed_up} words to vi_detail")
    return backed_up

def process_word_batch(word_batch, conn, counter, db_lock):
    """Process a batch of words (thread-safe)"""
    results = []
    
    for word_row in word_batch:
        word_id, word, old_vi, sentence, sentence_vi = word_row
        
        try:
            # Generate new meaning
            new_vi = generate_new_vi_meaning(word, old_vi, sentence, sentence_vi)
            
            if new_vi:
                results.append((word_id, new_vi, True))
            else:
                results.append((word_id, None, False))
                
        except Exception as e:
            print(f"\nError processing {word}: {e}")
            results.append((word_id, None, False))
    
    # Update database
    with db_lock:
        cursor = conn.cursor()
        for word_id, new_vi, success in results:
            if success and new_vi:
                try:
                    cursor.execute("""
                        UPDATE words 
                        SET vi = ?, updated_at = ?
                        WHERE id = ?
                    """, (new_vi, datetime.now().isoformat(), word_id))
                except Exception as e:
                    print(f"\nError updating word ID {word_id}: {e}")
                    success = False
        
        conn.commit()
    
    # Update counter
    for _, _, success in results:
        counter.increment(success)
    
    return len([r for r in results if r[2]])

def update_vi_meanings(database_path, resume=True):
    """Update Vietnamese meanings in database"""
    
    # Connect to database
    conn = sqlite3.connect(database_path, check_same_thread=False)
    cursor = conn.cursor()
    
    # Ensure vi_detail column exists and backup old meanings
    backup_old_meanings(conn)
    
    # Get words to process
    if resume:
        # Skip words that already have updated vi (vi is different from vi_detail and shorter)
        # Process words where: vi_detail exists but vi hasn't been updated yet (vi == vi_detail or vi is longer)
        cursor.execute("""
            SELECT id, en, vi, sentence, sentenceVi 
            FROM words 
            WHERE vi IS NOT NULL AND vi != ''
            AND (
                vi_detail IS NULL 
                OR vi_detail = '' 
                OR vi = vi_detail 
                OR LENGTH(vi) > LENGTH(vi_detail)
            )
            ORDER BY id
        """)
    else:
        # Process all words
        cursor.execute("""
            SELECT id, en, vi, sentence, sentenceVi 
            FROM words 
            WHERE vi IS NOT NULL AND vi != ''
            ORDER BY id
        """)
    
    words_to_process = cursor.fetchall()
    total_words = len(words_to_process)
    
    if total_words == 0:
        print("No words to process!")
        conn.close()
        return
    
    # Initialize progress counter
    counter = ProgressCounter(total_words)
    
    print(f"\nTotal words to process: {total_words}")
    print(f"Batch size: {BATCH_SIZE} words per batch")
    print(f"Using {MAX_WORKERS} worker(s) with connection reuse\n")
    
    # Thread lock for database writes
    db_lock = threading.Lock()
    
    # Process words in batches
    save_counter = 0
    
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = []
        
        # Submit batches
        for i in range(0, total_words, BATCH_SIZE):
            batch = words_to_process[i:i + BATCH_SIZE]
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
                print_progress(counter.get_stats())
                
            except Exception as e:
                print(f"\nError processing batch: {e}")
                print_progress(counter.get_stats())
    
    # Final commit
    with db_lock:
        conn.commit()
    
    # Final statistics
    print("\n\n" + "="*60)
    stats = counter.get_stats()
    elapsed = time.time() - counter.start_time
    
    # Get final counts
    cursor.execute("SELECT COUNT(*) FROM words WHERE vi IS NOT NULL AND vi != ''")
    total_with_vi = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM words WHERE vi_detail IS NOT NULL AND vi_detail != ''")
    total_backed_up = cursor.fetchone()[0]
    
    print(f"✓ Update complete!")
    print(f"✓ Total words with Vietnamese meaning: {total_with_vi}")
    print(f"✓ Words backed up to vi_detail: {total_backed_up}")
    print(f"✓ Processed in this run: {stats['processed']}")
    print(f"✓ Success: {stats['success']}")
    print(f"✓ Failed: {stats['failed']}")
    print(f"✓ Time taken: {int(elapsed/60)}m {int(elapsed%60)}s")
    if stats['processed'] > 0:
        print(f"✓ Average speed: {stats['rate']:.2f} words/second")
    print("="*60)
    
    # Show samples
    cursor.execute('''
        SELECT en, vi, vi_detail 
        FROM words 
        WHERE vi IS NOT NULL AND vi != ''
        ORDER BY RANDOM() 
        LIMIT 5
    ''')
    print("\nSample entries (new meaning | old meaning):")
    for row in cursor.fetchall():
        word, new_vi, old_vi = row
        print(f"  {word}")
        print(f"    → Mới: {new_vi[:80]}...")
        if old_vi:
            print(f"    → Cũ: {old_vi[:80]}...")
        print()
    
    conn.close()

if __name__ == '__main__':
    database_path = 'dictionary.db'
    
    print("="*60)
    print("Update Vietnamese Meanings - AI Enhanced")
    print("="*60)
    print(f"Database: {database_path}")
    print(f"AI Model: {MODEL_NAME} @ {LM_STUDIO_URL}")
    print(f"Workers: {MAX_WORKERS} worker(s)")
    print(f"Batch size: {BATCH_SIZE} words per batch")
    print("="*60 + "\n")
    
    # Test AI connection
    print("Testing LM Studio connection...")
    test_response = call_ai_model("Respond with only: OK", max_tokens=10)
    if test_response:
        print("✓ LM Studio connected successfully\n")
        update_vi_meanings(database_path, resume=True)
    else:
        print("✗ Cannot connect to LM Studio. Please ensure:")
        print("  1. LM Studio is running")
        print("  2. Server is started on port 1234")
        print(f"  3. Model {MODEL_NAME} is loaded")

