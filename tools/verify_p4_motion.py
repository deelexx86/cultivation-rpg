"""Measure presentation cadence and frame intervals of identical combat tick windows."""
import argparse
import json
import math
from pathlib import Path
import statistics
import subprocess
from uuid import uuid4

from verify_combat_ui import Game, ESC, combat, held, tap

RATES = {"normal": 1, "half": 0.5, "quarter": 0.25}
FIRST_TICK, LAST_TICK = 8, 42
CHANNELS = {"hero_m": 5, "opponent_m": 6, "projectile_m": 7, "camera_m": 8,
            "landmark_px": 9, "projectile_px": 10, "opponent_px": 11, "hero_px": 12}


def summary(values):
    ordered = sorted(values)
    return {"median": round(statistics.median(ordered), 5),
            "p95": round(ordered[int(0.95 * (len(ordered) - 1))], 5),
            "max": round(ordered[-1], 5)}


def sample(renderer, scene, pace, args, folder):
    tag = f"{renderer}-{scene}-{pace}"
    trace = folder / f"{tag}.motion.json"
    slot = f"motion-{uuid4().hex[:16]}"
    prep = subprocess.run(
        [str(args.godot), "--headless", "--path", str(args.game), "--script",
         "res://tests/combat_motion_fixture.gd", "--", slot, scene, pace],
        capture_output=True, text=True, encoding="utf-8", timeout=20,
    )
    assert prep.returncode == 0 and "ERROR:" not in prep.stdout + prep.stderr, prep.stdout + prep.stderr
    with Game([str(args.export), "--fullscreen", "--resolution", "1920x1080"], folder, tag,
              renderer, "qi", slot, [f"--p4-motion={trace}"]) as game:
        restored = game.wait("fixture restored on system pause", lambda d: d["paused"] and d["modal"] == "restore")
        assert combat(restored)["tick"] == 0 and len(combat(restored)["projectiles"]) == 1
        with held("D"):
            tap(ESC)
            after = game.wait("same window of combat ticks", lambda d: combat(d)["tick"] >= LAST_TICK + 2)
        assert after["resolution"] == [1920,1080], after["resolution"]
        assert combat(after)["perception"] == (pace != "normal")
        game.leave()
    all_frames = json.loads(trace.read_text(encoding="utf-8"))
    rows = [row for row in all_frames if FIRST_TICK <= row[1] < LAST_TICK
            and (len(row) == 16 or not row[16])]
    if not args.baseline:
        paused = [row for row in all_frames if row[16]]
        initial = [row for row in paused if row[1] == 0]
        final = [row for row in paused if row[1] > LAST_TICK]
        for frozen in (initial, final):
            assert len(frozen) >= 2, (tag, "too few rendered frames on pause")
            assert all(row[1:4] == frozen[0][1:4] for row in frozen), (tag, "combat advanced on pause")
            assert all(row[5:16] == frozen[0][5:16] for row in frozen), (tag, "pose or camera changed on pause")
        assert all(math.dist(initial[0][index], [v / 1000 for v in initial[0][index+8]]) < 0.0001
                   for index in (5, 6, 7)), (tag, "load presented a pose other than the snapshot")
    assert len(rows) >= 24 and rows[0][1] <= FIRST_TICK + 2 and rows[-1][1] >= LAST_TICK - 3, tag
    intervals = [(b[0] - a[0]) / 1000 for a, b in zip(rows, rows[1:])]
    elapsed = (rows[-1][0] - rows[0][0]) / 1_000_000
    physics_rate = (rows[-1][4] - rows[0][4]) / elapsed
    updates = rows[-1][1] - rows[0][1]
    assert abs(updates / (rows[-1][4] - rows[0][4]) - RATES[pace]) < 0.04, tag
    transforms = {}
    for channel, index in CHANNELS.items():
        distances = [math.dist(a[index], b[index]) for a, b in zip(rows, rows[1:])]
        threshold = 0.00001 if channel.endswith("_m") else 0.0005
        transforms[channel] = {
            "hold_percent": round(100 * sum(d < threshold for d in distances) / len(distances), 2),
            "step": summary(distances),
            "travel": round(sum(distances), 5),
        }
    authority = {str(row[1]):row[13:16] for row in rows}
    return {"frames": len(rows), "fps": round((len(rows)-1) / elapsed, 2),
            "physics_hz": round(physics_rate, 2), "combat_hz": round(updates / elapsed, 2),
            "frame_ms": summary(intervals), "transforms": transforms,
            "authority": authority, "trace": trace.name,
            "frozen_frames": {"initial": len(initial), "final": len(final)} if not args.baseline else None}


def compare_poses(actual, expected, label):
    shared = actual.keys() & expected.keys()
    assert len(shared) >= 24, (label, "too few matching combat ticks")
    assert all(actual[tick] == expected[tick] for tick in shared), (label, "authoritative trajectory differs")


def main():
    parser = argparse.ArgumentParser()
    for key in ("godot", "game", "export", "output"):
        parser.add_argument(f"--{key}", required=True, type=lambda path: Path(path).resolve())
    parser.add_argument("--baseline", action="store_true", help="Capture baseline without smoothing assertions")
    parser.add_argument("--compare", type=Path, help="Confirm authoritative trajectories match an earlier summary")
    args = parser.parse_args()
    reference = json.loads(args.compare.read_text(encoding="utf-8")) if args.compare else None
    args.output.mkdir(parents=True)
    cases = {}
    for renderer in ("forward_plus", "gl_compatibility"):
        cases[renderer] = {}
        for scene in ("ground", "air"):
            results = {pace: sample(renderer, scene, pace, args, args.output) for pace in RATES}
            authority = results["normal"]["authority"]
            for pace, data in results.items():
                label = (renderer, scene, pace)
                compare_poses(data["authority"], authority, label)
                if reference:
                    compare_poses(data["authority"], reference[renderer][scene][pace]["authority"], (*label, "reference"))
                if not args.baseline:
                    names = ["hero_m", "projectile_m", "camera_m", "landmark_px", "projectile_px"]
                    if scene == "ground":
                        names += ["opponent_m", "opponent_px"]
                    for name in names:
                        transform = data["transforms"][name]
                        assert transform["travel"] > (0.2 if name.endswith("_m") else 3), (renderer, scene, pace, name, transform)
                        assert transform["hold_percent"] <= 4, (renderer, scene, pace, name, transform)
                print(f"P4_MOTION_SAMPLE {renderer} {scene} {pace} fps={data['fps']} p95={data['frame_ms']['p95']}ms "
                      f"hero hold={data['transforms']['hero_m']['hold_percent']}% "
                      f"camera hold={data['transforms']['landmark_px']['hold_percent']}% ", flush=True)
            cases[renderer][scene] = results
    (args.output / "summary.json").write_text(json.dumps(cases, indent=2) + "\n", encoding="utf-8")
    print("P4_MOTION_BASELINE" if args.baseline else "P4_MOTION_PASS")


if __name__ == "__main__":
    main()
