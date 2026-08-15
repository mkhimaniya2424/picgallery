"""Offline legal/support content loader.

The content under app/data/legal/*.json is bundled with the repo (not
fetched at runtime, no DB table) so these endpoints work with zero
database dependency and can be edited/redeployed without an app store
release. Mirrors the pattern used by core/location_data.py.

Each JSON file is loaded once per process (via lru_cache) and kept in
memory.
"""

import json
from functools import lru_cache
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "data" / "legal"


@lru_cache
def get_privacy_policy() -> dict:
    with open(DATA_DIR / "privacy_policy.json", encoding="utf-8") as f:
        return json.load(f)


@lru_cache
def get_terms_conditions() -> dict:
    with open(DATA_DIR / "terms_conditions.json", encoding="utf-8") as f:
        return json.load(f)


@lru_cache
def get_help_support() -> dict:
    with open(DATA_DIR / "help_support.json", encoding="utf-8") as f:
        return json.load(f)
