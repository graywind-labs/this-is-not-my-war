from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import re
import struct
from pathlib import Path
from urllib.parse import unquote, unquote_to_bytes


JSON_CHUNK_TYPE = 0x4E4F534A
BIN_CHUNK_TYPE = 0x004E4942
GLB_MAGIC = 0x46546C67


def _align_four(data: bytearray, fill: int = 0) -> None:
    while len(data) % 4:
        data.append(fill)


def _resolve_external_path(uri: str, base_dir: Path, search_dirs: list[Path]) -> Path:
    relative = Path(unquote(uri))
    candidate_names = [relative]
    if relative.name.endswith("_png.png"):
        candidate_names.append(relative.with_name(relative.name.replace("_png.png", ".png")))
    for root in [base_dir, *search_dirs]:
        for candidate_name in candidate_names:
            candidate = root / candidate_name
            if candidate.is_file():
                return candidate
    raise FileNotFoundError(base_dir / relative)


def _read_uri(
    uri: str,
    base_dir: Path,
    search_dirs: list[Path],
) -> tuple[bytes, str | None]:
    if uri.startswith("data:"):
        header, payload = uri.split(",", 1)
        mime_type = header[5:].split(";", 1)[0] or None
        if ";base64" in header:
            return base64.b64decode(payload), mime_type
        return unquote_to_bytes(payload), mime_type
    path = _resolve_external_path(uri, base_dir, search_dirs)
    mime_type, _ = mimetypes.guess_type(path.name)
    return path.read_bytes(), mime_type


def _external_image_name(
    destination: Path,
    image: dict,
    index: int,
    mime_type: str | None,
    external_image_prefix: str | None,
) -> str:
    raw_name = str(image.get("name", "")).strip()
    stem = Path(raw_name).stem if raw_name else f"image_{index + 1}"
    stem = re.sub(r"[^A-Za-z0-9_.-]+", "_", stem).strip("._") or f"image_{index + 1}"
    extension = mimetypes.guess_extension(mime_type or "") or ".bin"
    prefix = external_image_prefix or destination.stem
    return f"{prefix}_{stem}{extension}"


def pack_gltf(
    source: Path,
    destination: Path,
    search_dirs: list[Path],
    external_images: bool,
    external_image_prefix: str | None,
) -> None:
    document = json.loads(source.read_text(encoding="utf-8-sig"))
    base_dir = source.parent
    binary = bytearray()
    buffer_offsets: list[int] = []

    for buffer in document.get("buffers", []):
        uri = buffer.get("uri")
        if not uri:
            raise ValueError(f"External .gltf buffer has no URI: {source}")
        _align_four(binary)
        buffer_offsets.append(len(binary))
        payload, _ = _read_uri(uri, base_dir, search_dirs)
        binary.extend(payload)

    for view in document.get("bufferViews", []):
        old_buffer = int(view.get("buffer", 0))
        view["byteOffset"] = int(view.get("byteOffset", 0)) + buffer_offsets[old_buffer]
        view["buffer"] = 0

    buffer_views = document.setdefault("bufferViews", [])
    for image_index, image in enumerate(document.get("images", [])):
        uri = image.pop("uri", None)
        if uri is None:
            continue
        payload, detected_mime = _read_uri(uri, base_dir, search_dirs)
        mime_type = image.get("mimeType") or detected_mime or "application/octet-stream"
        if external_images:
            external_name = _external_image_name(
                destination,
                image,
                image_index,
                mime_type,
                external_image_prefix,
            )
            external_path = destination.parent / external_name
            if external_path.is_file() and external_path.read_bytes() != payload:
                raise ValueError(
                    f"Refusing to overwrite different shared image: {external_path}"
                )
            external_path.write_bytes(payload)
            image["uri"] = external_name
            image.pop("bufferView", None)
            image.pop("mimeType", None)
            continue
        _align_four(binary)
        offset = len(binary)
        binary.extend(payload)
        buffer_views.append(
            {"buffer": 0, "byteOffset": offset, "byteLength": len(payload)}
        )
        image["bufferView"] = len(buffer_views) - 1
        image["mimeType"] = mime_type

    _align_four(binary)
    document["buffers"] = [{"byteLength": len(binary)}]

    json_bytes = json.dumps(
        document,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    json_chunk = bytearray(json_bytes)
    _align_four(json_chunk, fill=0x20)

    total_length = 12 + 8 + len(json_chunk) + 8 + len(binary)
    glb = bytearray(struct.pack("<III", GLB_MAGIC, 2, total_length))
    glb.extend(struct.pack("<II", len(json_chunk), JSON_CHUNK_TYPE))
    glb.extend(json_chunk)
    glb.extend(struct.pack("<II", len(binary), BIN_CHUNK_TYPE))
    glb.extend(binary)

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(glb)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Pack a glTF 2.0 JSON file and its external buffers/images into one GLB."
    )
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument(
        "--search-dir",
        action="append",
        default=[],
        type=Path,
        help="Additional directory used to resolve broken or relocated external URIs.",
    )
    parser.add_argument(
        "--external-images",
        action="store_true",
        help=(
            "Keep image files next to the GLB with deterministic names instead of embedding "
            "them. This avoids duplicate texture bytes when Godot extracts embedded images."
        ),
    )
    parser.add_argument(
        "--external-image-prefix",
        help=(
            "Optional shared filename prefix for external images. Existing files are reused "
            "only when their bytes match exactly."
        ),
    )
    args = parser.parse_args()
    pack_gltf(
        args.source.resolve(),
        args.destination.resolve(),
        [path.resolve() for path in args.search_dir],
        args.external_images,
        args.external_image_prefix,
    )
    print(args.destination.as_posix())


if __name__ == "__main__":
    main()
