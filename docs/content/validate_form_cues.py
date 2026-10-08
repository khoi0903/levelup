"""Validate per-exercise form cues against seed exercises and active CV rules."""

import argparse
import json
from pathlib import Path
import sys
import unicodedata


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_JSON = ROOT / "app/assets/content/form-cues.json"
EXERCISES_JSON = ROOT / "mongo/seed/exercises.json"
CV_CONFIGS_JSON = ROOT / "mongo/cv-configs.json"
EXPECTED_EXERCISES = 34
EXPECTED_PAIRS = 27
LINE_LIMITS = {"startTip": (1, 2, 12), "cue": (2, 3, 8), "minimal": (1, 1, 4)}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError(f"Invalid JSON number: {value}")


def load_json(path):
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raise ValueError(f"{path}: use UTF-8 without BOM")
    return json.loads(
        raw.decode("utf-8", errors="strict"),
        object_pairs_hook=unique_object,
        parse_constant=reject_constant,
    )


def read_contract():
    """Use every seed slug, including cv.supported=false; union active camera rules."""
    seed = load_json(EXERCISES_JSON)
    if not isinstance(seed, list) or len(seed) != EXPECTED_EXERCISES:
        raise ValueError(f"Seed must contain exactly {EXPECTED_EXERCISES} exercises")
    slugs = set()
    for index, exercise in enumerate(seed):
        if not isinstance(exercise, dict):
            raise ValueError(f"Seed exercise {index}: must be an object")
        slug = exercise.get("slug")
        if not isinstance(slug, str) or not slug or slug != slug.strip():
            raise ValueError(f"Seed exercise {index}: invalid slug")
        if slug in slugs:
            raise ValueError(f"Seed: duplicate slug {slug}")
        slugs.add(slug)

    configs = load_json(CV_CONFIGS_JSON)
    if not isinstance(configs, dict):
        raise ValueError("CV configs must be an object")
    unknown = set(configs) - slugs
    if unknown:
        raise ValueError(f"CV configs: slugs absent from seed: {sorted(unknown)}")
    expected = {slug: set() for slug in slugs}
    for slug, bundle in configs.items():
        if not isinstance(bundle, dict):
            raise ValueError(f"{slug}: CV bundle must be an object")
        active_version = bundle.get("activeVersion")
        versions = bundle.get("configs")
        if type(active_version) is not int or active_version < 1:
            raise ValueError(f"{slug}: invalid activeVersion")
        if not isinstance(versions, list) or not all(isinstance(v, dict) for v in versions):
            raise ValueError(f"{slug}: configs must be an array of objects")
        active = [v for v in versions if type(v.get("version")) is int and v["version"] == active_version]
        if not active:
            raise ValueError(f"{slug}: activeVersion has no matching config")
        for entry in active:
            config = entry.get("config")
            if not isinstance(config, dict):
                raise ValueError(f"{slug}: active config must be an object")
            rules = config.get("formRules", [])
            if not isinstance(rules, list):
                raise ValueError(f"{slug}: formRules must be an array")
            camera_codes = set()
            for rule in rules:
                code = rule.get("code") if isinstance(rule, dict) else None
                if not isinstance(code, str) or not code or code != code.strip():
                    raise ValueError(f"{slug}: formRule requires a nonempty code")
                if code in camera_codes:
                    raise ValueError(f"{slug}: duplicate formRule code {code}")
                camera_codes.add(code)
            expected[slug].update(camera_codes)
    total = sum(len(codes) for codes in expected.values())
    if total != EXPECTED_PAIRS:
        raise ValueError(f"Active CV rules: expected {EXPECTED_PAIRS} pairs, found {total}")
    return expected


def validate(data, expected):
    errors = []

    def check(condition, message):
        if not condition:
            errors.append(message)

    def check_lines(variants, field, location):
        low, high, word_limit = LINE_LIMITS[field]
        if not isinstance(variants, list):
            errors.append(f"{location}: must be an array")
            return
        check(low <= len(variants) <= high, f"{location}: requires {low}–{high} sentences")
        normalized = set()
        for index, sentence in enumerate(variants):
            label = f"{location}[{index}]"
            if not isinstance(sentence, str) or not sentence.strip():
                errors.append(f"{label}: must be nonempty text")
                continue
            check(sentence == sentence.strip(), f"{label}: surrounding whitespace")
            check(unicodedata.normalize("NFC", sentence) == sentence, f"{label}: use NFC text")
            # Spoken sentences contain letters, spaces and basic punctuation only.
            check(all(c.isalpha() or c in " ,.!?;:" for c in sentence),
                  f"{label}: no digits, placeholders, abbreviating symbols, emoji or controls")
            key = " ".join(sentence.casefold().split()).rstrip(" ,.!?;:")
            check(key not in normalized, f"{label}: duplicate sentence")
            normalized.add(key)
            words = len(sentence.split())
            check(words <= word_limit, f"{label}: {words} words exceeds {word_limit}")

    if not isinstance(data, dict):
        return ["Root must be an object"]
    check(set(data) == {"version", "exercises"}, "Root must contain only version and exercises")
    check(type(data.get("version")) is int and data["version"] == 1, "version must be integer 1")
    exercises = data.get("exercises")
    if not isinstance(exercises, dict):
        return errors + ["exercises must be an object"]
    missing = set(expected) - set(exercises)
    extra = set(exercises) - set(expected)
    check(not missing and not extra,
          f"Slugs differ from seed: missing={sorted(missing)}, extra={sorted(extra)}")
    check(len(exercises) == EXPECTED_EXERCISES, f"Requires exactly {EXPECTED_EXERCISES} exercises")
    total_pairs = 0
    for slug, exercise in exercises.items():
        if not isinstance(exercise, dict):
            errors.append(f"{slug}: exercise must be an object")
            continue
        check(set(exercise) == {"startTip", "issues"}, f"{slug}: requires only startTip and issues")
        check_lines(exercise.get("startTip"), "startTip", f"{slug}.startTip")
        issues = exercise.get("issues")
        if not isinstance(issues, dict):
            errors.append(f"{slug}.issues: must be an object (empty is allowed without rules)")
            continue
        total_pairs += len(issues)
        codes = expected.get(slug, set())
        missing_codes, extra_codes = codes - set(issues), set(issues) - codes
        check(not missing_codes and not extra_codes,
              f"{slug}: codes differ from active CV rules: missing={sorted(missing_codes)}, extra={sorted(extra_codes)}")
        for code, issue in issues.items():
            location = f"{slug}.issues.{code}"
            if not isinstance(issue, dict):
                errors.append(f"{location}: must be an object")
                continue
            check(set(issue) == {"cue", "minimal"}, f"{location}: requires only cue and minimal")
            for field in ("cue", "minimal"):
                check_lines(issue.get(field), field, f"{location}.{field}")
    check(total_pairs == EXPECTED_PAIRS, f"Requires exactly {EXPECTED_PAIRS} issue pairs, found {total_pairs}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", type=Path, default=DEFAULT_JSON, help="Alternative form-cues JSON path")
    args = parser.parse_args()
    try:
        expected = read_contract()
        data = load_json(args.json)
        errors = validate(data, expected)
    except (OSError, UnicodeError, ValueError, RecursionError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    total = sum(len(e["startTip"]) + sum(len(i["cue"]) + len(i["minimal"]) for i in e["issues"].values())
                for e in data["exercises"].values())
    print(f"OK: UTF-8 JSON, {EXPECTED_EXERCISES} seed slugs, {EXPECTED_PAIRS} active CV pairs, "
          f"{total} sentences; schema, counts and word limits valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
