"""Exercise the project and Windows release through native keyboard and mouse input.

A P4 probe records observable state and screenshots. The harness does not edit
game state, synthesize engine events or invoke gameplay methods.
"""
import argparse
from contextlib import contextmanager
import ctypes as c
from ctypes import wintypes as w
import json
from pathlib import Path
import re
import statistics
import sys
import subprocess
import time
from uuid import uuid4

user = c.WinDLL("user32", use_last_error=True)
user.GetForegroundWindow.restype = w.HWND
user.SetForegroundWindow.argtypes = [w.HWND]
user.GetWindowRect.argtypes = [w.HWND, c.POINTER(w.RECT)]
user.ClientToScreen.argtypes = [w.HWND, c.POINTER(w.POINT)]
user.GetClientRect.argtypes = [w.HWND, c.POINTER(w.RECT)]
user.GetWindowTextW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
user.keybd_event.argtypes = [w.BYTE, w.BYTE, w.DWORD, c.c_size_t]
user.mouse_event.argtypes = [w.DWORD, w.DWORD, w.DWORD, w.DWORD, c.c_size_t]
user.SetProcessDPIAware()
kernel = c.WinDLL("kernel32", use_last_error=True)
kernel.OpenProcess.argtypes = [w.DWORD, w.BOOL, w.DWORD]
kernel.OpenProcess.restype = w.HANDLE
kernel.CloseHandle.argtypes = [w.HANDLE]
psapi = c.WinDLL("psapi", use_last_error=True)
user.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]


class ProcessMemory(c.Structure):
    _fields_ = [("cb", w.DWORD), ("faults", w.DWORD)] + [
        (name, c.c_size_t) for name in ("peak_working", "working", "peak_paged_pool",
                                       "paged_pool", "peak_nonpaged_pool", "nonpaged_pool",
                                       "pagefile", "peak_pagefile")
    ]


psapi.GetProcessMemoryInfo.argtypes = [w.HANDLE, c.POINTER(ProcessMemory), w.DWORD]


def working_set(hwnd):
    pid = w.DWORD()
    user.GetWindowThreadProcessId(hwnd, c.byref(pid))
    process = kernel.OpenProcess(0x0410, False, pid.value)
    if not process:
        return None
    try:
        info = ProcessMemory()
        info.cb = c.sizeof(info)
        if psapi.GetProcessMemoryInfo(process, c.byref(info), info.cb):
            return {"current_bytes": info.working, "peak_bytes": info.peak_working}
        return None
    finally:
        kernel.CloseHandle(process)

ESC, TAB, SPACE, CTRL, SHIFT, F10, F12 = 27, 9, 32, 17, 16, 121, 123
HERO = "hero"
YOUNG = "stone.young"
ELITE = "stone.horned"
AIR = "stand.air"
CROSSING = "route.air"


def window(fragment):
    matches = []
    callback_type = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)

    @callback_type
    def visit(hwnd, _):
        title = c.create_unicode_buffer(256)
        user.GetWindowTextW(hwnd, title, len(title))
        if fragment in title.value:
            matches.append(hwnd)
        return True

    user.EnumWindows(visit, 0)
    return matches[0] if matches else None


def key(value, up=False):
    vk = ord(value) if isinstance(value, str) else value
    user.keybd_event(vk, user.MapVirtualKeyW(vk, 0), 2 if up else 0, 0)


def tap(value):
    key(value)
    time.sleep(0.045)
    key(value, True)


@contextmanager
def held(*values):
    for value in values:
        key(value)
    try:
        yield
    finally:
        for value in reversed(values):
            key(value, True)


def combat(data):
    return data["combat"]


def actor(data, name=HERO):
    return combat(data)["actors"][name]


class Game:
    def __init__(self, command, directory, tag, renderer, rank, slot=None, extra_args=()):
        self.slot = slot or f"p4-{uuid4().hex[:16]}"
        self.path = directory / f"{tag}.json"
        self.log = directory / f"{tag}.log"
        self.output = self.log.open("wb")
        self.process = subprocess.Popen(
            [*command, "--rendering-method", renderer, "--position", "120,80", "--",
             "--p4", f"--rank={rank}", f"--campaign={self.slot}", f"--p4-probe={self.path}", *extra_args],
            stdout=self.output, stderr=subprocess.STDOUT,
        )
        self.data = {}
        self.hwnd = None
        self.captures = 0

    def __enter__(self):
        try:
            self.wait("real game ready", lambda data: bool(data), seconds=20)
            self.hwnd = window(self.slot)
            if not self.hwnd:
                raise AssertionError("No native game window")
            if self.hwnd != user.GetForegroundWindow():
                key(18)
                user.SetForegroundWindow(self.hwnd)
                key(18, True)
            if self.hwnd != user.GetForegroundWindow():
                raise AssertionError("Native game window did not receive foreground focus")
        except BaseException:
            self.__exit__(*sys.exc_info())
            raise
        return self

    def __exit__(self, exc_type, _value, _trace):
        if self.process.poll() is None:
            subprocess.run(["taskkill", "/PID", str(self.process.pid), "/T", "/F"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False, timeout=8)
            self.process.wait(timeout=8)
        self.output.close()
        log = self.log.read_text(encoding="utf-8", errors="replace")
        if exc_type is None:
            assert self.process.returncode == 0, log
            assert not re.search(r"(?im)(SCRIPT ERROR:|(^|\s)ERROR:|FATAL)", log), log

    def read(self):
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
        except (ValueError, OSError):
            return self.data
        self.data = data
        return data

    def wait(self, description, predicate, seconds=8):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise AssertionError(f"{description}: game exited: {self.log.read_text(errors='replace')}")
            data = self.read()
            if data and predicate(data):
                return data
            time.sleep(0.04)
        data = self.data
        summary = {k: v for k, v in data.items() if k not in ("frames_ms", "process_us", "combat")}
        raise AssertionError(f"{description}: {summary}, combat={data.get('combat')}")

    def shoot(self, target, button):
        for _ in range(6):
            data = self.read()
            if data["target"] == target:
                break
            old = data["target"]
            tap(TAB)
            self.wait("cycle target", lambda d: d["target"] != old)
        assert self.read()["target"] == target, target
        tap(button)

    def click(self, x, y):
        client = w.RECT()
        user.GetClientRect(self.hwnd, c.byref(client))
        point = w.POINT(round(x * client.right / 960), round(y * client.bottom / 640))
        user.ClientToScreen(self.hwnd, c.byref(point))
        user.SetCursorPos(point.x, point.y)
        user.mouse_event(2, 0, 0, 0, 0)
        time.sleep(0.05)
        user.mouse_event(4, 0, 0, 0, 0)

    def button(self, prefix):
        data = self.wait(f"button {prefix}", lambda d: any(k.startswith(prefix) for k in d["buttons"]))
        xy = next(at for label, at in data["buttons"].items() if label.startswith(prefix))
        self.click(*xy)

    def capture(self):
        tap(F10)
        self.captures += 1
        image = Path(f"{self.path}.{self.captures:02d}.png")
        self.wait("render capture", lambda _: image.exists() and image.stat().st_size > 2000)
        return image.name

    def leave(self):
        if not self.read()["paused"]:
            tap(ESC)
            self.wait("pause before exit", lambda d: d["paused"])
        tap(F12)
        self.process.wait(timeout=10)


def metrics(data, game):
    def summary(values):
        ordered = sorted(values)
        return {"count": len(ordered), "median": round(statistics.median(ordered), 3),
                "p95": round(ordered[int(0.95 * (len(ordered) - 1))], 3), "max": round(ordered[-1], 3)}

    return {"frame_ms": summary(data["frames_ms"]), "physics_and_projection_us": summary(data["process_us"]),
            "resolution": data["resolution"], "video_bytes": data["video_bytes"],
            "working_set": working_set(game.hwnd),
            "last_checkpoint_us": data["checkpoint_us"], "geometry_load_us": data["load_us"]}


def stored(data):
    path = Path(data["storage"]) / "current.json"
    envelope = json.loads(path.read_text(encoding="utf-8"))
    assert envelope["header"]["schema"] == 4
    return json.loads(envelope["payload"])


def young_route(start):
    result = {}
    with start("young", "qi") as game:
        tap("V")
        game.wait("Qi refuses flight", lambda d: "взлёта" in combat(d)["notice"] and actor(d)["flight"] == "ground")
        tap("R")
        game.wait("perception on", lambda d: combat(d)["perception"])
        tap("T")
        game.wait("ward warmup", lambda d: actor(d)["action"]["key"] == "ward")
        tap("1")
        game.wait("queued melee", lambda d: combat(d)["queued"]["key"] == "strike")
        tap("G")
        game.wait("replace queued melee", lambda d: combat(d)["queued"]["key"] == "guard")
        ready = game.wait("ward release in slow motion", lambda d: actor(d)["shield"] == 40 and combat(d)["wards"] == 2)
        assert 74_000 < actor(ready)["qi"] < 90_000
        tap("R")
        game.wait("normal pace", lambda d: not combat(d)["perception"])
        with held("W"):
            game.wait("enter encounter", lambda d: actor(d,YOUNG)["alert"] and actor(d)["pos"][2] < -4700)
        game.shoot(YOUNG, "2")
        game.wait("projectile hits young stone-eater", lambda d: actor(d,YOUNG)["hp"] == 15)
        game.shoot(YOUNG, "2")
        won = game.wait("ordinary victory", lambda d: actor(d,YOUNG)["hp"] == 0)
        assert won["day"] == 0
        with held("W"):
            game.wait("approach loot", lambda d: abs(actor(d)["pos"][2] - actor(d,YOUNG)["pos"][2]) < 1600)
        tap("E")
        game.wait("finite loot claimed", lambda d: any(row["kind"] == "bone_plate" for row in d["items"]))
        tap("E")
        game.wait("one material only", lambda d: len(d["items"]) == 1)
        with held("S"):
            safe = game.wait("retreat to safety", lambda d: actor(d)["pos"][2] > -3600)
        tap("M")
        meditated = game.wait("active meditation", lambda d: combat(d)["meditating"] and actor(d)["qi"] > actor(safe)["qi"] + 5000)
        assert actor(meditated)["hp"] == actor(safe)["hp"] and meditated["day"] == 0
        tap("B")
        book = game.wait("all mastered techniques in live list", lambda d: any(name.startswith("Линия") for name in d["buttons"]))
        game.button("Линия")
        ran = game.wait("mouse selects non-hotkey technique", lambda d: actor(d)["action"]["key"] == "line")
        assert not ran["paused"] and combat(ran)["tick"] > combat(book)["tick"]
        result["controls"] = game.capture()
        result["metrics"] = metrics(ran, game)
        game.leave()
    return result


def elite_route(start):
    with start("elite", "qi") as game:
        slot = game.slot
        # Approach from the open path and clear the ordinary encounter first.
        with held("W"):
            game.wait("alert the young stone-eater", lambda d: actor(d, YOUNG)["alert"])
        for hp in (15, 0):
            game.shoot(YOUNG,"2")
            game.wait("clear the path", lambda d: actor(d, YOUNG)["hp"] == hp)
        with held("W"):
            game.wait("approach armored elite", lambda d: actor(d, ELITE)["alert"] and actor(d)["pos"][2] < -10400)
        game.shoot(ELITE,"2")
        armor = game.wait("frontal spell chips armor before health", lambda d: actor(d, ELITE)["armor"] == 25)
        assert actor(armor, ELITE)["hp"] == 80
        game.wait("elite telegraph", lambda d: actor(d, ELITE)["action"]["wind"] > 25)
        with held("S"):
            tap("Q")
            game.wait("paid dodge travels toward retreat", lambda d: actor(d)["action"]["key"] == "dodge")
            refuge = game.wait("exit to safety", lambda d: not actor(d, ELITE)["alert"] and actor(d)["pos"][2] > -3700)
        assert refuge["day"] == 0
        with held("W"):
            game.wait("return to elite reach", lambda d: actor(d)["pos"][2] < -10800)
        wound = game.wait("two direct heavy hits cause lasting injury", lambda d: actor(d)["injury"], seconds=14)
        assert actor(wound)["hp"] <= 30 and wound["day"] == 0
        dead = game.wait("lethal damage recorded at resolution", lambda d: d["mode"] == "body_dead" and d["paused"], seconds=14)
        death_snapshot = stored(dead)
        assert death_snapshot["mode"] == "body_dead" and not death_snapshot["bodies"][0]["alive"]
        assert death_snapshot["bodies"][0]["died"] == 0
        image = game.capture()
        game.leave()
    with start("death-resume", "qi", slot) as game:
        state = game.wait("dead body reloads into death panel", lambda d: d["paused"] and d["modal"] == "death")
        assert combat(state) == death_snapshot["combat"]
        tap(ESC)
        tap("T")
        game.wait("death cannot be undone with resume", lambda d: d["paused"] and d["modal"] == "death")
        assert combat(game.read()) == combat(state)
        game.leave()
    return {"death_screen": image, "checkpoint_at_death": dead["sequence"], "armor_after_spell": 25}


def core_route(start):
    result = {}
    with start("core", "core") as game:
        slot = game.slot
        tap("T")
        game.wait("core shield", lambda d: actor(d)["shield"] == 40)
        tap("V")
        game.wait("self flight", lambda d: actor(d)["flight"] == "self")
        with held("W", SPACE):
            game.wait("aerial combat ingress", lambda d: actor(d)["pos"][2] < -5350 and actor(d)["pos"][1] > 2100)
        tap("R")
        game.wait("core slow world", lambda d: combat(d)["perception"])
        game.wait("unassisted air forewarning", lambda d: bool(combat(d)["warning"]))
        game.shoot(AIR, "2")
        flight = game.wait(
            "ward, projectile, airborne hero and hostile windup together",
            lambda d: actor(d)["shield"] > 0 and actor(d)["flight"] == "self"
            and actor(d,AIR)["action"]["wind"] > 0 and any(shot["owner"] == HERO for shot in combat(d)["projectiles"]),
        )
        result["active"] = game.capture()
        tap(ESC)
        paused = game.wait("manual pause", lambda d: d["paused"])
        assert actor(paused, AIR)["action"]["wind"] > 0 and combat(paused)["projectiles"], paused
        tap("T")
        tap("3")
        time.sleep(0.35)
        assert combat(game.read()) == combat(paused)
        result["paused"] = game.capture()
        result["phase"] = {key: combat(paused)[key] for key in ("tick", "credit", "wards", "hits", "projectiles", "perception")}
        result["phase"]["hero"] = actor(paused)
        result["phase"]["air"] = actor(paused, AIR)
        result["metrics"] = metrics(flight, game)
        game.leave()
        persisted = stored(paused)
        assert persisted["combat"] == combat(paused)

    with start("resume", "core", slot) as game:
        restored = game.wait("restore lands on system pause", lambda d: d["paused"] and d["modal"] == "restore")
        assert combat(restored) == persisted["combat"]
        tap("G")
        tap("R")
        time.sleep(0.45)
        assert combat(game.read()) == persisted["combat"]
        result["restored"] = game.capture()
        game.button("Продолжить")
        continued = game.wait("windup and same projectile continue", lambda d: combat(d)["hits"] > combat(restored)["hits"])
        assert not continued["paused"] and combat(continued)["wards"] == combat(restored)["wards"]
        assert actor(continued, AIR)["hp"] == 37 and not any(p["owner"] == HERO for p in combat(continued)["projectiles"]), combat(continued)
        result["resumed_hit"] = {"tick": combat(continued)["tick"], "air_hp": actor(continued,AIR)["hp"],
                                 "hit_count": combat(continued)["hits"], "wards": combat(continued)["wards"]}
        # Drop the ward to free the two units of management the volumes require.
        tap("X")
        game.shoot(AIR, "4")
        game.wait("ground projection chosen", lambda d: d["selection"] == "ground")
        game.click(478, 320)
        ground = game.wait("ground projection has a fixed surface center",
                           lambda d: actor(d)["action"]["key"] == "ground")
        assert actor(ground)["action"]["center"][1] < 100
        game.wait("ground projection misses airborne actor",
                  lambda d: actor(d)["action"]["key"] == "ground" and actor(d)["action"]["rest"] > 0)
        assert actor(game.read(), AIR)["hp"] == 37
        game.shoot(AIR, "5")
        game.wait("spatial sphere selected", lambda d: d["selection"] == "sphere")
        game.click(478, 320)
        sphere = game.wait("sphere fixes target at airborne height",
                           lambda d: actor(d)["action"]["key"] == "sphere" and actor(d)["action"]["wind"] > 0)
        assert actor(sphere)["action"]["center"][1] > 3000
        result["sphere"] = game.capture()
        game.wait("sphere damages same airborne actor", lambda d: actor(d,AIR)["hp"] == 10)
        game.leave()
    return result


def foundation_route(start):
    with start("foundation", "foundation") as game:
        tap("V")
        with held(SPACE, "D"):
            up = game.wait("artifact flight ascends and strafes", lambda d: actor(d)["flight"] == "artifact" and actor(d)["pos"][1] > 2800)
        assert up["day"] == 0
        image = game.capture()
        tap("V")
        with held(CTRL):
            game.wait("controlled landing", lambda d: actor(d)["flight"] == "ground" and actor(d)["pos"][1] < 200)
        # South and east to the existing ferry. Advance in one axis at a time.
        with held("S"):
            game.wait("ferry latitude", lambda d: actor(d)["pos"][2] > 3500)
        with held("D"):
            game.wait("ferry approach", lambda d: actor(d)["pos"][0] > 7400)
        tap("E")
        game.wait("visible route cost before confirmation", lambda d: d["modal"] == "route" and d["day"] == 0)
        game.button("Перелёт")
        encounter = game.wait("route interrupted by shared aerial encounter",
                              lambda d: d["crossing"] and d["day"] == 2 and actor(d)["flight"] == "artifact")
        assert encounter["place"] == "court"
        game.shoot(CROSSING, "2")
        game.wait("first shot on crossing guard", lambda d: actor(d, CROSSING)["hp"] == 15)
        game.shoot(CROSSING, "2")
        defeated = game.wait("crossing fight settled on day 2", lambda d: actor(d, CROSSING)["hp"] == 0)
        assert defeated["day"] == 2
        # The guard's prior cast may still have a live projectile.
        game.wait("remaining crossing effects expire", lambda d: not combat(d)["projectiles"])
        tap("E")
        arrival = game.wait("confirmed air route arrival", lambda d: d["place"] == "landing" and d["day"] == 5)
        assert actor(arrival)["flight"] == "ground"
        performance = metrics(arrival, game)
        game.leave()
    return {"flight": image, "combat_interruption_day": 2, "confirmed_arrival_day": 5, "metrics": performance}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--game", type=Path, required=True)
    parser.add_argument("--export", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--only", choices=["young", "elite", "core", "foundation"])
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"])
    args = parser.parse_args()
    folder = args.output.resolve() / f"p4-ui-{time.time_ns()}"
    folder.mkdir(parents=True)
    summary = {}
    checks = {"young": young_route, "elite": elite_route, "core": core_route, "foundation": foundation_route}
    engine = [str(args.godot.resolve()), "--path", str(args.game.resolve())]
    export = [str(args.export.resolve())]
    for renderer in [args.renderer] if args.renderer else ["forward_plus", "gl_compatibility"]:
        routes = {"young": engine, "core": export, "foundation": export, "elite": export}
        result = {}
        for route, command in routes.items():
            if args.only and args.only != route:
                continue

            def start(tag, rank, slot=None):
                return Game(command, folder, f"{renderer}-{tag}", renderer, rank, slot)

            result[route] = checks[route](start)
            print(f"P4_UI_{route.upper()}_PASS renderer={renderer}", flush=True)
        summary[renderer] = result
    (folder / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"P4_UI_PASS evidence={folder}", flush=True)


if __name__ == "__main__":
    main()
