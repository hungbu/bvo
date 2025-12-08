#!/usr/bin/env python3
"""
Update Vietnamese meanings in dictionary.db using AI
- Process 1000 priority words from 1000.txt first
- Then process remaining words in database
- Support resume to continue from where it stopped
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
import os

# Configuration
LM_STUDIO_URL = "http://localhost:1234/v1/chat/completions"
MAX_WORKERS = 1  # Use 1 worker to maintain consistent speed
BATCH_SIZE = 15  # Words per batch (10-20 for optimal speed)
SAVE_INTERVAL = 50  # Save progress every N words
TIMEOUT = 20  # Timeout for each request
REQUEST_DELAY = 0.0  # Delay between requests
MODEL_NAME = "qwen/qwen3-4b-2507"
PRIORITY_WORDS_FILE = "1000.txt"  # File containing priority words

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

def load_priority_words(filepath):
    """Load priority words from file (comma-separated or one per line)"""
    if not os.path.exists(filepath):
        print(f"⚠ Priority file not found: {filepath}")
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
        
        print(f"✓ Loaded {len(words)} priority words from {filepath}")
        return words
    except Exception as e:
        print(f"✗ Error loading priority words: {e}")
        return []

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

def get_words_to_process(conn, priority_words=None):
    """Get words to process based on priority list and resume capability"""
    cursor = conn.cursor()
    
    # Words that need updating: vi hasn't been shortened yet
    base_condition = """
        vi IS NOT NULL AND vi != ''
        AND (
            vi_detail IS NULL 
            OR vi_detail = '' 
            OR vi = vi_detail 
            OR LENGTH(vi) > LENGTH(vi_detail)
        )
    """
    
    if priority_words:
        # Get priority words that need updating
        placeholders = ','.join(['?'] * len(priority_words))
        cursor.execute(f"""
            SELECT id, en, vi, sentence, sentenceVi 
            FROM words 
            WHERE LOWER(en) IN ({placeholders})
            AND {base_condition}
            ORDER BY id
        """, priority_words)
        priority_batch = cursor.fetchall()
        
        # Get remaining words (excluding priority words)
        cursor.execute(f"""
            SELECT id, en, vi, sentence, sentenceVi 
            FROM words 
            WHERE LOWER(en) NOT IN ({placeholders})
            AND {base_condition}
            ORDER BY id
        """, priority_words)
        remaining_batch = cursor.fetchall()
        
        return priority_batch, remaining_batch
    else:
        # Get all words that need updating
        cursor.execute(f"""
            SELECT id, en, vi, sentence, sentenceVi 
            FROM words 
            WHERE {base_condition}
            ORDER BY id
        """)
        all_words = cursor.fetchall()
        return all_words, []

def process_batch(words_batch, conn, phase_name):
    """Process a batch of words with progress tracking"""
    if not words_batch:
        print(f"\n✓ No words to process in {phase_name}")
        return 0
    
    total_words = len(words_batch)
    counter = ProgressCounter(total_words)
    db_lock = threading.Lock()
    
    print(f"\n{'='*60}")
    print(f"{phase_name}")
    print(f"{'='*60}")
    print(f"Words to process: {total_words}")
    print(f"Batch size: {BATCH_SIZE} | Workers: {MAX_WORKERS}\n")
    
    save_counter = 0
    
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = []
        
        # Submit batches
        for i in range(0, total_words, BATCH_SIZE):
            batch = words_batch[i:i + BATCH_SIZE]
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
                print_progress(counter.get_stats(), phase_name)
                
            except Exception as e:
                print(f"\nError processing batch: {e}")
                print_progress(counter.get_stats(), phase_name)
    
    # Final commit
    with db_lock:
        conn.commit()
    
    # Phase statistics
    stats = counter.get_stats()
    elapsed = time.time() - counter.start_time
    
    print(f"\n\n✓ {phase_name} complete!")
    print(f"  Processed: {stats['processed']} | Success: {stats['success']} | Failed: {stats['failed']}")
    print(f"  Time: {int(elapsed/60)}m {int(elapsed%60)}s | Speed: {stats['rate']:.2f} words/s\n")
    
    return stats['success']

def update_vi_meanings(database_path):
    """Update Vietnamese meanings in database with priority words first"""
    
    # Connect to database
    conn = sqlite3.connect(database_path, check_same_thread=False)
    
    # Ensure vi_detail column exists and backup old meanings
    backup_old_meanings(conn)
    
    # Load priority words
    priority_words = load_priority_words(PRIORITY_WORDS_FILE)
    
    # Get words to process
    if priority_words:
        priority_batch, remaining_batch = get_words_to_process(conn, priority_words)
    else:
        all_words, _ = get_words_to_process(conn, None)
        priority_batch = []
        remaining_batch = all_words
    
    total_priority = len(priority_batch)
    total_remaining = len(remaining_batch)
    total_all = total_priority + total_remaining
    
    if total_all == 0:
        print("\n✓ All words are already updated!")
        conn.close()
        return
    
    print(f"\n{'='*60}")
    print("PROCESSING PLAN")
    print(f"{'='*60}")
    print(f"Priority words (from {PRIORITY_WORDS_FILE}): {total_priority}")
    print(f"Remaining words: {total_remaining}")
    print(f"Total words to process: {total_all}")
    print(f"{'='*60}")
    
    # Phase 1: Process priority words
    priority_success = 0
    if total_priority > 0:
        priority_success = process_batch(priority_batch, conn, "PHASE 1: Priority Words")
    
    # Phase 2: Process remaining words
    remaining_success = 0
    if total_remaining > 0:
        remaining_success = process_batch(remaining_batch, conn, "PHASE 2: Remaining Words")
    
    # Final statistics
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM words WHERE vi IS NOT NULL AND vi != ''")
    total_with_vi = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM words WHERE vi_detail IS NOT NULL AND vi_detail != ''")
    total_backed_up = cursor.fetchone()[0]
    
    print(f"\n{'='*60}")
    print("FINAL SUMMARY")
    print(f"{'='*60}")
    print(f"✓ Priority words processed: {priority_success}/{total_priority}")
    print(f"✓ Remaining words processed: {remaining_success}/{total_remaining}")
    print(f"✓ Total success: {priority_success + remaining_success}/{total_all}")
    print(f"✓ Total words in database: {total_with_vi}")
    print(f"✓ Backed up to vi_detail: {total_backed_up}")
    print(f"{'='*60}")
    
    # Show samples
    cursor.execute('''
        SELECT en, vi, vi_detail 
        FROM words 
        WHERE vi IS NOT NULL AND vi != ''
        AND vi_detail IS NOT NULL AND vi_detail != ''
        ORDER BY RANDOM() 
        LIMIT 5
    ''')
    print("\nSample updated entries:")
    for row in cursor.fetchall():
        word, new_vi, old_vi = row
        print(f"  {word}")
        print(f"    → New: {new_vi[:80]}...")
        print(f"    → Old: {old_vi[:80]}...")
        print()
    
    conn.close()

if __name__ == '__main__':
    database_path = 'dictionary.db'
    
    print("="*60)
    print("Update Vietnamese Meanings - AI Enhanced")
    print("="*60)
    print(f"Database: {database_path}")
    print(f"Priority file: {PRIORITY_WORDS_FILE}")
    print(f"AI Model: {MODEL_NAME} @ {LM_STUDIO_URL}")
    print(f"Workers: {MAX_WORKERS} | Batch size: {BATCH_SIZE}")
    print("="*60 + "\n")
    
    # Test AI connection
    print("Testing LM Studio connection...")
    test_response = call_ai_model("Respond with only: OK", max_tokens=10)
    if test_response:
        print("✓ LM Studio connected successfully\n")
        update_vi_meanings(database_path)
    else:
        print("✗ Cannot connect to LM Studio. Please ensure:")
        print("  1. LM Studio is running")
        print("  2. Server is started on port 1234")
        print(f"  3. Model {MODEL_NAME} is loaded")