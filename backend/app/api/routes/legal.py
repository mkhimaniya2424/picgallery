from fastapi import APIRouter

from app.core.legal_content import (
    get_help_support,
    get_privacy_policy,
    get_terms_conditions,
)
from app.schemas.legal import (
    HelpSupportContentOut,
    PolicyContentOut,
    TermsContentOut,
)

router = APIRouter(prefix="/legal", tags=["legal"])


@router.get("/privacy-policy", response_model=PolicyContentOut)
def read_privacy_policy() -> dict:
    """Static privacy policy content, editable without an app release."""
    return get_privacy_policy()


@router.get("/terms-conditions", response_model=TermsContentOut)
def read_terms_conditions() -> dict:
    """Static terms & conditions content, editable without an app release."""
    return get_terms_conditions()


@router.get("/help-support", response_model=HelpSupportContentOut)
def read_help_support() -> dict:
    """Static FAQ + support contact content, editable without an app release."""
    return get_help_support()
