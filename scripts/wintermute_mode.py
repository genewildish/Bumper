#!/usr/bin/env python3
"""
Get or set Wintermute execution mode.
Usage:
  python3 scripts/wintermute_mode.py            # show current mode
  python3 scripts/wintermute_mode.py get        # print only mode
  python3 scripts/wintermute_mode.py set portable
  python3 scripts/wintermute_mode.py set full-warp
"""

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "wintermute.config.json"
VALID_MODES = {"portable", "full-warp"}


def default_config() -> dict:
    return {
        "mode": "portable",
        "modes": {
            "portable": {
                "description": "Aider-driven workflow (agnostic/work-safe): uses scripts/run_agent.sh and optional Anthropic/New Relic APIs."
            },
            "full-warp": {
                "description": "Warp-native workflow (POC): task execution is done in Warp directly, with manual session close logging."
            },
        },
    }


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        cfg = default_config()
        save_config(cfg)
        return cfg
    with open(CONFIG_PATH, encoding="utf-8") as f:
        return json.load(f)


def save_config(cfg: dict) -> None:
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")


def get_mode(cfg: dict) -> str:
    mode = cfg.get("mode", "portable")
    return mode if mode in VALID_MODES else "portable"


def show(cfg: dict) -> int:
    mode = get_mode(cfg)
    modes = cfg.get("modes", {})
    print(f"Current Wintermute mode: {mode}")
    for key in ("portable", "full-warp"):
        desc = modes.get(key, {}).get("description", "")
        marker = "*" if key == mode else "-"
        print(f"{marker} {key}: {desc}")
    print("")
    print("Switch modes with:")
    print("  python3 scripts/wintermute_mode.py set portable")
    print("  python3 scripts/wintermute_mode.py set full-warp")
    return 0


def main() -> int:
    cfg = load_config()
    if len(sys.argv) == 1:
        return show(cfg)

    cmd = sys.argv[1]
    if cmd == "get":
        print(get_mode(cfg))
        return 0

    if cmd == "set":
        if len(sys.argv) != 3:
            print("Usage: python3 scripts/wintermute_mode.py set <portable|full-warp>")
            return 2
        mode = sys.argv[2]
        if mode not in VALID_MODES:
            print(f"Invalid mode: {mode}. Valid modes: portable, full-warp")
            return 2
        cfg["mode"] = mode
        save_config(cfg)
        print(f"Wintermute mode set to: {mode}")
        return 0

    print("Usage:")
    print("  python3 scripts/wintermute_mode.py")
    print("  python3 scripts/wintermute_mode.py get")
    print("  python3 scripts/wintermute_mode.py set <portable|full-warp>")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
