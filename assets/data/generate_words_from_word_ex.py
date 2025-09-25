#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Generate per-topic word JSON files from topic word lists in assets/data/word_ex.

Input:
  - Topics definition: assets/data/topics.json
  - Topic word lists (comma-separated): assets/data/word_ex/{index}_{topic_id}.txt

Output:
  - One JSON file per topic: assets/data/word/{index}_{topic_id}.json

Uses the same Dashscope (Qwen) API style as gpt5.py with retries/backoff and
robust output parsing. Produces items compatible with lib/model/word.dart (dWord).

CLI example (from project root):
  python assets/data/generate_words_from_word_ex.py \
    --topics-file assets/data/topics.json \
    --word-ex-dir assets/data/word_ex \
    --output-dir assets/data/word \
    --attempts 3 --backoff 2 --min-items 20 --max-items 60
"""

import os
import re
import json
import time
import argparse
from typing import List, Dict, Any, Tuple, Optional

import requests


class WordsFromWordExGenerator:
    def __init__(self,
                 topics_file: str = "assets/data/topics.json",
                 word_ex_dir: str = "assets/data/word_ex",
                 output_dir: str = "assets/data/word",
                 model: str = "qwen-plus",
                 base_url: str = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions",
                 temperature: float = 0.2,
                 top_p: float = 0.9,
                 max_tokens: int = 2500,
                 timeout_sec: int = 180,
                 attempts: int = 3,
                 backoff_sec: int = 2,
                 min_items: int = 20,
                 max_items: int = 60):
        self.topics_file = topics_file
        self.word_ex_dir = word_ex_dir
        self.output_dir = output_dir
        self.model = model
        self.base_url = base_url.strip()
        self.temperature = temperature
        self.top_p = top_p
        self.max_tokens = max_tokens
        self.timeout_sec = timeout_sec
        self.attempts = attempts
        self.backoff_sec = backoff_sec
        self.min_items = min_items
        self.max_items = max_items

        # NOTE: mirrors gpt5.py pattern; replace with env var if desired
        api_key = "sk-eb4af1767ee447118eac1df88c0478ff"
        # api_key = os.getenv("DASHSCOPE_API_KEY", "").strip()
        if not api_key:
            raise RuntimeError("Missing DASHSCOPE_API_KEY.")
        self.headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        }

        os.makedirs(self.output_dir, exist_ok=True)

    # ---------------- IO ----------------
    def load_topics(self) -> List[Dict[str, Any]]:
        with open(self.topics_file, "r", encoding="utf-8") as f:
            return json.load(f)

    def list_word_ex_files(self) -> List[str]:
        if not os.path.isdir(self.word_ex_dir):
            return []
        all_txt = [os.path.join(self.word_ex_dir, f)
                   for f in os.listdir(self.word_ex_dir)
                   if f.lower().endswith(".txt")]
        # sort by numeric prefix if present
        def sort_key(p: str) -> Tuple[int, str]:
            name = os.path.basename(p)
            m = re.match(r"^(\d+)_", name)
            if m:
                return (int(m.group(1)), name)
            return (9999, name)
        return sorted(all_txt, key=sort_key)

    def read_word_list(self, path: str) -> List[str]:
        try:
            text = open(path, "r", encoding="utf-8").read().strip()
        except Exception:
            return []
        # Accept comma-separated; also tolerate newlines/semicolons
        tokens = re.split(r"[,\n;]+", text)
        items, seen = [], set()
        for tok in tokens:
            t = tok.strip()
            if not t:
                continue
            key = t.lower()
            if key in seen:
                continue
            seen.add(key)
            items.append(t)
        return items

    def save_topic_words(self, index: int, topic_id: str, items: List[Dict[str, Any]]) -> int:
        filename = f"{index:02d}_{topic_id}.json"
        path = os.path.join(self.output_dir, filename)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(items, f, ensure_ascii=False, indent=2)
        print(f"💾 Saved: {filename} → {len(items)} items")
        return len(items)

    # ---------------- Prompt & API ----------------
    def build_prompt(self, topic: Dict[str, Any], provided_list: List[str]) -> List[Dict[str, str]]:
        topic_name = topic.get("name", "")
        topic_desc = topic.get("description", "")
        topic_level = topic.get("level", "BASIC")
        topic_id = topic.get("id", "")

        # Constrain list length to [min_items, max_items]
        trimmed = provided_list[: self.max_items]

        # The model must output ONLY a JSON array, matching dWord-compatible fields
        user_content = (
            f"You are given a topic and a provided list of English words/phrases.\n"
            f"Topic: {topic_name} (id: {topic_id})\n"
            f"Level: {topic_level}. Description: \"{topic_desc}\".\n\n"
            f"Provided list (use as the 'en' field, no extra items):\n"
            + ", ".join(trimmed) + "\n\n"
            f"Task: Return ONLY a JSON array (no surrounding text) with {self.min_items}-{self.max_items} objects.\n"
            f"Each object MUST have these keys exactly (JSON):\n"
            f"en, vi, pronunciation, sentence, sentenceVi, topic, level, type, difficulty, tags, reviewCount, nextReview, masteryLevel, lastReviewed, correctAnswers, totalAttempts, currentInterval, easeFactor, isKidFriendly, synonyms, antonyms\n\n"
            f"Rules:\n"
            f"- The 'en' must be one of the provided items (case-insensitive). Do not invent new entries.\n"
            f"- 'topic' = '{topic_id}'. 'level' = '{topic_level}'.\n"
            f"- 'type' ∈ [noun, verb, adjective, adverb, preposition, conjunction, interjection, pronoun, determiner, phrase].\n"
            f"- 'difficulty' integer 1-5 (for learners at this level).\n"
            f"- 'pronunciation' provide IPA if known; otherwise leave empty string.\n"
            f"- 'sentence' short, simple English example using the word naturally; 'sentenceVi' its Vietnamese meaning.\n"
            f"- 'tags' include at least ['{topic_id}', '{topic_level.lower()}'].\n"
            f"- Set 'reviewCount' = 0, 'nextReview' = null, 'masteryLevel' = 0.0, 'lastReviewed' = null,\n"
            f"  'correctAnswers' = 0, 'totalAttempts' = 0, 'currentInterval' = 1, 'easeFactor' = 2.5, 'isKidFriendly' = true,\n"
            f"  'synonyms' = [], 'antonyms' = [].\n"
            f"- Output a valid JSON array only. Start with [ and end with ]."
        )

        return [
            {"role": "system", "content": (
                "You are an expert English vocabulary generator for Vietnamese learners. "
                "Return STRICT JSON only, no explanations."
            )},
            {"role": "user", "content": user_content},
        ]

    def call_api(self, messages: List[Dict[str, str]]) -> str:
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": self.temperature,
            "max_tokens": self.max_tokens,
            "top_p": self.top_p,
            "stream": False,
        }
        resp = requests.post(
            self.base_url,
            headers=self.headers,
            json=payload,
            timeout=self.timeout_sec,
        )
        if resp.status_code in (200, 201):
            data = resp.json()
            return (data.get("choices", [{}])[0]
                        .get("message", {})
                        .get("content", "")).strip()
        else:
            print(f"❌ API Error: {resp.status_code} - {resp.text}")
            return ""

    # ---------------- Parsing & Post-processing ----------------
    def _extract_json_object(self, text: str) -> Optional[str]:
        if not text:
            return None
        # Try to locate the first { ... } JSON object in the text
        m = re.search(r"\{([\s\S]*)\}", text)
        if not m:
            return None
        content = "{" + m.group(1) + "}"
        return content

    def _extract_json_array(self, text: str) -> Optional[str]:
        if not text:
            return None
        # Try to locate the first [ ... ] JSON array in the text
        m = re.search(r"\[([\s\S]*)\]", text)
        if not m:
            return None
        content = "[" + m.group(1) + "]"
        return content

    def _normalize_item(self, item: Dict[str, Any], topic_id: str, level: str) -> Dict[str, Any]:
        # Ensure required keys and types; fill defaults
        def get_str(key: str, default: str = "") -> str:
            v = item.get(key, default)
            return v if isinstance(v, str) else default

        def get_int(key: str, default: int = 0) -> int:
            v = item.get(key, default)
            try:
                return int(v)
            except Exception:
                return default

        def get_float(key: str, default: float = 0.0) -> float:
            v = item.get(key, default)
            try:
                return float(v)
            except Exception:
                return default

        def get_bool(key: str, default: bool = True) -> bool:
            v = item.get(key, default)
            return bool(v)

        def get_list_str(key: str, default: List[str] = None) -> List[str]:
            if default is None:
                default = []
            v = item.get(key, default)
            if isinstance(v, list):
                return [str(x) for x in v]
            return default

        en = get_str("en")
        vi = get_str("vi")
        pronunciation = get_str("pronunciation")
        sentence = get_str("sentence")
        sentenceVi = get_str("sentenceVi")
        wtype = get_str("type", "noun")
        # clamp type to allowed set
        allowed_types = {
            "noun","verb","adjective","adverb","preposition","conjunction",
            "interjection","pronoun","determiner","phrase"
        }
        if wtype not in allowed_types:
            wtype = "noun"

        difficulty = get_int("difficulty", 1)
        if difficulty < 1:
            difficulty = 1
        if difficulty > 5:
            difficulty = 5

        tags = get_list_str("tags")
        if topic_id not in tags:
            tags.append(topic_id)
        if level.lower() not in [t.lower() for t in tags]:
            tags.append(level.lower())

        normalized = {
            "en": en,
            "vi": vi,
            "pronunciation": pronunciation,
            "sentence": sentence,
            "sentenceVi": sentenceVi,
            "topic": topic_id,
            "level": level,
            "type": wtype,
            "synonyms": get_list_str("synonyms"),
            "antonyms": get_list_str("antonyms"),
            "imageUrl": item.get("imageUrl"),
            "difficulty": difficulty,
            "tags": tags,
            "reviewCount": get_int("reviewCount", 0),
            # nextReview may be null or ISO string; keep null to let app set default
            "nextReview": item.get("nextReview", None),
            "masteryLevel": get_float("masteryLevel", 0.0),
            "lastReviewed": item.get("lastReviewed", None),
            "correctAnswers": get_int("correctAnswers", 0),
            "totalAttempts": get_int("totalAttempts", 0),
            "currentInterval": get_int("currentInterval", 1),
            "easeFactor": get_float("easeFactor", 2.5),
            "isKidFriendly": get_bool("isKidFriendly", True),
            "mnemonicTip": item.get("mnemonicTip"),
            "culturalNote": item.get("culturalNote"),
        }
        return normalized

    # ---------------- Per-item enrichment ----------------
    def build_enrich_prompt(self, en_word: str, topic: Dict[str, Any]) -> List[Dict[str, str]]:
      topic_name = topic.get("name", "")
      topic_desc = topic.get("description", "")
      topic_level = topic.get("level", "BASIC")
      topic_id = topic.get("id", "")

      user_content = (
          f"Given an English word/phrase and its topic, return ONLY a JSON object with these keys: "
          f"en, vi, pronunciation, sentence, sentenceVi, type, difficulty.\n\n"
          f"Constraints:\n"
          f"- en = '{en_word}'.\n"
          f"- vi: concise Vietnamese meaning.\n"
          f"- pronunciation: IPA if known else empty string.\n"
          f"- sentence: short simple English example (A1-B1), natural usage.\n"
          f"- sentenceVi: Vietnamese translation of the example.\n"
          f"- type ∈ [noun, verb, adjective, adverb, preposition, conjunction, interjection, pronoun, determiner, phrase].\n"
          f"- difficulty: integer 1-5 appropriate for {topic_level}.\n\n"
          f"Topic: {topic_name} (id: {topic_id})\n"
          f"Description: {topic_desc}\n\n"
          f"Output strictly JSON object only."
      )

      return [
          {"role": "system", "content": (
              "You enrich vocabulary items for Vietnamese learners. Return STRICT JSON only."
          )},
          {"role": "user", "content": user_content},
      ]

    def _enrich_single_item(self, base_item: Dict[str, Any], topic: Dict[str, Any]) -> Dict[str, Any]:
      en = str(base_item.get("en", "")).strip()
      if not en:
          return base_item
      needs = [
          not base_item.get("vi"),
          base_item.get("pronunciation", "") == "",
          base_item.get("sentence", "") == "",
          base_item.get("sentenceVi", "") == "",
      ]
      if not any(needs):
          return base_item

      messages = self.build_enrich_prompt(en, topic)
      for attempt in range(1, self.attempts + 1):
          try:
              content = self.call_api(messages)
              obj_text = self._extract_json_object(content)
              if obj_text:
                  data = json.loads(obj_text)
                  # Merge fields
                  merged = dict(base_item)
                  for k in ["vi", "pronunciation", "sentence", "sentenceVi", "type", "difficulty"]:
                      v = data.get(k)
                      if v is not None and v != "":
                          merged[k] = v
                  return merged
          except Exception:
              pass
          time.sleep(self.backoff_sec * attempt)
      return base_item

    def _enrich_items(self, topic: Dict[str, Any], items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        enriched: List[Dict[str, Any]] = []
        for i, it in enumerate(items):
            enriched_item = self._enrich_single_item(it, topic)
            enriched.append(enriched_item)
            # small delay to avoid rate limit
            time.sleep(0.2)
        return enriched

    def generate_topic_words(self, index: int, topic: Dict[str, Any], provided_list: List[str]) -> List[Dict[str, Any]]:
        # Enforce list length window
        if len(provided_list) < self.min_items:
            print(f"⚠️  Topic {topic.get('id')} has only {len(provided_list)} items (< {self.min_items}). Proceeding anyway.")
        trimmed = provided_list[: self.max_items]

        messages = self.build_prompt(topic, trimmed)

        content = ""
        for attempt in range(1, self.attempts + 1):
            try:
                content = self.call_api(messages)
                json_text = self._extract_json_array(content)
                if json_text:
                    try:
                        raw_items = json.loads(json_text)
                        if isinstance(raw_items, list) and len(raw_items) >= 1:
                            # Keep only objects whose 'en' comes from provided list
                            provided_set = {x.lower() for x in trimmed}
                            topic_id = topic.get("id", "")
                            level = topic.get("level", "BASIC")
                            normalized = []
                            for it in raw_items:
                                if not isinstance(it, dict):
                                    continue
                                en_val = str(it.get("en", "")).lower()
                                if en_val and en_val in provided_set:
                                    normalized.append(self._normalize_item(it, topic_id, level))
                            # ensure within min/max
                            if len(normalized) >= max(1, min(self.min_items, len(trimmed))):
                                # Enrich missing fields before returning
                                return self._enrich_items(topic, normalized[: self.max_items])
                    except Exception as e:
                        # parsing failed, will retry
                        pass
            except Exception as e:
                print(f"⚠️ Exception on attempt {attempt}: {e}")
            time.sleep(self.backoff_sec * attempt)

        print("❌ Failed to get valid JSON array; returning minimal stubs")
        # Fallback: create minimal stubs with only required fields
        topic_id = topic.get("id", "")
        level = topic.get("level", "BASIC")
        stubs = []
        for en in trimmed:
            stubs.append(self._normalize_item({
                "en": en,
                "vi": "",
                "pronunciation": "",
                "sentence": "",
                "sentenceVi": "",
                "type": "phrase" if " " in en else "noun",
                "difficulty": 1,
                "tags": [topic_id, level.lower()],
            }, topic_id, level))
        # Enrich stubs to fill missing fields
        return self._enrich_items(topic, stubs)

    # ---------------- Main ----------------
    def run(self, only_topics: Optional[List[str]] = None):
        topics = self.load_topics()
        # map topic_id -> (index, topic)
        id_to_index_topic: Dict[str, Tuple[int, Dict[str, Any]]] = {}
        for i, t in enumerate(topics, 1):
            id_to_index_topic[t.get("id")] = (i, t)

        files = self.list_word_ex_files()
        if not files:
            print("❌ No topic files found in word_ex directory.")
            return

        print(f"🔎 Found {len(files)} topic files in {self.word_ex_dir}")

        for path in files:
            fname = os.path.basename(path)
            m = re.match(r"^(\d+)_([\w\-]+)\.txt$", fname)
            idx_by_name: Optional[int] = None
            topic_id_from_file: Optional[str] = None
            if m:
                idx_by_name = int(m.group(1))
                topic_id_from_file = m.group(2)
            else:
                # accept names like topic_id.txt
                m2 = re.match(r"^([\w\-]+)\.txt$", fname)
                if m2:
                    topic_id_from_file = m2.group(1)

            if not topic_id_from_file:
                print(f"⚠️  Skip unrecognized filename: {fname}")
                continue

            if only_topics and topic_id_from_file not in only_topics:
                continue

            if topic_id_from_file not in id_to_index_topic:
                print(f"⚠️  Topic id not in topics.json: {topic_id_from_file} → skip")
                continue

            index, topic = id_to_index_topic[topic_id_from_file]
            word_list = self.read_word_list(path)
            if not word_list:
                print(f"⚠️  Empty list in {fname} → producing empty JSON")
                self.save_topic_words(index, topic_id_from_file, [])
                continue

            print(f"\n🔷 [{index:02d}] Generating words for: {topic.get('name')} (ID: {topic_id_from_file})")
            items = self.generate_topic_words(index, topic, word_list)
            self.save_topic_words(index, topic_id_from_file, items)


def parse_args():
    p = argparse.ArgumentParser(description="Generate per-topic word JSON from word_ex lists using Qwen API.")
    p.add_argument("--topics-file", default="assets/data/topics.json")
    p.add_argument("--word-ex-dir", default="assets/data/word_ex")
    p.add_argument("--output-dir", default="assets/data/word")
    p.add_argument("--attempts", type=int, default=3)
    p.add_argument("--backoff", type=int, default=2)
    p.add_argument("--min-items", type=int, default=20)
    p.add_argument("--max-items", type=int, default=60)
    p.add_argument("--only-topics", default="", help="Comma-separated topic ids to process only")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    only_topics = [x.strip() for x in args.only_topics.split(",") if x.strip()] or None

    gen = WordsFromWordExGenerator(
        topics_file=args.topics_file,
        word_ex_dir=args.word_ex_dir,
        output_dir=args.output_dir,
        attempts=args.attempts,
        backoff_sec=args.backoff,
        min_items=args.min_items,
        max_items=args.max_items,
    )
    print(f"🔧 attempts={args.attempts} | backoff={args.backoff}s | range={args.min_items}-{args.max_items}")
    print(f"📁 topics={args.topics_file} | word_ex={args.word_ex_dir} | out={args.output_dir}")
    gen.run(only_topics=only_topics)


