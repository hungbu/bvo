#!/usr/bin/env python3
"""
Update Vietnamese meanings in dictionary.db using OpenRouter API (Gemma 3)
- Only update words with meanings longer than 6 words
- Process in smart batches (100 words per batch)
- Support resume on error
- Track progress with SQLite status table

Run: python update_vi_with_openrouter.py

Requirements:
    pip install openai
"""

import sqlite3
import re
import time
import sys
import os
from datetime import datetime
from typing import Optional, List, Tuple
import json
from openai import OpenAI

# ============================================================================
# CONFIGURATION
# ============================================================================

# OpenRouter API Configuration
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "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")
OPENROUTER_MODEL = "google/gemma-3-27b-it:free"
YOUR_SITE_URL = "https://github.com/hungbu/bvo"
YOUR_SITE_NAME = "BVO Dictionary Manager"

# Processing Configuration
BATCH_SIZE = 150  # Increased batch size (100 -> 150) to minimize requests
MAX_WORDS_THRESHOLD = 6  
MAX_REQUESTS_PER_DAY = 950  # Stay under OpenRouter 1000 requests/day limit
SAVE_INTERVAL = 150  
REQUEST_DELAY = 1.0  # Stable delay

# Database
DATABASE_PATH = "dictionary.db"
PROGRESS_TABLE = "vi_update_progress"

# ============================================================================
# OPENROUTER API CLIENT
# ============================================================================

def init_client():
    """Initialize OpenRouter client"""
    if OPENROUTER_API_KEY == "YOUR_API_KEY_HERE" or not OPENROUTER_API_KEY:
        print("\n❌ Please set OPENROUTER_API_KEY environment variable or edit the script")
        sys.exit(1)
        
    client = OpenAI(
        base_url="https://openrouter.ai/api/v1",
        api_key=OPENROUTER_API_KEY,
    )
    return client


def call_ai_batch(client, words_batch: List[Tuple[int, str, str]]) -> dict:
    """
    Call OpenRouter API with a batch of words.
    
    Args:
        client: OpenAI client instance
        words_batch: List of (id, en, vi) tuples
    
    Returns:
        Dict mapping word_id to new Vietnamese meaning
    """
    # Build batch prompt
    words_list = []
    for word_id, en, vi in words_batch:
        words_list.append(f"{word_id}|{en}|{vi[:200]}")  # Truncate long meanings
    
    batch_text = "\n".join(words_list)
    
    prompt = f"""Bạn là trợ lý từ điển Anh-Việt chuyên nghiệp. Nhiệm vụ: Tối ưu lại nghĩa tiếng Việt để ngắn gọn và súc tích hơn.

YÊU CẦU:
1. Mỗi nghĩa tiếng Việt mới phải NGẮN GỌN (tối đa 4-6 từ).
2. Giữ nguyên nghĩa chính, loại bỏ các diễn giải dài dòng.
3. Chỉ trả về kết quả theo định dạng: ID|nghĩa mới
4. Mỗi từ một dòng. KHÔNG giải thích gì thêm.

DANH SÁCH TỪ (ID|Từ tiếng Anh|Nghĩa hiện tại):
{batch_text}

KẾT QUẢ (ID|nghĩa mới):"""

    try:
        completion = client.chat.completions.create(
            extra_headers={
                "HTTP-Referer": YOUR_SITE_URL,
                "X-Title": YOUR_SITE_NAME,
            },
            model=OPENROUTER_MODEL,
            messages=[
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            temperature=0.1,
        )
        
        response_text = completion.choices[0].message.content
        
        # Parse response
        results = {}
        if response_text:
            for line in response_text.strip().split("\n"):
                line = line.strip()
                if "|" in line:
                    parts = line.split("|", 1)
                    if len(parts) == 2:
                        try:
                            word_id_str = re.sub(r'^\D*', '', parts[0].strip())
                            if word_id_str:
                                word_id = int(word_id_str)
                                new_vi = parts[1].strip()
                                # Basic cleanup
                                new_vi = re.sub(r'^[\d\.\-\)\:]+\s*', '', new_vi)
                                new_vi = new_vi.strip('"\'')
                                if new_vi and len(new_vi) > 1:
                                    results[word_id] = new_vi
                        except ValueError:
                            continue
        
        return results
    
    except Exception as e:
        print(f"\n❌ OpenRouter API error: {e}")
        return {}


# ============================================================================
# DATABASE HELPERS
# ============================================================================

def ensure_progress_table(conn):
    """Create progress tracking table if not exists"""
    cursor = conn.cursor()
    cursor.execute(f"""
        CREATE TABLE IF NOT EXISTS {PROGRESS_TABLE} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER UNIQUE,
            status TEXT DEFAULT 'pending',
            old_vi TEXT,
            new_vi TEXT,
            updated_at TEXT,
            error TEXT
        )
    """)
    conn.commit()


def count_words_in_text(text: str) -> int:
    """Count number of words in text"""
    if not text:
        return 0
    # Split by spaces and filter empty strings
    words = [w for w in text.split() if w.strip()]
    return len(words)


def get_words_to_process(conn, limit: Optional[int] = None) -> List[Tuple]:
    """
    Get words that need processing:
    - vi has more than MAX_WORDS_THRESHOLD words
    - Haven't been processed yet (not in progress table with status='done')
    """
    cursor = conn.cursor()
    
    # First, ensure progress table exists
    ensure_progress_table(conn)
    
    # Get words with long vi that haven't been processed
    query = f"""
        SELECT w.id, w.en, w.vi
        FROM words w
        LEFT JOIN {PROGRESS_TABLE} p ON w.id = p.word_id AND p.status = 'done'
        WHERE w.vi IS NOT NULL 
        AND w.vi != ''
        AND p.word_id IS NULL
        ORDER BY w.id
    """
    
    if limit:
        query += f" LIMIT {limit}"
    
    cursor.execute(query)
    all_words = cursor.fetchall()
    
    # Filter by word count (do this in Python since SQLite doesn't have good word counting)
    words_to_process = []
    for word_id, en, vi in all_words:
        word_count = count_words_in_text(vi)
        if word_count > MAX_WORDS_THRESHOLD:
            words_to_process.append((word_id, en, vi))
    
    return words_to_process


def save_progress(conn, word_id: int, old_vi: str, new_vi: str, status: str = "done", error: str = None):
    """Save progress for a word"""
    cursor = conn.cursor()
    cursor.execute(f"""
        INSERT OR REPLACE INTO {PROGRESS_TABLE} (word_id, status, old_vi, new_vi, updated_at, error)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (word_id, status, old_vi, new_vi, datetime.now().isoformat(), error))


def update_word_vi(conn, word_id: int, new_vi: str):
    """Update vi meaning in words table"""
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE words 
        SET vi = ?, updated_at = ?
        WHERE id = ?
    """, (new_vi, datetime.now().isoformat(), word_id))


def backup_vi_to_vi_detail(conn):
    """Backup vi to vi_detail if not already done"""
    cursor = conn.cursor()
    
    # Check if vi_detail column exists
    cursor.execute("PRAGMA table_info(words)")
    columns = [row[1] for row in cursor.fetchall()]
    
    if "vi_detail" not in columns:
        print("📦 Adding vi_detail column...")
        cursor.execute("ALTER TABLE words ADD COLUMN vi_detail TEXT")
        conn.commit()
    
    # Backup vi to vi_detail where vi_detail is empty
    cursor.execute("""
        UPDATE words 
        SET vi_detail = vi 
        WHERE vi IS NOT NULL AND vi != '' 
        AND (vi_detail IS NULL OR vi_detail = '')
    """)
    backed_up = cursor.rowcount
    conn.commit()
    
    if backed_up > 0:
        print(f"✅ Backed up {backed_up} words to vi_detail")
    else:
        print("✅ Backup already exists")


def get_statistics(conn) -> dict:
    """Get current statistics"""
    cursor = conn.cursor()
    
    # Ensure progress table exists
    ensure_progress_table(conn)
    
    # Total words with vi
    cursor.execute("SELECT COUNT(*) FROM words WHERE vi IS NOT NULL AND vi != ''")
    total_words = cursor.fetchone()[0]
    
    # Words in progress table
    cursor.execute(f"SELECT COUNT(*) FROM {PROGRESS_TABLE} WHERE status = 'done'")
    processed = cursor.fetchone()[0]
    
    cursor.execute(f"SELECT COUNT(*) FROM {PROGRESS_TABLE} WHERE status = 'error'")
    errors = cursor.fetchone()[0]
    
    # Get words needing processing (with long vi)
    words_to_process = get_words_to_process(conn)
    
    return {
        "total_words": total_words,
        "processed": processed,
        "errors": errors,
        "pending": len(words_to_process)
    }


# ============================================================================
# MAIN PROCESSING
# ============================================================================

def print_progress_bar(current: int, total: int, prefix: str = "", suffix: str = ""):
    """Print a progress bar"""
    if total == 0:
        return
    
    bar_length = 40
    percent = current / total
    filled = int(bar_length * percent)
    bar = "█" * filled + "░" * (bar_length - filled)
    
    sys.stdout.write(f"\r{prefix}[{bar}] {percent*100:.1f}% ({current}/{total}) {suffix}")
    sys.stdout.flush()


def process_words(conn, client, words: List[Tuple], start_time: float):
    """Process a list of words in batches"""
    total = len(words)
    processed = 0
    success = 0
    failed = 0
    request_count = 0
    
    for i in range(0, total, BATCH_SIZE):
        # Respect daily limit
        if request_count >= MAX_REQUESTS_PER_DAY:
            print(f"\n\n🛑 Reached session limit of {MAX_REQUESTS_PER_DAY} requests.")
            print("Please run again tomorrow to continue.")
            break
            
        batch = words[i:i + BATCH_SIZE]
        batch_size = len(batch)
        
        # Call AI API
        print(f"\n📤 Processing batch {i//BATCH_SIZE + 1} ({batch_size} words) | Request {request_count + 1}/{MAX_REQUESTS_PER_DAY}...")
        
        try:
            request_count += 1
            results = call_ai_batch(client, batch)
            
            # Update database
            for word_id, en, old_vi in batch:
                if word_id in results:
                    new_vi = results[word_id]
                    update_word_vi(conn, word_id, new_vi)
                    save_progress(conn, word_id, old_vi, new_vi, "done")
                    success += 1
                else:
                    # Failed to get result for this word
                    save_progress(conn, word_id, old_vi, None, "error", "No result from API")
                    failed += 1
                
                processed += 1
            
            conn.commit()
            
            # Print progress
            elapsed = time.time() - start_time
            rate = processed / elapsed if elapsed > 0 else 0
            remaining = (total - processed) / rate if rate > 0 else 0
            
            print_progress_bar(
                processed, total,
                prefix="📊 ",
                suffix=f"| ✅ {success} ❌ {failed} | {rate:.1f} w/s | ETA: {int(remaining/60)}m"
            )
            
            # Delay to avoid rate limiting for free models
            if i + BATCH_SIZE < total:
                time.sleep(REQUEST_DELAY)
        
        except KeyboardInterrupt:
            print("\n\n⚠️ Interrupted! Progress has been saved. Run again to resume.")
            conn.commit()
            return processed, success, failed
        
        except Exception as e:
            print(f"\n❌ Batch error: {e}")
            # Mark all words in batch as error
            for word_id, en, old_vi in batch:
                save_progress(conn, word_id, old_vi, None, "error", str(e))
                failed += 1
                processed += 1
            conn.commit()
    
    return processed, success, failed


def main():
    """Main entry point"""
    print("=" * 60)
    print("📚 Update Vietnamese Meanings with OpenRouter (Gemma 3)")
    print("=" * 60)
    
    print(f"\n📁 Database: {DATABASE_PATH}")
    print(f"🤖 Model: {OPENROUTER_MODEL}")
    print(f"📦 Batch size: {BATCH_SIZE} words")
    print(f"📏 Processing words with > {MAX_WORDS_THRESHOLD} words in meaning")
    
    # Initialize Client
    print("\n🔌 Connecting to OpenRouter API...")
    client = init_client()
    
    # Test connection
    try:
        completion = client.chat.completions.create(
            extra_headers={
                "HTTP-Referer": YOUR_SITE_URL,
                "X-Title": YOUR_SITE_NAME,
            },
            model=OPENROUTER_MODEL,
            messages=[{"role": "user", "content": "Say OK"}]
        )
        print(f"✅ Connected to OpenRouter: {completion.choices[0].message.content.strip()}")
    except Exception as e:
        print(f"❌ Failed to connect to OpenRouter: {e}")
        sys.exit(1)
    
    # Connect to database
    conn = sqlite3.connect(DATABASE_PATH)
    
    # Backup vi to vi_detail
    print("\n📦 Checking backup...")
    backup_vi_to_vi_detail(conn)
    
    # Get statistics
    print("\n📊 Getting statistics...")
    stats = get_statistics(conn)
    print(f"   Total words: {stats['total_words']}")
    print(f"   Already processed: {stats['processed']}")
    print(f"   Errors: {stats['errors']}")
    print(f"   Pending (> {MAX_WORDS_THRESHOLD} words): {stats['pending']}")
    
    if stats['pending'] == 0:
        print("\n✅ All words have been processed!")
        conn.close()
        return
    
    # Get words to process
    print(f"\n📥 Loading {stats['pending']} words to process...")
    words = get_words_to_process(conn)
    
    # Confirm
    print(f"\n🚀 Ready to process {len(words)} words in batches of {BATCH_SIZE}")
    input("   Press Enter to start (Ctrl+C to cancel)...")
    
    # Process
    print("\n" + "=" * 60)
    print("🔄 Processing started...")
    print("=" * 60)
    
    start_time = time.time()
    processed, success, failed = process_words(conn, client, words, start_time)
    elapsed = time.time() - start_time
    
    # Final statistics
    print("\n\n" + "=" * 60)
    print("📊 Final Statistics")
    print("=" * 60)
    print(f"✅ Processed: {processed}")
    print(f"✅ Success: {success}")
    print(f"❌ Failed: {failed}")
    print(f"⏱️ Time: {int(elapsed/60)}m {int(elapsed%60)}s")
    if processed > 0:
        print(f"📈 Average speed: {processed/elapsed:.2f} words/second")
    
    # Show samples
    if success > 0:
        print("\n📝 Sample results:")
        cursor = conn.cursor()
        cursor.execute(f"""
            SELECT w.en, p.old_vi, p.new_vi
            FROM {PROGRESS_TABLE} p
            JOIN words w ON w.id = p.word_id
            WHERE p.status = 'done'
            ORDER BY p.updated_at DESC
            LIMIT 5
        """)
        for row in cursor.fetchall():
            en, old_vi, new_vi = row
            print(f"\n   📖 {en}")
            print(f"      Cũ: {old_vi[:60]}..." if old_vi and len(old_vi) > 60 else f"      Cũ: {old_vi}")
            print(f"      Mới: {new_vi}")
    
    conn.close()
    print("\n✅ Done!")


def reset_errors():
    """Reset error status to retry failed words"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    
    cursor.execute(f"SELECT COUNT(*) FROM {PROGRESS_TABLE} WHERE status = 'error'")
    count = cursor.fetchone()[0]
    
    if count > 0:
        cursor.execute(f"DELETE FROM {PROGRESS_TABLE} WHERE status = 'error'")
        conn.commit()
        print(f"✅ Reset {count} error(s). Run the script again to retry.")
    else:
        print("ℹ️ No errors to reset.")
    
    conn.close()


def show_stats():
    """Show current statistics"""
    conn = sqlite3.connect(DATABASE_PATH)
    stats = get_statistics(conn)
    
    print("📊 Current Statistics:")
    print(f"   Total words: {stats['total_words']}")
    print(f"   Processed: {stats['processed']}")
    print(f"   Errors: {stats['errors']}")
    print(f"   Pending: {stats['pending']}")
    
    conn.close()


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Update Vietnamese meanings with OpenRouter API")
    parser.add_argument("--reset-errors", action="store_true", help="Reset error status to retry")
    parser.add_argument("--stats", action="store_true", help="Show statistics only")
    parser.add_argument("--api-key", type=str, help="OpenRouter API key")
    
    args = parser.parse_args()
    
    if args.api_key:
        OPENROUTER_API_KEY = args.api_key
    
    if args.reset_errors:
        reset_errors()
    elif args.stats:
        show_stats()
    else:
        main()
