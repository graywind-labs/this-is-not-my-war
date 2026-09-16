from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path

try:
    from .prepare_demo_staging import DemoStagingError, load_config
except ImportError:
    from prepare_demo_staging import DemoStagingError, load_config


REQUIRED_ICO_SIZES = {16, 32, 48, 64, 128, 256}
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def verify_branding_icon(source_root: Path) -> dict[str, object]:
    source_root = source_root.resolve()
    config = load_config(source_root)
    ico_path = source_root / str(config["branding_icon_ico"])
    png_path = source_root / str(config["branding_icon_source"])
    ico = ico_path.read_bytes()
    png = png_path.read_bytes()

    if len(png) < 33 or png[:8] != PNG_SIGNATURE or png[12:16] != b"IHDR":
        raise DemoStagingError("Branding source must be a valid PNG with an IHDR chunk.")
    width, height, bit_depth, color_type = struct.unpack_from(">IIBB", png, 16)
    if (width, height, bit_depth, color_type) != (1024, 1024, 8, 6):
        raise DemoStagingError("Branding source must be a 1024x1024 8-bit RGBA PNG.")

    if len(ico) < 6:
        raise DemoStagingError("Branding ICO header is missing.")
    reserved, image_type, count = struct.unpack_from("<HHH", ico, 0)
    if reserved != 0 or image_type != 1 or count <= 0 or len(ico) < 6 + count * 16:
        raise DemoStagingError("Branding ICO directory is invalid.")
    sizes: set[int] = set()
    for index in range(count):
        width_byte, height_byte, _, _, _, bits, data_size, offset = struct.unpack_from(
            "<BBBBHHII", ico, 6 + index * 16
        )
        width_value = width_byte or 256
        height_value = height_byte or 256
        if width_value != height_value or bits != 32:
            raise DemoStagingError("Every branding ICO entry must be square 32-bit RGBA.")
        if data_size <= 0 or offset < 6 + count * 16 or offset + data_size > len(ico):
            raise DemoStagingError("Branding ICO entry points outside the file.")
        sizes.add(width_value)
    if sizes != REQUIRED_ICO_SIZES:
        raise DemoStagingError(
            "Branding ICO sizes must be exactly: " + ", ".join(map(str, sorted(REQUIRED_ICO_SIZES)))
        )
    return {
        "ok": True,
        "png_size": [width, height],
        "png_rgba": True,
        "ico_sizes": sorted(sizes),
        "ico_entries": count,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify the shared Windows demo branding icon assets.")
    parser.add_argument("--source-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    print(json.dumps(verify_branding_icon(args.source_root), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
