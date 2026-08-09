#!/usr/bin/env python3
"""Build the personal baseline from a generated mSCP CIS Level 1 baseline."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import yaml


def load_yaml(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as stream:
        data = yaml.safe_load(stream)
    if not isinstance(data, dict):
        raise ValueError(f"expected a YAML mapping in {path}")
    return data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    source = load_yaml(args.source)
    profile = load_yaml(args.profile)

    if profile.get("name") != "personal":
        raise ValueError("profile name must be personal")
    if source.get("parent_values") != profile.get("source_baseline"):
        raise ValueError("source baseline does not match profile source_baseline")

    excluded = profile.get("excluded_rules")
    overridden = profile.get("overridden_rules")
    if not isinstance(excluded, list) or not all(isinstance(item, str) for item in excluded):
        raise ValueError("excluded_rules must be a list of rule IDs")
    if not isinstance(overridden, list) or not all(isinstance(item, str) for item in overridden):
        raise ValueError("overridden_rules must be a list of rule IDs")
    if len(excluded) != len(set(excluded)) or len(overridden) != len(set(overridden)):
        raise ValueError("profile rule lists must not contain duplicates")
    if set(excluded) & set(overridden):
        raise ValueError("a rule cannot be both excluded and overridden")

    custom_rules_dir = args.profile.parent / "rules"
    missing_overrides = [
        rule_id for rule_id in overridden if not (custom_rules_dir / f"{rule_id}.yaml").is_file()
    ]
    if missing_overrides:
        raise ValueError(f"missing custom rule files: {', '.join(missing_overrides)}")

    profile_sections = source.get("profile")
    if not isinstance(profile_sections, list):
        raise ValueError("source baseline has no profile sections")

    source_rule_ids: set[str] = set()
    kept_sections: list[dict[str, Any]] = []
    removed_rule_ids: set[str] = set()
    for section in profile_sections:
        if not isinstance(section, dict) or not isinstance(section.get("rules"), list):
            raise ValueError("invalid profile section in source baseline")
        source_rule_ids.update(section["rules"])
        kept_rules = []
        for rule_id in section["rules"]:
            if rule_id in excluded:
                removed_rule_ids.add(rule_id)
            else:
                kept_rules.append(rule_id)
        if kept_rules:
            kept_section = dict(section)
            kept_section["rules"] = kept_rules
            kept_sections.append(kept_section)

    active_overrides = set(overridden) & source_rule_ids
    if not active_overrides:
        raise ValueError("none of the custom rules apply to this source baseline")

    platform = source.get("platform")
    if not isinstance(platform, dict) or not platform.get("version"):
        raise ValueError("source baseline is missing its platform version")
    version = str(platform["version"])

    source["title"] = f"macOS {version}: {profile['title']}"
    source["description"] = profile["description"]
    source["authors"] = [
        {
            "name": "macos-mscp-scan contributors",
            "organization": "macos-mscp-scan",
        }
    ]
    source["profile"] = kept_sections

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as stream:
        yaml.safe_dump(source, stream, sort_keys=False, allow_unicode=True)

    print(
        f"Built {args.output}: "
        f"{sum(len(section['rules']) for section in kept_sections)} rules, "
        f"{len(removed_rule_ids)} out-of-scope rules removed, "
        f"{len(active_overrides)} local-state checks customized."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
