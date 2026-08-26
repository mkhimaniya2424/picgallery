from fastapi import APIRouter, HTTPException, Query, status

from app.core.location_data import LocationData, get_location_data
from app.schemas.location import CityOut, CountryOut, StateOut

router = APIRouter(prefix="/locations", tags=["locations"])


def _get_country_or_404(data: LocationData, country: str) -> dict:
    match = data.countries_by_name.get(country.strip().lower())
    if match is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Unknown country: {country}")
    return match


def _get_state_or_404(data: LocationData, country_code: str, state: str) -> dict:
    match = data.states_by_country_and_name.get((country_code, state.strip().lower()))
    if match is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Unknown state: {state}")
    return match


@router.get("/countries", response_model=list[CountryOut])
def list_countries() -> list[dict]:
    """All countries, sorted alphabetically by name."""
    data = get_location_data()
    return sorted(data.countries, key=lambda c: c["name"])


@router.get("/states", response_model=list[StateOut])
def list_states(country: str = Query(..., description="Country name, e.g. 'India'")) -> list[dict]:
    """States/provinces for a given country name. 404 if the country isn't recognized."""
    data = get_location_data()
    country_row = _get_country_or_404(data, country)
    states = data.states_by_country.get(country_row["iso_code"], [])
    return sorted(states, key=lambda s: s["name"])


@router.get("/cities", response_model=list[CityOut])
def list_cities(
    country: str = Query(..., description="Country name, e.g. 'India'"),
    state: str = Query(..., description="State name, e.g. 'Gujarat'"),
) -> list[dict]:
    """Cities for a given country + state name pair. 404 if either isn't recognized."""
    data = get_location_data()
    country_row = _get_country_or_404(data, country)
    state_row = _get_state_or_404(data, country_row["iso_code"], state)
    city_names = data.cities_by_country_and_state.get((country_row["iso_code"], state_row["iso_code"]), [])
    return [{"name": name} for name in sorted(city_names)]
