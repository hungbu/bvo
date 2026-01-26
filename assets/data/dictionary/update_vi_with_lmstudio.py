#!/usr/bin/env python3
"""
Update Vietnamese meanings in dictionary.db using local LM Studio (Gemma)
- Only update words with meanings longer than 6 words
- Process in batches (50 words per batch for local AI stability)
- Support resume on error
- Track progress with SQLite status table

Run: python update_vi_with_lmstudio.py

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

# LM Studio Configuration
LM_STUDIO_URL = "http://localhost:1234/v1"
LM_STUDIO_MODEL = "google/gemma-3n-e4b"

# Processing Configuration
BATCH_SIZE = 50  # Words per batch for local AI
MAX_WORDS_THRESHOLD = 6  # Only process words with more than this many words in vi
SAVE_INTERVAL = 100  # Commit to database every N words
REQUEST_DELAY = 0.1  # Minimal delay for local processing

# Database
DATABASE_PATH = "dictionary.db"
PROGRESS_TABLE = "vi_update_progress"

# ============================================================================
# LM STUDIO CLIENT
# ============================================================================

def init_client():
    """Initialize OpenAI client pointing to local LM Studio"""
    client = OpenAI(
        base_url=LM_STUDIO_URL,
        api_key="lm-studio",  # API key not needed but required by client
    )
    return client


def call_ai_batch(client, words_batch: List[Tuple[int, str, str]]) -> dict:
    """
    Call LM Studio API with a batch of words.
    
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
    
    prompt = f"""Bạn là trợ lý từ điển Anh-Việt chuyên nghiệp. Nhiệm vụ: Tối ưu lại các nghĩa tiếng Việt sau đây để chúng NGẮN GỌN và SÚC TÍCH hơn.

YÊU CẦU:
1. Mỗi nghĩa tiếng Việt mới phải NGẮN GỌN (tối đa 4-6 từ).
2. Giữ nguyên nghĩa chính, loại bỏ các phần giải thích dài dòng.
3. Chỉ trả về kết quả theo định dạng: ID|nghĩa mới
4. Mỗi từ một dòng. KHÔNG GIẢI THÍCH GÌ THÊM.

DANH SÁCH TỪ (ID|Từ tiếng Anh|Nghĩa hiện tại):
{batch_text}

KẾT QUẢ (ID|nghĩa mới):"""

    try:
        completion = client.chat.completions.create(
            model=LM_STUDIO_MODEL,
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
                            # Clean ID (sometimes AI adds numbers or dots)
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
        print(f"\n❌ LM Studio API error: {e}")
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
    words = [w for w in text.split() if w.strip()]
    return len(words)


def get_words_to_process(conn, limit: Optional[int] = None) -> List[Tuple]:
    """Get words that need processing"""
    cursor = conn.cursor()
    ensure_progress_table(conn)
    
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
    
    words_to_process = []
    for word_id, en, vi in all_words:
        if count_words_in_text(vi) > MAX_WORDS_THRESHOLD:
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
    cursor.execute("PRAGMA table_info(words)")
    columns = [row[1] for row in cursor.fetchall()]
    
    if "vi_detail" not in columns:
        print("📦 Adding vi_detail column...")
        cursor.execute("ALTER TABLE words ADD COLUMN vi_detail TEXT")
        conn.commit()
    
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
    ensure_progress_table(conn)
    cursor.execute("SELECT COUNT(*) FROM words WHERE vi IS NOT NULL AND vi != ''")
    total_words = cursor.fetchone()[0]
    cursor.execute(f"SELECT COUNT(*) FROM {PROGRESS_TABLE} WHERE status = 'done'")
    processed = cursor.fetchone()[0]
    cursor.execute(f"SELECT COUNT(*) FROM {PROGRESS_TABLE} WHERE status = 'error'")
    errors = cursor.fetchone()[0]
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
    
    for i in range(0, total, BATCH_SIZE):
        batch = words[i:i + BATCH_SIZE]
        batch_size = len(batch)
        
        print(f"\n📤 Processing batch {i//BATCH_SIZE + 1} ({batch_size} words)...")
        
        try:
            results = call_ai_batch(client, batch)
            
            for word_id, en, old_vi in batch:
                if word_id in results:
                    new_vi = results[word_id]
                    update_word_vi(conn, word_id, new_vi)
                    save_progress(conn, word_id, old_vi, new_vi, "done")
                    success += 1
                else:
                    save_progress(conn, word_id, old_vi, None, "error", "No result from API")
                    failed += 1
                processed += 1
            
            conn.commit()
            
            elapsed = time.time() - start_time
            rate = processed / elapsed if elapsed > 0 else 0
            remaining = (total - processed) / rate if rate > 0 else 0
            
            print_progress_bar(
                processed, total,
                prefix="📊 ",
                suffix=f"| ✅ {success} ❌ {failed} | {rate:.1f} w/s | ETA: {int(remaining/60)}m"
            )
            
            if i + BATCH_SIZE < total:
                time.sleep(REQUEST_DELAY)
        
        except KeyboardInterrupt:
            print("\n\n⚠️ Interrupted! Progress saved.")
            conn.commit()
            return processed, success, failed
        except Exception as e:
            print(f"\n❌ Batch error: {e}")
            for word_id, en, old_vi in batch:
                save_progress(conn, word_id, old_vi, None, "error", str(e))
                failed += 1
                processed += 1
            conn.commit()
    
    return processed, success, failed


def main():
    """Main entry point"""
    print("=" * 60)
    print("📚 Update Vietnamese Meanings with Local AI (LM Studio)")
    print("=" * 60)
    
    print(f"\n📁 Database: {DATABASE_PATH}")
    print(f"🤖 Model: {LM_STUDIO_MODEL}")
    print(f"🔗 URL: {LM_STUDIO_URL}")
    print(f"📦 Batch size: {BATCH_SIZE} words")
    
    client = init_client()
    
    print("\n🔌 Testing LM Studio connection...")
    try:
        completion = client.chat.completions.create(
            model=LM_STUDIO_MODEL,
            messages=[{"role": "user", "content": "Say OK"}]
        )
        print(f"✅ Connected: {completion.choices[0].message.content.strip()}")
    except Exception as e:
        print(f"❌ Connection failed. Ensure LM Studio is running on port 1234.")
        print(f"Error: {e}")
        sys.exit(1)
    
    conn = sqlite3.connect(DATABASE_PATH)
    backup_vi_to_vi_detail(conn)
    
    stats = get_statistics(conn)
    print(f"\n📊 Statistics:")
    print(f"   Total words: {stats['total_words']}")
    print(f"   Already processed: {stats['processed']}")
    print(f"   Errors: {stats['errors']}")
    print(f"   Pending (> {MAX_WORDS_THRESHOLD} words): {stats['pending']}")
    
    if stats['pending'] == 0:
        print("\n✅ All words processed!")
        conn.close()
        return
    
    words = get_words_to_process(conn)
    print(f"\n🚀 Ready to process {len(words)} words.")
    input("   Press Enter to start...")
    
    print("\n" + "=" * 60)
    print("🔄 Processing started...")
    start_time = time.time()
    processed, success, failed = process_words(conn, client, words, start_time)
    elapsed = time.time() - start_time
    
    print("\n\n" + "=" * 60)
    print(f"📊 Final: {processed} processed | ✅ {success} | ❌ {failed}")
    print(f"⏱️ Time: {int(elapsed/60)}m {int(elapsed%60)}s")
    
    if success > 0:
        print("\n📝 Samples:")
        cursor = conn.cursor()
        cursor.execute(f"SELECT w.en, p.old_vi, p.new_vi FROM {PROGRESS_TABLE} p JOIN words w ON w.id = p.word_id WHERE p.status = 'done' ORDER BY p.updated_at DESC LIMIT 5")
        for en, old, new in cursor.fetchall():
            print(f"\n   📖 {en}\n      Cũ: {old[:60]}...\n      Mới: {new}")
    
    conn.close()


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--reset-errors", action="store_true")
    parser.add_argument("--stats", action="store_true")
    args = parser.parse_args()
    
    if args.reset_errors:
        conn = sqlite3.connect(DATABASE_PATH)
        cursor = conn.cursor()
        cursor.execute(f"DELETE FROM {PROGRESS_TABLE} WHERE status = 'error'")
        conn.commit()
        print("✅ Reset errors.")
        conn.close()
    elif args.stats:
        conn = sqlite3.connect(DATABASE_PATH)
        stats = get_statistics(conn)
        print(f"📊 Processed: {stats['processed']} | Pending: {stats['pending']}")
        conn.close()
    else:
        main()
