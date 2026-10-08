"""Check the bodyweight expansion and its seed/CV/content contracts."""

from collections import Counter
import re
import sys

from validate_form_cues import (
    CV_CONFIGS_JSON,
    EXERCISES_JSON,
    load_json,
)


NEW_SLUGS = {
    "arm-circles", "prone-y-t-raise", "wall-slide",
    "close-grip-wall-push-up", "wall-triceps-extension", "self-resisted-biceps-curl",
    "low-superman", "prone-snow-angel", "prone-row",
    "supine-heel-slide", "slow-mountain-climber", "quadruped-glute-kickback",
    "standing-hamstring-curl", "side-step-touch",
}
CAMERA_SLUGS = {
    "close-grip-wall-push-up", "wall-triceps-extension", "standing-hamstring-curl",
}
REGIONS = {"lower_back", "knee", "shoulder", "neck", "wrist", "ankle", "hip"}
FIELDS = {
    "slug", "nameVi", "nameEn", "instructions", "cues", "primaryMuscle", "difficulty",
    "tracking", "met", "equipment", "contraindications", "isActive", "cv",
}


def validate(seed, configs):
    errors = []

    def check(condition, message):
        if not condition:
            errors.append(message)

    check(len(seed) == 34, "Expected 20 original exercises plus 14 new exercises")
    for field in ("slug", "nameVi", "nameEn"):
        values = [e[field].casefold().strip() for e in seed]
        check(len(set(values)) == len(seed), f"Duplicate {field}")
    for e in seed:
        slug = e["slug"]
        check(re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug) is not None,
              f"{slug}: invalid slug")
        regions = e["contraindications"]
        check(bool(regions) and set(regions) <= REGIONS and len(regions) == len(set(regions)),
              f"{slug}: contraindications must be nonempty, unique, valid regions")
        check(e["cv"].get("supported") is not True or slug in configs,
              f"{slug}: supported without a camera config")
    added = [e for e in seed if e["slug"] in NEW_SLUGS]
    check(len(added) == 14, "Missing bodyweight exercises")
    groups = Counter(e["primaryMuscle"] for e in added)
    check(all(groups[g] >= 3 for g in ("shoulders", "arms", "back")),
          "Need at least three new exercises each for shoulders, arms and back")
    check(sum(groups[g] for g in ("core", "cardio", "legs", "glutes")) == 5,
          "Need five varied core/cardio/legs/glutes exercises")
    for e in added:
        slug = e["slug"]
        check(set(e) == FIELDS, f"{slug}: unexpected seed fields")
        check(e["equipment"] in ([], ["mat"]), f"{slug}: requires equipment")
        check(type(e["difficulty"]) is int and 1 <= e["difficulty"] <= 3,
              f"{slug}: difficulty outside 1–3")
        check(e["tracking"] in ("reps", "duration"), f"{slug}: invalid tracking")
        check(type(e["met"]) in (int, float) and 0 < e["met"] <= 5,
              f"{slug}: invalid MET for gentle movement")
        check(e["isActive"] is True, f"{slug}: must be active")
        check(set(e["cv"]) == {"supported"} and type(e["cv"]["supported"]) is bool,
              f"{slug}: invalid camera flag")
        check(e["cv"]["supported"] == (slug in CAMERA_SLUGS),
              f"{slug}: unexpected camera support")
        check((slug in configs) == (slug in CAMERA_SLUGS),
              f"{slug}: unexpected camera config")
        sentences = [s for s in re.split(r"[.!?]+", e["instructions"]) if s.strip()]
        check(3 <= len(sentences) <= 5, f"{slug}: requires 3–5 instruction sentences")
        check(2 <= len(e["cues"]) <= 3 and all(isinstance(c, str) and c.strip() for c in e["cues"]),
              f"{slug}: requires 2–3 nonempty cues")
        if slug in CAMERA_SLUGS:
            bundle = configs[slug]
            active = [c for c in bundle["configs"] if c["version"] == bundle["activeVersion"]]
            check(bool(active), f"{slug}: missing active camera config")
            for entry in active:
                check(entry["cameraPosition"] == "side", f"{slug}: must use a side view")
                config = entry["config"]
                check(config["placement"] == "table_side", f"{slug}: must use hip-height placement")
                check(config.get("mode", "reps") == "reps", f"{slug}: must count reps")
    check(set(configs) <= {e["slug"] for e in seed}, "CV config absent from seed")
    return errors


def main():
    try:
        errors = validate(load_json(EXERCISES_JSON), load_json(CV_CONFIGS_JSON))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    if errors:
        return 1
    print("OK: 34 unique exercises, 14 bodyweight additions, 3 new camera configs; "
          "schema, equipment, muscle groups, instructions and contraindication regions valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
