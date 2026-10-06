"""Validate the voice content contract using only the Python 3 standard library."""

import argparse
import json
import math
from pathlib import Path
import re
import sys
import unicodedata


STYLE_IDS = {"supportive", "strict", "funny", "calm", "hype", "genz", "minimal"}
EVENT_PLACEHOLDERS = {
    "start_countdown": {"n"},
    "go": set(),
    "rep": {"n"},
    "almost_done": {"left"},
    "last_rep": set(),
    "set_done": {"set", "sets"},
    "rest_start": {"sec"},
    "rest_ending": {"sec"},
    "hold_remaining": {"sec"},
    "hold_last": {"sec"},
    "form_generic": set(),
    "lost_person": set(),
    "exercise_next": {"exercise"},
    "workout_done": {"minutes", "kcal"},
    "personal_record": set(),
}
STYLE_FIELDS = {"nameVi", "descriptionVi", "rate", "pitch", "countEvery", "lines"}
PLACEHOLDER = re.compile(r"\{([a-z]+)\}")
DEFAULT_JSON = Path(__file__).resolve().parents[2] / "app/assets/content/voice-lines.json"


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError(f"Invalid JSON number: {value}")


def load_content(path):
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raise ValueError("Use UTF-8 without BOM")
    return json.loads(
        raw.decode("utf-8", errors="strict"),
        object_pairs_hook=unique_object,
        parse_constant=reject_constant,
    )


def validate(data):
    errors = []

    def check(condition, message):
        if not condition:
            errors.append(message)

    def valid_text(value):
        return (
            isinstance(value, str)
            and bool(value.strip())
            and value == value.strip()
            and unicodedata.normalize("NFC", value) == value
            and not any(unicodedata.category(c) in {"Cc", "Cs", "So"} for c in value)
        )

    def number_between(value, lower, upper):
        return type(value) in (int, float) and math.isfinite(value) and lower <= value <= upper

    if not isinstance(data, dict):
        return ["Root must be an object"]
    check(set(data) == {"version", "styles"}, "Root must contain only version and styles")
    check(type(data.get("version")) is int and data["version"] == 1, "version must be integer 1")
    styles = data.get("styles")
    if not isinstance(styles, dict):
        return errors + ["styles must be an object"]
    check(set(styles) == STYLE_IDS, "styles must contain exactly the 7 fixed IDs")

    for style_id, style in styles.items():
        if not isinstance(style, dict):
            errors.append(f"{style_id}: style must be an object")
            continue
        check(set(style) == STYLE_FIELDS, f"{style_id}: incorrect style fields")
        for field in ("nameVi", "descriptionVi"):
            value = style.get(field)
            check(valid_text(value), f"{style_id}.{field}: invalid text")
            if isinstance(value, str):
                check(not re.search(r"[{}]", value), f"{style_id}.{field}: no placeholders allowed")
        check(number_between(style.get("rate"), 0, 1), f"{style_id}: rate must be 0.0–1.0")
        check(number_between(style.get("pitch"), 0.5, 2), f"{style_id}: pitch must be 0.5–2.0")
        count_every = style.get("countEvery")
        check(type(count_every) is int and count_every >= 1, f"{style_id}: countEvery must be a positive integer")
        if style_id == "minimal":
            check(count_every == 1, "minimal: countEvery must be 1")
        lines = style.get("lines")
        if not isinstance(lines, dict):
            errors.append(f"{style_id}: lines must be an object")
            continue
        check(set(lines) == set(EVENT_PLACEHOLDERS), f"{style_id}: must contain exactly 15 event keys")
        for event, variants in lines.items():
            location = f"{style_id}.{event}"
            if event not in EVENT_PLACEHOLDERS:
                continue
            if not isinstance(variants, list):
                errors.append(f"{location}: must be an array")
                continue
            if event == "hold_last":
                # Only digits may be spoken; one canonical template, no fake variants.
                check(variants == ["{sec}"], f"{location}: must be exactly ['{{sec}}']")
            else:
                low, high = (1, 2) if style_id == "minimal" else (3, 6)
                check(low <= len(variants) <= high, f"{location}: requires {low}–{high} variants")
            text_variants = [v for v in variants if isinstance(v, str)]
            check(len(set(text_variants)) == len(text_variants), f"{location}: duplicate variants")
            for index, sentence in enumerate(variants):
                label = f"{location}[{index}]"
                if not valid_text(sentence):
                    errors.append(f"{label}: must be nonempty NFC text without controls or emoji")
                    continue
                placeholders = set(PLACEHOLDER.findall(sentence))
                check(not re.search(r"[{}]", PLACEHOLDER.sub("", sentence)), f"{label}: malformed placeholder")
                allowed = EVENT_PLACEHOLDERS[event]
                required = allowed - {"kcal"} if event == "workout_done" else allowed
                check(placeholders <= allowed, f"{label}: unknown or wrong-event placeholder")
                check(required <= placeholders, f"{label}: missing required placeholder")
                if event in {"rep", "almost_done"}:
                    limit = 4 if event == "rep" else 8
                    check(len(sentence.split()) <= limit, f"{label}: exceeds {limit} words")
            if event == "workout_done":
                check(any("{minutes}" in v and "{kcal}" not in v for v in text_variants), f"{location}: needs a fallback without kcal")
        if style_id == "minimal":
            check(lines.get("rep") == ["{n}"], "minimal.rep must be exactly ['{n}']")

    for style_id in ("calm", "strict", "hype"):
        style = styles.get(style_id)
        if isinstance(style, dict) and number_between(style.get("rate"), 0, 1):
            rate = style["rate"]
            check(rate < 0.5 if style_id == "calm" else rate > 0.5, f"{style_id}: incorrect rate relative to normal 0.5")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", type=Path, default=DEFAULT_JSON, help="JSON content path")
    args = parser.parse_args()
    try:
        data = load_content(args.json)
    except (OSError, UnicodeError, ValueError, RecursionError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    errors = validate(data)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    total = sum(len(variants) for style in data["styles"].values() for variants in style["lines"].values())
    print(f"OK: UTF-8 JSON, 7 styles, 15 events/style, {total} templates; placeholders and word limits valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
