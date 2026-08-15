from pydantic import BaseModel


class CountryOut(BaseModel):
    name: str
    iso_code: str
    phonecode: str
    currency: str
    flag: str


class StateOut(BaseModel):
    name: str
    iso_code: str


class CityOut(BaseModel):
    name: str
