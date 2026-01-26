#!/usr/bin/env python3
"""
Update Vietnamese meanings in dictionary.db using Google Gemini API
- Only update words with meanings longer than 6 words
- Process in smart batches (100 words per batch)
- Support resume on error
- Track progress with SQLite status table

Run: python update_vi_with_gemini.py

Requirements:
    pip install google-generativeai
"""

import sqlite3
import re
import time
import sys
import os
from datetime import datetime
from typing import Optional, List, Tuple
import json

# ============================================================================
# CONFIGURATION
# ============================================================================

# Gemini API Configuration
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "YOUR_API_KEY_HERE")
GEMINI_MODEL = "gemini-2.0-flash"  # Fast and cheap model

# Processing Configuration
BATCH_SIZE = 100  # Words per batch to send to Gemini
MAX_WORDS_THRESHOLD = 6  # Only process words with more than this many words in vi
SAVE_INTERVAL = 100  # Commit to database every N words
REQUEST_DELAY = 0.5  # Delay between API calls (seconds) to avoid rate limiting

# Database
DATABASE_PATH = "dictionary.db"
PROGRESS_TABLE = "vi_update_progress"

# ============================================================================
# GEMINI API CLIENT
# ============================================================================

def init_gemini():
    """Initialize Gemini API client"""
    try:
        import google.generativeai as genai
        genai.configure(api_key=GEMINI_API_KEY)
        model = genai.GenerativeModel(GEMINI_MODEL)
        return model
    except ImportError:
        print("❌ Please install google-generativeai:")
        print("   pip install google-generativeai")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Failed to initialize Gemini: {e}")
        sys.exit(1)


def call_gemini_batch(model, words_batch: List[Tuple[int, str, str]]) -> dict:
    """
    Call Gemini API with a batch of words.
    
    Args:
        model: Gemini model instance
        words_batch: List of (id, en, vi) tuples
    
    Returns:
        Dict mapping word_id to new Vietnamese meaning
    """
    # Build batch prompt
    words_list = []
    for word_id, en, vi in words_batch:
        word_count = len(vi.split()) if vi else 0
        words_list.append(f"{word_id}|{en}|{vi[:200]}...")  # Truncate long meanings
    
    batch_text = "\n".join(words_list)
    
    prompt = f"""Bạn là trợ lý từ điển Anh-Việt. Nhiệm vụ: tạo nghĩa tiếng Việt NGẮN GỌN cho các từ sau.

Yêu cầu:
- Mỗi nghĩa tiếng Việt phải NGẮN GỌN, tối đa 4-6 từ
- Giữ nguyên nghĩa chính, bỏ phần giải thích dài dòng
- Trả về định dạng: ID|nghĩa mới
- Mỗi từ một dòng

Danh sách từ (ID|từ tiếng Anh|nghĩa hiện tại):
{batch_text}

Trả về nghĩa mới theo định dạng (ID|nghĩa mới):"""

    try:
        response = model.generate_content(
            prompt,
            generation_config={
                "temperature": 0.1,
                "max_output_tokens": 2000,
            }
        )
        
        # Parse response
        results = {}
        if response.text:
            for line in response.text.strip().split("\n"):
                line = line.strip()
                if "|" in line:
                    parts = line.split("|", 1)
                    if len(parts) == 2:
                        try:
                            word_id = int(parts[0].strip())
                            new_vi = parts[1].strip()
                            # Clean up the meaning
                            new_vi = re.sub(r'^[\d\.\-\)\:]+\s*', '', new_vi)
                            new_vi = new_vi.strip('"\'')
                            if new_vi and len(new_vi) > 1:
                                results[word_id] = new_vi
                        except ValueError:
                            continue
        
        return results
    
    except Exception as e:
        print(f"\n❌ Gemini API error: {e}")
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


def process_words(conn, model, words: List[Tuple], start_time: float):
    """Process a list of words in batches"""
    total = len(words)
    processed = 0
    success = 0
    failed = 0
    
    for i in range(0, total, BATCH_SIZE):
        batch = words[i:i + BATCH_SIZE]
        batch_size = len(batch)
        
        # Call Gemini API
        print(f"\n📤 Processing batch {i//BATCH_SIZE + 1} ({batch_size} words)...")
        
        try:
            results = call_gemini_batch(model, batch)
            
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
            
            # Delay to avoid rate limiting
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
    print("📚 Update Vietnamese Meanings with Gemini AI")
    print("=" * 60)
    
    # Check API key
    if GEMINI_API_KEY == "YOUR_API_KEY_HERE" or not GEMINI_API_KEY:
        print("\n❌ Please set GEMINI_API_KEY environment variable or edit the script")
        print("   Example: set GEMINI_API_KEY=your-api-key-here")
        print("   Or: $env:GEMINI_API_KEY='your-api-key-here'")
        sys.exit(1)
    
    print(f"\n📁 Database: {DATABASE_PATH}")
    print(f"🤖 Model: {GEMINI_MODEL}")
    print(f"📦 Batch size: {BATCH_SIZE} words")
    print(f"📏 Processing words with > {MAX_WORDS_THRESHOLD} words in meaning")
    
    # Initialize Gemini
    print("\n🔌 Connecting to Gemini API...")
    model = init_gemini()
    
    # Test connection
    try:
        response = model.generate_content("Say 'OK' only")
        print(f"✅ Connected to Gemini API")
    except Exception as e:
        print(f"❌ Failed to connect to Gemini: {e}")
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
    processed, success, failed = process_words(conn, model, words, start_time)
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
    
    parser = argparse.ArgumentParser(description="Update Vietnamese meanings with Gemini AI")
    parser.add_argument("--reset-errors", action="store_true", help="Reset error status to retry")
    parser.add_argument("--stats", action="store_true", help="Show statistics only")
    parser.add_argument("--api-key", type=str, help="Gemini API key")
    
    args = parser.parse_args()
    
    if args.api_key:
        GEMINI_API_KEY = args.api_key
    
    if args.reset_errors:
        reset_errors()
    elif args.stats:
        show_stats()
    else:
        main()
