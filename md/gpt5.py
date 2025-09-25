# regenerate_empty_topics_enhanced.py
# -*- coding: utf-8 -*-

import os
import json
import time
import re
import argparse
import requests
from time import sleep
from typing import List, Tuple, Dict, Any, Optional

class EmptyTopicRegenerator:
    def __init__(self,
                 vocab_dir: str = "generated_vocab_qwen",
                 topics_file: str = "topics.json",
                 model: str = "qwen-plus",
                 base_url: str = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions",
                 temperature: float = 0.2,
                 top_p: float = 0.9,
                 max_tokens: int = 1500,
                 timeout_sec: int = 180,
                 attempts: int = 3,
                 backoff_sec: int = 2,
                 min_items_ok: int = 1):
        self.vocab_dir = vocab_dir
        self.topics_file = topics_file
        self.model = model
        self.base_url = base_url.strip()  # fix: remove trailing space if any
        self.temperature = temperature
        self.top_p = top_p
        self.max_tokens = max_tokens
        self.timeout_sec = timeout_sec
        self.attempts = attempts
        self.backoff_sec = backoff_sec
        self.min_items_ok = min_items_ok
        api_key = "sk-eb4af1767ee447118eac1df88c0478ff"
        #api_key = os.getenv("DASHSCOPE_API_KEY", "").strip()
        if not api_key:
            raise RuntimeError("Missing DASHSCOPE_API_KEY environment variable.")
        self.headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}"
        }

        # Bạn có thể nạp mô tả nâng cao từ file JSON riêng nếu có:
        # with open("enhanced_descriptions.json", "r", encoding="utf-8") as f:
        #     self.enhanced_descriptions = json.load(f)
        self.enhanced_descriptions: Dict[str, str] = {}  # fallback rỗng; dùng description trong topics.json

    # ---------- IO ----------
    def load_topics(self) -> List[Dict[str, Any]]:
        with open(self.topics_file, 'r', encoding='utf-8') as f:
            return json.load(f)

    def _filepath(self, index: int, topic_id: str) -> str:
        filename = f"{index:02d}_{topic_id}.txt"
        return os.path.join(self.vocab_dir, filename)

    def save_vocab(self, index: int, topic_id: str, vocab_text: str) -> int:
        filepath = self._filepath(index, topic_id)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(vocab_text)
        item_count = self._count_items(vocab_text)
        print(f"✅ Regenerated: {os.path.basename(filepath)} → {item_count} items")
        return item_count

    # ---------- Helpers ----------
    def _count_items(self, text: str) -> int:
        if not text:
            return 0
        return len([x for x in text.split(",") if x.strip()])

    def _extract_items(self, content: str) -> List[str]:
        """Parser chắc tay để lấy danh sách CSV từ output có thể dính mô tả/markdown."""
        if not content:
            return []

        # Bỏ code fences nếu có
        content = re.sub(r"^```[\s\S]*?```", "", content.strip(), flags=re.M)

        # Nếu model lỡ có nhãn kiểu "Words: ..." "Phrases: ..." ở đầu dòng → cắt bỏ nhãn trước dấu :
        content = re.sub(
            r"(?im)^(?:topic|level|description|rules?|examples?|output|note|instruction|format|start(?: with)?|begin(?: with)?|words?|phrases?|list)\s*:\s*",
            "", content
        )

        # Một số model có thể xuống dòng nhiều; ta tách theo dấu phẩy là chính,
        # đồng thời chấp nhận ; / xuống dòng / bullet
        raw_tokens = re.split(r"[,\n;•·\-–—]+\s*", content)

        items: List[str] = []
        for tok in raw_tokens:
            t = tok.strip()
            if not t:
                continue
            # loại các câu hướng dẫn rõ rệt
            if re.match(r"(?i)^(here (?:are|is)|generate|include|only|no |please|important|reply)\b", t):
                continue
            # loại cụm quá dài (thường là câu văn)
            if len(t) > 60:
                continue
            # loại dấu đầu dòng kiểu "1. apple"
            t = re.sub(r"^\d+[\.\)]\s*", "", t)
            # cuối cùng: nếu vẫn còn dấu backtick/quote thừa thì bỏ
            t = t.strip("`'\" ")
            if t:
                items.append(t)

        # Dedupe không phân biệt hoa/thường
        seen, uniq = set(), []
        for it in items:
            key = it.lower()
            if key not in seen:
                seen.add(key)
                uniq.append(it)

        return uniq

    def generate_enhanced_prompt(self, topic_name: str, topic_description: str, level: str) -> List[Dict[str, str]]:
        detailed_desc = self.enhanced_descriptions.get(topic_name, topic_description or "")
        return [
            {
                "role": "system",
                "content": (
                    "You are an expert English vocabulary generator for Vietnamese learners. "
                    "Output ONLY a comma-separated list of words or phrases. No explanations. "
                    "No numbering. No examples in output."
                )
            },
            {
                "role": "user",
                "content": (
                    f'Generate 20-60 practical English words or phrases for the topic: "{topic_name}".\n'
                    f"Level: {level}. Description: \"{detailed_desc}\".\n\n"
                    "Rules:\n"
                    "- Output ONLY comma-separated values. Example: pencil, eraser, notebook\n"
                    "- Do NOT include: Vietnamese, numbers, bullets, \"Topic:\", \"Level:\", \"extra\", \"variation\".\n"
                    "- Include collocations or phrasal verbs if relevant.\n"
                    "- Do NOT add any explanations or formatting instructions.\n"
                    "- Start your response immediately with the list.\n\n"
                    "Now generate:"
                )
            }
        ]

    # ---------- API ----------
    def call_qwen_api(self, messages: List[Dict[str, str]], attempts: Optional[int] = None,
                      backoff_sec: Optional[int] = None) -> str:
        attempts = attempts or self.attempts
        backoff_sec = backoff_sec or self.backoff_sec

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": self.temperature,
            "max_tokens": self.max_tokens,
            "top_p": self.top_p,
            "stream": False
        }

        for attempt in range(1, attempts + 1):
            try:
                resp = requests.post(
                    self.base_url,
                    headers=self.headers,
                    json=payload,
                    timeout=self.timeout_sec
                )
                if resp.status_code in (200, 201):
                    data = resp.json()
                    content = (data.get("choices", [{}])[0]
                                  .get("message", {})
                                  .get("content", "")).strip()
                    items = self._extract_items(content)

                    if len(items) >= self.min_items_ok:
                        return ", ".join(items)

                    # Lần sau: nhắc lại thật rõ ràng phải là 1 dòng CSV
                    messages = [
                        messages[0],
                        {
                            "role": "user",
                            "content": messages[1]["content"]
                                       + "\n\nIMPORTANT: Reply with ONE SINGLE LINE of comma-separated items only. "
                                         "No extra words before or after."
                        }
                    ]
                else:
                    print(f"❌ API Error: {resp.status_code} - {resp.text}")
            except Exception as e:
                print(f"⚠️ Exception: {e}")

            time.sleep(backoff_sec * attempt)  # exponential backoff (2s, 4s, 6s,...)

        return ""  # vẫn rỗng

    # ---------- Target selection ----------
    def find_missing_or_zero_topics(self, topics: List[Dict[str, Any]]) -> List[Tuple[int, Dict[str, Any]]]:
        targets = []
        for i, topic in enumerate(topics, 1):
            path = self._filepath(i, topic["id"])
            if not os.path.exists(path):
                targets.append((i, topic))
                continue
            with open(path, "r", encoding="utf-8") as f:
                content = f.read().strip()
            if self._count_items(content) == 0:
                targets.append((i, topic))
        return targets

    def find_zero_only_topics(self, topics: List[Dict[str, Any]]) -> List[Tuple[int, Dict[str, Any]]]:
        targets = []
        for i, topic in enumerate(topics, 1):
            path = self._filepath(i, topic["id"])
            if os.path.exists(path):
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read().strip()
                if self._count_items(content) == 0:
                    targets.append((i, topic))
        return targets

    def all_topics(self, topics: List[Dict[str, Any]]) -> List[Tuple[int, Dict[str, Any]]]:
        return [(i, t) for i, t in enumerate(topics, 1)]

    # ---------- Main ----------
    def run(self, mode: str = "smart", attempts: Optional[int] = None, backoff_sec: Optional[int] = None):
        """
        mode:
          - "all"        : regenerate toàn bộ
          - "smart"      : regenerate file thiếu hoặc 0 items (mặc định)
          - "only-zero"  : chỉ regenerate các file đang tồn tại nhưng 0 items
        """
        os.makedirs(self.vocab_dir, exist_ok=True)
        topics = self.load_topics()

        if mode == "all":
            target_topics = self.all_topics(topics)
            action_word = "tạo lại toàn bộ"
        elif mode == "only-zero":
            target_topics = self.find_zero_only_topics(topics)
            action_word = "sinh lại (chỉ các file 0 items)"
        else:
            target_topics = self.find_missing_or_zero_topics(topics)
            action_word = "sinh lại (thiếu hoặc 0 items)"

        if not target_topics:
            print("🎉 Không có topic nào cần xử lý!")
            return

        print(f"🔁 Tìm thấy {len(target_topics)} topic cần {action_word}:")
        for idx, topic in target_topics:
            print(f"   → [{idx:02d}] {topic['name']} (ID: {topic['id']})")

        print(f"\n🚀 Bắt đầu {action_word} với parser cải tiến + retry + backoff...")

        failed: List[Tuple[int, str, str]] = []
        for i, (index, topic) in enumerate(target_topics, 1):
            topic_id = topic["id"]
            topic_name = topic["name"]
            topic_desc = topic.get("description", "")
            level = topic.get("level", "BASIC")

            print(f"\n🔷 [{i:02d}/{len(target_topics):02d}] Regenerating: {topic_name}")

            messages = self.generate_enhanced_prompt(topic_name, topic_desc, level)
            vocab = self.call_qwen_api(messages, attempts=attempts, backoff_sec=backoff_sec)

            items_count = self._count_items(vocab)
            if items_count == 0:
                print("⚠️ Parse ra 0 items, ghi file rỗng để đánh dấu và sẽ có thể chạy lại sau.")
                failed.append((index, topic_id, topic_name))

            self.save_vocab(index, topic_id, vocab)

            print("⏳ Đang chờ 1s trước request tiếp theo...")
            sleep(1)

        if failed:
            print("\n❗Các topic vẫn 0 items sau khi retry:")
            for idx, tid, tname in failed:
                print(f"   - [{idx:02d}] {tname} (ID: {tid})")
            print("\n👉 Bạn có thể chạy lại lệnh **không --all** hoặc dùng **--only-zero** để thử regenerate lại các topic này.")

def parse_args():
    parser = argparse.ArgumentParser(description="Regenerate English vocab lists for empty/missing topics.")
    parser.add_argument("--all", action="store_true", help="Regenerate ALL topics (overwrite existing files).")
    parser.add_argument("--only-zero", action="store_true", help="Only regenerate files that currently have 0 items.")
    parser.add_argument("--attempts", type=int, default=3, help="Retry attempts for each topic (default: 3).")
    parser.add_argument("--backoff", type=int, default=2, help="Base backoff seconds between retries (default: 2).")
    parser.add_argument("--min-items-ok", type=int, default=1, help="Minimum items to accept an output (default: 1).")
    parser.add_argument("--vocab-dir", default="generated_vocab_qwen", help="Output folder for vocab files.")
    parser.add_argument("--topics-file", default="topics.json", help="Path to topics.json.")
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_args()

    mode = "smart"
    if args.all:
        mode = "all"
    elif args.only_zero:
        mode = "only-zero"

    regenerator = EmptyTopicRegenerator(
        vocab_dir=args.vocab_dir,
        topics_file=args.topics_file,
        attempts=args.attempts,
        backoff_sec=args.backoff,
        min_items_ok=args.min_items_ok
    )

    print(f"🔧 Mode: {mode} | attempts={args.attempts} | backoff={args.backoff}s | min_items_ok={args.min_items_ok}")
    if mode != "all":
        print("💡 Không dùng --all: script sẽ chỉ regenerate file thiếu hoặc 0 items (hoặc chỉ 0 items nếu --only-zero).")

    regenerator.run(mode=mode, attempts=args.attempts, backoff_sec=args.backoff)
