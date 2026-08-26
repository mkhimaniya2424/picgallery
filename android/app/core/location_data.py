"""Offline country / state / city lookup.

The dataset under app/data/locations/*.json is bundled with the repo (not
fetched at runtime, no DB table) so these endpoints work with zero network
or database dependency. It's a trimmed copy of the public domain-ish
"country-state-city" dataset (250 countries, ~5k states/provinces, ~148k
cities) — generic for any country, India included.

Everything is loaded and indexed once per process (via lru_cache) and kept
in memory; at ~4MB of JSON this is cheap and avoids re-parsing on every
request.
"""

import json
from collections import defaultdict
from functools import lru_cache
from pathlib import Path
from typing import NamedTuple

DATA_DIR = Path(__file__).resolve().parent.parent / "data" / "locations"


class LocationData(NamedTuple):
    countries: list[dict]
    # country iso_code (upper) -> country dict
    countries_by_code: dict[str, dict]
    # lowercased country name -> country dict
    countries_by_name: dict[str, dict]
    # country iso_code -> list of state dicts
    states_by_country: dict[str, list[dict]]
    # (country iso_code, lowercased state name) -> state dict
    states_by_country_and_name: dict[tuple[str, str], dict]
    # (country iso_code, state iso_code) -> list of city names
    cities_by_country_and_state: dict[tuple[str, str], list[str]]


@lru_cache
def get_location_data() -> LocationData:
    with open(DATA_DIR / "countries.json", encoding="utf-8") as f:
        countries: list[dict] = json.load(f)
    with open(DATA_DIR / "states.json", encoding="utf-8") as f:
        states: list[dict] = json.load(f)
    with open(DATA_DIR / "cities.json", encoding="utf-8") as f:
        # stored compactly as [name, country_code, state_code]
        raw_cities: list[list[str]] = json.load(f)

    countries_by_code = {c["iso_code"]: c for c in countries}
    countries_by_name = {c["name"].lower(): c for c in countries}

    states_by_country: dict[str, list[dict]] = defaultdict(list)
    states_by_country_and_name: dict[tuple[str, str], dict] = {}
    for s in states:
        states_by_country[s["country_code"]].append(s)
        states_by_country_and_name[(s["country_code"], s["name"].lower())] = s

    cities_by_country_and_state: dict[tuple[str, str], list[str]] = defaultdict(list)
    for name, country_code, state_code in raw_cities:
        cities_by_country_and_state[(country_code, state_code)].append(name)

    return LocationData(
        countries=countries,
        countries_by_code=countries_by_code,
        countries_by_name=countries_by_name,
        states_by_country=dict(states_by_country),
        states_by_country_and_name=states_by_country_and_name,
        cities_by_country_and_state=dict(cities_by_country_and_state),
    )
