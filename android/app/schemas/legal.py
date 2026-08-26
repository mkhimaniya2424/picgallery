from pydantic import BaseModel


class PolicySectionOut(BaseModel):
    title: str
    paragraphs: list[str]
    bullets: list[str] = []


class PolicyContentOut(BaseModel):
    last_updated: str
    intro_title: str
    intro_paragraphs: list[str]
    sections: list[PolicySectionOut]


class TermsSectionOut(BaseModel):
    title: str
    paragraphs: list[str]


class TermsContentOut(BaseModel):
    last_updated: str
    intro_title: str
    intro_paragraphs: list[str]
    sections: list[TermsSectionOut]


class FaqItemOut(BaseModel):
    question: str
    answer: str


class FaqSectionOut(BaseModel):
    title: str
    items: list[FaqItemOut]


class SupportActionOut(BaseModel):
    label: str
    payload: str
    type: str  # "email" | "phone" | "copy"


class SupportContactOut(BaseModel):
    title: str
    email: str
    phone: str
    actions: list[SupportActionOut]


class HelpSupportContentOut(BaseModel):
    last_updated: str
    faq_sections: list[FaqSectionOut]
    contact: SupportContactOut
