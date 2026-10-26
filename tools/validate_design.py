#!/usr/bin/env python3
"""Read-only checks for this design package and its EXAMPLE fixtures.

These checks do not run the game or validate production balance. Fixture-specific
dates/counts are intentional; update them when the reference design is revised.
Life boundaries use TIME-08's strict comparison for this fixture only (PROPOSAL).
"""

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
ERRORS = []
TEXTS = {}
JSONS = {}
COUNTS = dict(checks=0, text_files=0, markdown_files=0, local_links=0,
              json_files=0, milestones=0, checkpoints=0)
EXAMPLES = ("progression-milestones", "campaign-white-sedge", "resource-node",
            "quest-and-contract", "long-action-preview")


def check(condition, message):
    COUNTS["checks"] += 1
    if not condition:
        ERRORS.append(message)


def equal(actual, expected, message):
    check(actual == expected,
          f"{message}: expected {repr(expected)[:180]}, got {repr(actual)[:180]}")


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def invalid_constant(value):
    raise ValueError(f"non-JSON numeric constant: {value}")


def local_target(source, target):
    parsed = urlsplit(target.strip("<>"))
    if parsed.scheme or parsed.netloc:
        check(parsed.scheme != "file", f"{source}: nonportable file URI {target}")
        return
    if not parsed.path:
        return  # Fragment-only links are not checked by this small validator.
    COUNTS["local_links"] += 1
    resolved = (ROOT / source).parent.joinpath(unquote(parsed.path)).resolve()
    inside = resolved == ROOT or ROOT in resolved.parents
    check(inside, f"{source}: link escapes the package: {target}")
    if inside:
        check(resolved.exists(), f"{source}: missing local target: {target}")


def scan_files():
    extensions = {".md", ".json", ".py", ".txt", ".yml", ".yaml", ".toml"}
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or ".git" in path.relative_to(ROOT).parts:
            continue
        if path.suffix not in extensions and path.name not in {".gitignore", ".gitattributes"}:
            continue
        name = path.relative_to(ROOT).as_posix()
        try:
            raw = path.read_bytes()
            text = raw.decode("utf-8")
        except (OSError, UnicodeError) as error:
            check(False, f"{name}: cannot read UTF-8: {error}")
            continue
        COUNTS["text_files"] += 1
        check(b"\r" not in raw, f"{name}: use LF line endings")
        check(raw.endswith(b"\n"), f"{name}: missing final newline")
        TEXTS[name] = text
        if path.suffix == ".md":
            COUNTS["markdown_files"] += 1
            prose = re.sub(r"(?ms)^(```|~~~).*?^\1[ \t]*$", "", text)
            prose = re.sub(r"`[^`\n]*`", "", prose)
            inline = re.findall(r"!?\[[^\]]*\]\(\s*(<[^>]+>|[^\s)]+)", prose)
            references = re.findall(r"(?m)^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)", prose)
            for target in inline + references:
                local_target(name, target)
        if path.suffix == ".json":
            COUNTS["json_files"] += 1
            try:
                value = json.loads(text, object_pairs_hook=unique, parse_constant=invalid_constant)
                JSONS[name] = value
                if path.parent == ROOT / "examples":
                    equal(value["document_status"], "EXAMPLE", f"{name}: document status")
                    check(value["not_for_runtime"] is True, f"{name}: not_for_runtime must be true")
                    check(bool(value["source_documents"]), f"{name}: source_documents is empty")
                    for target in value["source_documents"]:
                        local_target(name, target)
            except (ValueError, KeyError, TypeError) as error:
                check(False, f"{name}: invalid JSON or example metadata: {error}")
    for stem in EXAMPLES:
        check(f"examples/{stem}.example.json" in JSONS, f"missing readable example: {stem}")


def fixture(stem):
    return JSONS[f"examples/{stem}.example.json"]


def by_id(rows, key, label):
    result = {row[key]: row for row in rows}
    equal(len(result), len(rows), f"{label}: unique {key}")
    return result


def periods(rows, start="start_campaign_year", end="end_campaign_year"):
    for row in rows:
        label = row.get("interval_id", "period")
        equal(row[end] - row[start], row["duration_years"], f"{label}: duration")
        check(row[end] > row[start], f"{label}: positive duration")


def progression_and_campaign():
    progression, campaign = fixture(EXAMPLES[0]), fixture(EXAMPLES[1])
    rows = progression["milestones"]
    COUNTS["milestones"] = len(rows)
    equal(len(rows), 16, "progression: reference milestone count")
    milestones = by_id(rows, "milestone_id", "progression")
    equal([row["rank"] for row in rows], list(range(16)), "progression: ranks 0..15")
    check(all(type(row["rank"]) is int for row in rows), "progression: integer ranks")
    caps = [row["lifespan_cap_years"] for row in rows]
    check(all(type(cap) is int and cap > 0 for cap in caps), "progression: positive integer caps")
    check(all(a < b for a, b in zip(caps, caps[1:])), "progression: strictly increasing caps")
    check(progression["victory_milestone"]["lifespan_cap_years"] is None,
          "progression: unbounded soul has no finite numeric cap")
    victory_rule = progression["victory_milestone"]
    equal(victory_rule["lifespan_cap_status"], "SOUL_UNBOUNDED_AFTER_VICTORY", "victory: explicit soul lifespan meaning")
    check(victory_rule["soul_lifespan_unbounded"] is True, "victory: immortal soul")
    equal(victory_rule["body_lifespan_cap_status"], "OPEN", "victory: body cap not inferred")
    cal = campaign["calendar_contract"]
    equal((campaign["start_world_year"], campaign["start_campaign_year"], cal["start_world_year"], cal["start_soul_age_years"]),
          (0, 0, 0, 0), "calendar: fixed zero start")
    equal(cal["initial_soul_lifespan_cap_years"], rows[0]["lifespan_cap_years"], "calendar: initial cap matches progression")
    equal(cal["initial_soul_lifespan_cap_years"], 100, "calendar: initial soul cap 100")
    equal((cal["fixture_unit"], cal["runtime_precision"], cal["calendar_structure"]),
          ("calendar_year", "day", "earth_analog"), "calendar: fixture years distinct from runtime days")
    check(cal["runtime_exact_dates_assigned"] is False, "calendar: no invented exact fixture dates")
    check(cal["starting_epoch_selection"] is False, "calendar: no starting epoch selection")
    equal(cal["forced_ascension_world_year"], 3000, "calendar: shared epoch boundary")
    check(cal["forced_ascension_requires_victory"] is True and cal["voluntary_ascension_after_victory"] is True,
          "calendar: ascension rules apply after victory")
    check(campaign["design_guardrails"]["post_victory_soul_lifespan_unbounded"] is True
          and campaign["design_guardrails"]["post_victory_body_lifespan_specified"] is False,
          "campaign: soul/body post-victory distinction")
    equal(campaign["progression_reference_file"], EXAMPLES[0] + ".example.json", "progression reference")
    bodies = by_id(campaign["body_definitions"], "body_id", "bodies")
    points = campaign["checkpoints"]
    COUNTS["checkpoints"] = len(points)
    equal(len(points), 32, "campaign: reference checkpoint count")
    years = [point["campaign_year"] for point in points]
    equal(years, sorted(set(years)), "campaign: strictly ordered checkpoint years")
    seen, soul_cap, previous = set(), 0, None
    for point in points:
        year, body_id, mid = point["campaign_year"], point["body_id"], point["milestone_id"]
        body = bodies[body_id]
        label = f"checkpoint {year}"
        elapsed = year - campaign["start_campaign_year"]
        equal(point["world_year"] - campaign["start_world_year"], elapsed, label + ": world offset")
        equal(point["body_age_years"], body["age_at_entry_years"] + year - body["entry_campaign_year"],
              label + ": body age")
        if previous:
            check(elapsed < previous["soul_lifespan_cap_years"], label + ": survives under PREVIOUS soul cap")
            if body_id == previous["body_id"]:
                check(point["body_age_years"] < previous["body_lifespan_cap_years"],
                      label + ": survives under PREVIOUS body cap")
            else:
                equal((previous["event_kind"], point["event_kind"]), ("body_death", "reincarnation"),
                      label + ": body change follows death")
                equal((previous["campaign_year"], year, point["body_age_years"]), (440, 445, 18),
                      label + ": reference transfer")
                equal(bodies[previous["body_id"]]["death_campaign_year"], previous["campaign_year"],
                      label + ": recorded body death")
                equal(year, body["entry_campaign_year"], label + ": new body entry")
        first = mid not in seen
        check(point["soul_milestone_first_time"] is first, label + ": first personal achievement flag")
        if first:
            soul_cap = max(soul_cap, milestones[mid]["lifespan_cap_years"])
            seen.add(mid)
        equal(point["body_lifespan_cap_years"], milestones[mid]["lifespan_cap_years"], label + ": body cap")
        equal(point["soul_lifespan_cap_years"], soul_cap, label + ": earned soul cap without repeat reward")
        previous = point
    victory = points[-1]
    equal((victory["event_kind"], victory["achieved_milestone_id"], victory["cap_measurement"]),
          ("victory", "divine_transformation", "before_victory"), "victory interpretation")
    equal(victory["soul_lifespan_cap_years"] - years[-1], 315, "reference reserve before victory")
    equal(victory["soul_lifespan_cap_years"], 1300, "reference pre-victory cap")
    npc = by_id(campaign["npc_events"], "npc_id", "NPC events")
    for row in npc.values():
        equal(row["age_years"], row["age_at_reference_years"] + row["campaign_year"] - row["age_reference_campaign_year"],
              row["npc_id"] + ": age at death")
    for row in campaign["npc_events"] + campaign["calendar_events"]:
        equal(row["world_year"] - campaign["start_world_year"], row["campaign_year"] - campaign["start_campaign_year"],
              "calendar event: world offset")
    intervals = by_id(campaign["illustrative_intervals"], "interval_id", "intervals")
    periods(list(intervals.values()))
    r = campaign["retreat_interruption_example"]
    equal(r["planned_start_campaign_year"] + r["planned_duration_years"], r["planned_end_campaign_year"], "planned retreat")
    equal(r["elapsed_practice_years"] + r["remaining_practice_years"], r["planned_duration_years"], "90 years of practice")
    equal(r["actual_completion_campaign_year"] - r["planned_start_campaign_year"],
          r["elapsed_practice_years"] + r["recovery_duration_years"] + r["remaining_practice_years"], "98 = 34 + 8 + 56")
    comparison = campaign["one_body_comparison"]
    equal(comparison["two_body_victory_campaign_year"] - comparison["victory_campaign_year"],
          comparison["additional_calendar_years"], "985 - 810 = 175")
    equal(sum(comparison["additional_years_components"].values()), comparison["additional_calendar_years"], "5 + 140 + 30 = 175")
    for key, interval in (("soul_transfer", "soul_transfer"), ("restoration_after_transfer", "body_rebuilding"),
                          ("lost_uncommitted_body_cultivation", "uncommitted_late_nascent_growth")):
        equal(comparison["additional_years_components"][key], intervals[interval]["duration_years"], key + ": interval match")
    equal(comparison["death_to_restored_milestone_years"], intervals["body_rebuilding"]["end_campaign_year"] - 440,
          "restoration after death includes transfer once")
    pacing = campaign["pacing_estimate"]
    equal(sum(phase["estimated_real_hours"] for phase in pacing["phases"]), pacing["estimated_real_hours_total"], "pacing sum")


def table_rows(name):
    return [[cell.strip() for cell in line.strip().strip("|").split("|")]
            for line in TEXTS[name].splitlines() if line.lstrip().startswith("|")]


def number(cell):
    return int(re.search(r"\d+", cell).group())


def compare_tables():
    campaign, progression = fixture(EXAMPLES[1]), fixture(EXAMPLES[0])
    bodies = {row["body_id"]: row["name_ru"] for row in campaign["body_definitions"]}
    points = campaign["checkpoints"]
    for filename, balance in (("10-white-sedge-campaign.md", False), ("11-balance-and-pacing.md", True)):
        rows = [row for row in table_rows("docs/" + filename) if len(row) == 6 and row[0].isdigit()]
        equal(len(rows), len(points), filename + ": checkpoint row count")
        for row, point in zip(rows, points):
            age = number(row[1].split("/")[-1]) if balance else number(row[2])
            cap_columns = (3, 4) if balance else (4, 5)
            actual = (number(row[0]), age, number(row[cap_columns[0]]), number(row[cap_columns[1]]))
            expected = tuple(point[key] for key in ("campaign_year", "body_age_years", "body_lifespan_cap_years", "soul_lifespan_cap_years"))
            equal(actual, expected, filename + f": row {point['campaign_year']}")
            if balance:
                equal(re.search(r"`([^`]+)`", row[2]).group(1), point["milestone_id"], filename + ": milestone")
                equal(row[5].startswith("Да"), point["soul_milestone_first_time"], filename + ": first achievement")
                equal(row[1].split("/")[0].strip(), {"liang_shen": "ЛШ", "yun_ze": "ЮЦ"}[point["body_id"]], filename + ": body")
            else:
                equal(row[1], bodies[point["body_id"]], filename + ": body")
    rows = table_rows("docs/11-balance-and-pacing.md")
    for realm in dict.fromkeys(row["realm_name_ru"] for row in progression["milestones"]):
        found = [row for row in rows if len(row) == 5 and row[0] == realm]
        equal(len(found), 1, "balance cap table: " + realm)
        if found:
            equal([number(cell) for cell in found[0][1:]],
                  [row["lifespan_cap_years"] for row in progression["milestones"] if row["realm_name_ru"] == realm], realm + ": caps")
    actual = [tuple(map(int, re.findall(r"\d+", row[1]))) + (number(row[2]),)
              for row in table_rows("docs/10-white-sedge-campaign.md") if len(row) == 3 and re.fullmatch(r"\d+–\d+", row[1])]
    equal(actual, [(p["start_campaign_year"], p["end_campaign_year"], p["estimated_real_hours"])
                   for p in campaign["pacing_estimate"]["phases"]], "campaign pacing table")


def resource_and_quests():
    resource, quests, campaign = fixture(EXAMPLES[2]), fixture(EXAMPLES[3]), fixture(EXAMPLES[1])
    observed, before, after = (resource[key] for key in ("first_observation", "before_extraction", "after_extraction"))
    equal(before["plant_age_years"], observed["plant_age_years"] + before["world_year"] - observed["world_year"], "plant age 600 + 20 = 620")
    equal(after["world_year"], before["world_year"], "extraction adds no calendar years")
    equal(after["node_status"], "harvested", "harvested source")
    check(after["whole_plant_available_at_source"] is False, "whole plant must not remain as duplicate source")
    items = by_id(after["produced_items"], "item_id", "produced resource items")
    for item in items.values():
        equal(item["origin_age_years_at_harvest"], before["plant_age_years"], "damage preserves origin age")
    roots = [item for item in items.values() if item["part"] == "root"]
    equal(len(roots), 1, "one damaged root")
    check(roots[0]["integrity"] != before["condition_properties"]["integrity"] and roots[0]["can_replace_whole_living_root"] is False,
          "damage prevents whole-root substitution")
    check(resource["committed_operation"]["repeat_original_roll_allowed"] is False, "harvest cannot reroll")
    quest = quests["personal_quest"]
    changes = {row["world_year"]: row for row in quest["transitions"]}
    check(quest["item_exists_in_world_independently_of_quest"] is True, "quest item persists independently")
    check(changes[0]["reward_promise_valid"] is True and changes[0]["objective_item_obtained"] is False
          and changes[0]["reward_claim_available"] is False, "accepted promise is not an immediate reward")
    for year in (15, 24):
        equal(changes[year]["state"], "expired_issuer_dead", "expired personal quest")
        check(changes[year]["reward_claim_available"] is False and changes[year]["reward_paid"] is False, "no posthumous personal reward")
        check(changes[year]["reward_promise_valid"] is False, "personal promise expires with issuer")
        check(changes[year]["objective_item_obtained"] is (year == 24), "item acquired only after expiration")
    check(changes[15]["objective_item_deleted"] is False, "issuer death does not delete item")
    equal(changes[24]["objective_item_location"], "player_inventory", "item may be found after expiration")
    role = quests["merchant_role"]
    check(role["former_person_id"] != role["new_person_id"] and role["inherits_personal_trust"] is False,
          "new merchant has a new identity and relationship")
    check(role["inherits_old_personal_reward_debt"] is False, "merchant role does not inherit personal debt")
    first, final = quests["first_guest_elder_contract"], quests["final_chamber_contract"]
    equal(first["scheduled_end_world_year"] - first["start_world_year"], first["term_years"], "150-year guest contract")
    equal((first["start_world_year"], first["scheduled_end_world_year"], first["actual_end_world_year"]), (300, 450, 440), "first contract dates")
    equal(first["actual_end_world_year"], campaign["contracts"][0]["actual_end_campaign_year"], "contract matches campaign death")
    check(first["new_body_automatically_inherits_personal_access"] is False, "new body must establish personal access")
    equal(final["representative_death_world_year"], 830, "final signer's death")
    check(final["representative_death_terminates_contract"] is False and final["contract_scope"] == "institutional",
          "institutional chamber right survives signer")


def preview():
    data, campaign = fixture(EXAMPLES[4]), fixture(EXAMPLES[1])
    visible, resolved = data["player_visible_preview"], data["author_only_resolution_fixture"]
    start, duration = visible["current_world_year"], visible["planned_duration_years"]
    equal(start + duration, visible["planned_end_world_year"], "preview: 312 + 90 = 402")
    for scope, age, end_age in (("soul", "elapsed_years", "elapsed_at_planned_end_years"),
                                ("body", "age_years", "age_at_planned_end_years")):
        state = visible[scope]
        cap = state["current_lifespan_cap_years"]
        equal(state[age] + duration, state[end_age], scope + ": preview age")
        equal(cap - state[age], state["remaining_before_years"], scope + ": current reserve")
        equal(cap - state[end_age], state["remaining_at_end_under_current_cap_years"], scope + ": reserve uses CURRENT cap")
        check(state[end_age] < cap, scope + ": survives until planned completion under current cap")
    check(visible["calendar_advances_before_confirmation"] is False and visible["rng_advances_on_preview"] is False,
          "preview does not mutate time or randomness")
    check(resolved["must_not_be_used_as_player_foreknowledge"] is True, "author-only result marked private")
    check(str(resolved["interrupt_world_year"]) not in json.dumps(visible, ensure_ascii=False), "preview leaks the future call year")
    check(all(o["exact_future_call_year_known"] is False for o in visible["known_obligations"]), "future call is not known")
    periods([resolved["injury_recovery"], resolved["resumed_practice"]], "start_world_year", "end_world_year")
    equal(resolved["completed_practice_years"], resolved["interrupt_world_year"] - start, "practice before interruption")
    equal(resolved["completed_practice_years"] + resolved["remaining_practice_years"], duration, "remaining practice")
    total = duration + resolved["injury_recovery"]["duration_years"] + resolved["defense_battle_adds_calendar_years"]
    equal(total, 98, "reference retreat elapsed years")
    equal(total, resolved["actual_total_elapsed_years"], "recorded retreat total")
    equal(start + total, resolved["final_world_year"], "actual final world year")
    point = next(p for p in campaign["checkpoints"] if p["campaign_year"] == resolved["final_world_year"])
    for target, source in (("final_body_age_years", "body_age_years"), ("final_soul_lifespan_cap_years", "soul_lifespan_cap_years"),
                           ("final_body_lifespan_cap_years", "body_lifespan_cap_years")):
        equal(resolved[target], point[source], "resolved preview matches campaign: " + target)


def main():
    scan_files()
    for operation in (progression_and_campaign, compare_tables, resource_and_quests, preview):
        try:
            operation()
        except (KeyError, TypeError, ValueError, IndexError, AttributeError, StopIteration) as error:
            check(False, f"{operation.__name__}: missing data or invalid fixture shape: {error}")
    print("Design documentation / EXAMPLE fixture validation")
    print(", ".join(f"{key}={value}" for key, value in COUNTS.items()))
    for error in ERRORS:
        print("ERROR:", error)
    print(f"Errors: {len(ERRORS)}")
    print("Scope: documents and reference arithmetic; no game execution, production balance or playtest results.")
    return 1 if ERRORS else 0


if __name__ == "__main__":
    sys.exit(main())
