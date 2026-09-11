from __future__ import annotations

import hashlib
import json
import struct
from collections import Counter
from datetime import date
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ARCHIVE_ROOT = PROJECT_ROOT / "art_source" / "downloads" / "quaternius"
SOURCE_ROOT = PROJECT_ROOT / "art_source" / "quaternius"
OUTPUT_PATH = (
    PROJECT_ROOT
    / "art_source"
    / "manifests"
    / "quaternius_free_standard_inventory.json"
)

PACKS: dict[str, dict[str, Any]] = {
    "medieval-village-megakit": {
        "title": "Medieval Village MegaKit",
        "original_archive_name": "Medieval Village MegaKit[Standard].zip",
        "official_page": "https://quaternius.com/packs/medievalvillagemegakit.html",
        "itch_page": "https://quaternius.itch.io/medieval-village-megakit",
        "official_release": "2025-01",
        "candidate_use": ["模块化建筑外墙", "地板", "门窗", "楼梯", "独立屋顶"],
    },
    "fantasy-props-megakit": {
        "title": "Fantasy Props MegaKit",
        "original_archive_name": "Fantasy Props MegaKit[Standard].zip",
        "official_page": "https://quaternius.com/packs/fantasypropsmegakit.html",
        "itch_page": "https://quaternius.itch.io/fantasy-props-megakit",
        "official_release": "2025-06",
        "candidate_use": ["室内家具", "铁匠工具", "食物", "武器", "工作台"],
    },
    "universal-base-characters": {
        "title": "Universal Base Characters",
        "original_archive_name": "Universal Base Characters[Standard].zip",
        "official_page": "https://quaternius.com/packs/universalbasecharacters.html",
        "itch_page": "https://quaternius.itch.io/universal-base-characters",
        "official_release": "2025-08",
        "candidate_use": ["NPC 男女基础人形", "头部", "眉毛", "发型", "胡须"],
    },
    "modular-character-outfits-fantasy": {
        "title": "Modular Character Outfits - Fantasy",
        "original_archive_name": "Modular Character Outfits - Fantasy[Standard].zip",
        "official_page": "https://quaternius.com/packs/modularcharacteroutfitsfantasy.html",
        "itch_page": "https://quaternius.itch.io/modular-character-outfits-fantasy",
        "official_release": "2025-11",
        "candidate_use": ["农民服装", "游侠服装", "职业外观原型", "服装模块拆分"],
    },
    "universal-animation-library-2": {
        "title": "Universal Animation Library 2",
        "original_archive_name": "Universal Animation Library 2[Standard].zip",
        "official_page": "https://quaternius.com/packs/universalanimationlibrary2.html",
        "itch_page": "https://quaternius.itch.io/universal-animation-library-2",
        "official_release": "2026-01",
        "candidate_use": ["待机", "行走搬运", "农活", "砍树", "近战", "受击"],
    },
    "stylized-nature-megakit": {
        "title": "Stylized Nature MegaKit",
        "original_archive_name": "Stylized Nature MegaKit[Standard].zip",
        "official_page": "https://quaternius.com/packs/stylizednaturemegakit.html",
        "itch_page": "https://quaternius.itch.io/stylized-nature-megakit",
        "official_release": "2024-07",
        "candidate_use": ["树木", "灌木", "草花", "岩石", "道路边缘装饰"],
    },
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def load_gltf_json(path: Path) -> dict[str, Any] | None:
    if path.suffix.lower() == ".gltf":
        return json.loads(path.read_text(encoding="utf-8-sig"))
    raw = path.read_bytes()
    if raw[:4] != b"glTF":
        return None
    offset = 12
    while offset + 8 <= len(raw):
        length, chunk_type = struct.unpack_from("<II", raw, offset)
        offset += 8
        chunk = raw[offset : offset + length]
        offset += length
        if chunk_type == 0x4E4F534A:
            return json.loads(chunk.decode("utf-8").rstrip("\x00 \t\r\n"))
    return None


def inventory_pack(slug: str, metadata: dict[str, Any]) -> dict[str, Any]:
    archive = ARCHIVE_ROOT / f"{slug}-standard.zip"
    source_dir = SOURCE_ROOT / slug / "standard"
    if not archive.is_file():
        raise FileNotFoundError(archive)
    if not source_dir.is_dir():
        raise FileNotFoundError(source_dir)

    files = sorted(path for path in source_dir.rglob("*") if path.is_file())
    extension_counts = Counter(path.suffix.lower() or "<none>" for path in files)
    gltf_paths = [path for path in files if path.suffix.lower() in {".gltf", ".glb"}]
    meshes = 0
    skins = 0
    skin_joint_counts: list[int] = []
    animation_tracks = 0
    animation_names: set[str] = set()
    materials = 0
    for path in gltf_paths:
        document = load_gltf_json(path)
        if not document:
            continue
        meshes += len(document.get("meshes", []))
        skins += len(document.get("skins", []))
        skin_joint_counts.extend(
            len(skin.get("joints", [])) for skin in document.get("skins", [])
        )
        animations = document.get("animations", [])
        animation_tracks += len(animations)
        animation_names.update(
            animation.get("name", "<unnamed>") for animation in animations
        )
        materials += len(document.get("materials", []))

    name_hints = {
        "collision": [
            path.relative_to(source_dir).as_posix()
            for path in files
            if "collision" in path.name.lower()
        ],
        "godot_project": [
            path.relative_to(source_dir).as_posix()
            for path in files
            if path.name == "project.godot"
        ],
        "license": [
            path.relative_to(source_dir).as_posix()
            for path in files
            if "license" in path.name.lower()
        ],
    }

    return {
        "id": slug,
        **metadata,
        "tier": "Standard (free)",
        "semantic_version": None,
        "acquired_on": date(2026, 8, 11).isoformat(),
        "license": "CC0 1.0 Universal",
        "archive": {
            "local_path": archive.relative_to(PROJECT_ROOT).as_posix(),
            "bytes": archive.stat().st_size,
            "sha256": sha256(archive),
        },
        "extracted_root": source_dir.relative_to(PROJECT_ROOT).as_posix(),
        "file_count": len(files),
        "uncompressed_bytes": sum(path.stat().st_size for path in files),
        "extension_counts": dict(sorted(extension_counts.items())),
        "gltf_summary": {
            "gltf_or_glb_files": len(gltf_paths),
            "meshes": meshes,
            "materials": materials,
            "skins": skins,
            "skin_joint_counts": sorted(set(skin_joint_counts)),
            "animation_tracks": animation_tracks,
            "unique_animation_count": len(animation_names),
            "unique_animation_names": sorted(animation_names),
        },
        "included_collision_name_matches": name_hints["collision"],
        "included_godot_projects": name_hints["godot_project"],
        "included_license_files": name_hints["license"],
        "scale_status": "glTF uses meter semantics; empirical Godot scale and pivot acceptance remain T0125",
        "runtime_imported": False,
    }


def main() -> None:
    inventory = {
        "schema_version": 1,
        "generated_on": date(2026, 8, 11).isoformat(),
        "source_policy": "Official Quaternius pages and free itch.io Standard uploads only",
        "runtime_imported": False,
        "packs": [inventory_pack(slug, PACKS[slug]) for slug in PACKS],
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(inventory, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(OUTPUT_PATH.relative_to(PROJECT_ROOT).as_posix())


if __name__ == "__main__":
    main()
