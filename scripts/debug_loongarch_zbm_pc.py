#!/usr/bin/env python3
"""Host-side: map fault PC (e.g. 0x19b50) to linked ELF sections; append NDJSON for debug session."""
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

LOG = Path(__file__).resolve().parents[1] / ".cursor" / "debug-9b5038.log"
DEFAULT_ERA = 0x19B50


def readelf_sections(elf: Path) -> list[dict]:
    out = subprocess.check_output(["readelf", "-SW", str(elf)], text=True, stderr=subprocess.DEVNULL)
    rows: list[dict] = []
    for line in out.splitlines():
        m = re.match(
            r"\s*\[\s*\d+\]\s+(\S+)\s+\S+\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s",
            line,
        )
        if not m:
            continue
        name, addr, off, size = m.groups()
        if name.startswith("["):
            continue
        rows.append(
            {
                "name": name,
                "addr": int(addr, 16),
                "off": int(off, 16),
                "size": int(size, 16),
            }
        )
    return rows


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    elf = root / "zig-out" / "bin" / "zbm_la_debug.elf"
    era = int(sys.argv[1], 0) if len(sys.argv) > 1 else DEFAULT_ERA
    if not elf.is_file():
        line = {
            "sessionId": "9b5038",
            "hypothesisId": "H0",
            "location": "debug_loongarch_zbm_pc.py",
            "message": "ELF missing; run link step to create zig-out/bin/zbm_la_debug.elf",
            "data": {"path": str(elf)},
            "timestamp": int(__import__("time").time() * 1000),
        }
        LOG.parent.mkdir(parents=True, exist_ok=True)
        LOG.open("a").write(json.dumps(line) + "\n")
        return 1
    secs = readelf_sections(elf)
    hit = None
    for s in secs:
        if s["size"] and s["addr"] <= era < s["addr"] + s["size"]:
            hit = s
            break
    line = {
        "sessionId": "9b5038",
        "hypothesisId": "H3",
        "location": "debug_loongarch_zbm_pc.py",
        "message": "ERA vs ELF sections",
        "data": {
            "era_hex": hex(era),
            "containing_section": hit["name"] if hit else None,
            "section_addr": hex(hit["addr"]) if hit else None,
            "section_end": hex(hit["addr"] + hit["size"]) if hit else None,
            "in_alloc_gap": hit is None,
        },
        "timestamp": int(__import__("time").time() * 1000),
    }
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a") as f:
        f.write(json.dumps(line) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
