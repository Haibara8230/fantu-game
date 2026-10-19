"""Inventory and package the 2026-10-19 art refresh. No raster style filters.

Run with python -B. Writes only inside the project. The baseline and original
backups are local (.tmp); tracked manifests retain hashes and delivery status.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
META = ROOT / "art_sources/refresh_20261019"
WORK = ROOT / ".tmp/art_refresh_20261019"
MANIFEST = META / "inventory.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def asset_info(path):
    info = {"sha256": digest(path), "bytes": path.stat().st_size}
    if path.suffix.lower() == ".png":
        with Image.open(path) as image:
            image.load()
            info.update(size=list(image.size), mode=image.mode)
            if image.mode == "RGBA":
                alpha = image.getchannel("A")
                histogram = alpha.histogram()
                info["transparent_fraction"] = round(histogram[0] / (image.width * image.height), 4)
    elif path.suffix.lower() == ".svg":
        ET.parse(path)
    return info


def snapshot():
    if MANIFEST.exists():
        raise SystemExit("Baseline already exists; refusing to replace it")
    assets = []
    for folder in (ROOT / "assets/art", ROOT / "assets/local/portraits"):
        for path in sorted(folder.rglob("*")):
            if path.suffix.lower() not in (".png", ".svg"):
                continue
            rel = path.relative_to(ROOT).as_posix()
            category = ("local_portraits" if "assets/local/" in rel else
                        path.relative_to(ROOT / "assets/art").parts[0])
            if category.endswith((".png", ".svg")):
                category = "root_atlases_background"
            backup = WORK / "baseline" / rel
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, backup)
            assets.append({"path": rel, "category": category,
                           "status": "review_reuse" if category == "vfx" else "pending",
                           "baseline": asset_info(path)})
    save_json(MANIFEST, {"date": "2026-10-19", "style_guide": "STYLE_GUIDE.md", "assets": assets})
    print("BASELINE", len(assets), dict(Counter(a["category"] for a in assets)))


def install():
    catalog = json.loads(MANIFEST.read_text(encoding="utf-8"))
    by_path = {a["path"]: a for a in catalog["assets"]}
    deliveries = json.loads((META / "deliveries.json").read_text(encoding="utf-8"))
    for delivery in deliveries:
        rel = delivery["path"]
        target = (ROOT / rel).resolve()
        target.relative_to(ROOT / "assets")
        source = (ROOT / delivery["source"]).resolve()
        entry = by_path.get(rel)
        # Do not overwrite a concurrent change that was not made by this batch.
        if target.exists() and entry:
            permitted = {entry["baseline"]["sha256"]}
            if "current" in entry:
                permitted.add(entry["current"]["sha256"])
            if digest(target) not in permitted:
                raise RuntimeError("Concurrent art change; inspect before replacing: " + rel)
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.suffix.lower() == ".png":
            with Image.open(source) as original:
                image = original.copy()
            size = delivery.get("size", entry.get("baseline", {}).get("size") if entry else None)
            # Packaging only: resizing/cropping is not a substitute for redrawing.
            if size and image.size != tuple(size):
                image = ImageOps.fit(image, tuple(size), method=Image.Resampling.LANCZOS)
            if delivery.get("alpha") and (image.mode != "RGBA" or image.getchannel("A").getextrema()[0] != 0):
                raise RuntimeError("Missing transparent alpha: " + rel)
            image.save(target)
        else:
            ET.parse(source)
            shutil.copy2(source, target)
        if entry is None:
            entry = {"path": rel, "category": delivery["category"]}
            catalog["assets"].append(entry)
        entry.update(status=delivery["status"], source=delivery["source"],
                     note=delivery["note"], current=asset_info(target))
        print("INSTALLED", rel, entry["status"])
    save_json(MANIFEST, catalog)


def report():
    catalog = json.loads(MANIFEST.read_text(encoding="utf-8"))
    failures = []
    for entry in catalog["assets"]:
        path = ROOT / entry["path"]
        current = asset_info(path)
        if entry["status"] in ("integrated", "ready_for_content"):
            if current["sha256"] != entry["current"]["sha256"]:
                failures.append(entry["path"] + " changed since packaging")
            expected = entry.get("baseline", {}).get("size")
            if expected and current.get("size") != expected:
                failures.append(entry["path"] + " size changed")
    counts = dict(Counter(a["status"] for a in catalog["assets"]))
    save_json(WORK / "validation.json", {"counts": counts, "failures": failures})
    print("ART_CATALOG", counts, "FAILURES", failures)
    if failures:
        raise SystemExit(1)


def register_vectors():
    catalog = json.loads(MANIFEST.read_text(encoding="utf-8"))
    by_path = {a["path"]: a for a in catalog["assets"]}
    for folder, source, status in (
        ("icons", "tools/art/make_item_icons.py", "integrated"),
        ("ui", "tools/art/make_ui_art.py", "integrated"),
        ("story/icons", "tools/art/make_story_icons.py", "ready_for_content"),
    ):
        for path in sorted((ROOT / "assets/art" / folder).rglob("*.svg")):
            rel = path.relative_to(ROOT).as_posix()
            info = asset_info(path)
            entry = by_path.get(rel)
            if entry is None:
                entry = {"path": rel, "category": folder}
                catalog["assets"].append(entry)
            changed = info["sha256"] != entry.get("baseline", {}).get("sha256")
            entry.update(status=status if changed else "audited_reuse", source=source, current=info,
                         note="Native editable vectors; simplified subjects, quiet field and thin grade rim" if folder != "story/icons" else "New outline art only; not registered as playable items")
    save_json(MANIFEST, catalog)
    print("VECTORS_REGISTERED")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("snapshot", "install", "vectors", "report"))
    args = parser.parse_args()
    {"snapshot": snapshot, "install": install, "vectors": register_vectors, "report": report}[args.action]()
