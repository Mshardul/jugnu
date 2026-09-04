"""Case transforms."""

from __future__ import annotations

import re

from .lines import OpError


def _to_words(text: str) -> list[str]:
    # Split on non-alphanumeric, keep runs
    parts = re.findall(r"[A-Za-z0-9]+", text)
    return parts


def case_lower(text: str, _args: dict) -> tuple[str, str]:
    return text.lower(), "Lowercase"


def case_upper(text: str, _args: dict) -> tuple[str, str]:
    return text.upper(), "UPPERCASE"


def case_title(text: str, _args: dict) -> tuple[str, str]:
    return text.title(), "Title Case"


def case_camel(text: str, _args: dict) -> tuple[str, str]:
    words = _to_words(text)
    if not words:
        return text, "camelCase (unchanged)"
    first, *rest = words
    out = first.lower() + "".join(w[:1].upper() + w[1:].lower() for w in rest)
    return out, "camelCase"


def case_snake(text: str, _args: dict) -> tuple[str, str]:
    words = _to_words(text)
    if not words:
        return text, "snake_case (unchanged)"
    return "_".join(w.lower() for w in words), "snake_case"


def case_kebab(text: str, _args: dict) -> tuple[str, str]:
    words = _to_words(text)
    if not words:
        return text, "kebab-case (unchanged)"
    return "-".join(w.lower() for w in words), "kebab-case"


def case(text: str, args: dict) -> tuple[str, str]:
    style = args.get("style", "lower")
    if not isinstance(style, str):
        raise OpError("style must be a string")
    dispatch = {
        "lower": case_lower,
        "upper": case_upper,
        "title": case_title,
        "camel": case_camel,
        "snake": case_snake,
        "kebab": case_kebab,
    }
    fn = dispatch.get(style.lower())
    if fn is None:
        raise OpError(f"unknown case style: {style}")
    return fn(text, args)
