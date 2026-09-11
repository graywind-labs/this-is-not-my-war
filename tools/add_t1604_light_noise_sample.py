from __future__ import annotations

import json
import random
import struct
import sys
import wave
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: add_t1604_light_noise_sample.py SAMPLE_DIRECTORY")
    sample_dir = Path(sys.argv[1]).resolve()
    source = sample_dir / "female_short.wav"
    target = sample_dir / "female_short_light_noise.wav"
    manifest_path = sample_dir / "manifest.json"
    if not source.is_file() or not manifest_path.is_file():
        raise SystemExit("generated source WAV or manifest is missing")

    with wave.open(str(source), "rb") as reader:
        params = reader.getparams()
        if params.sampwidth != 2:
            raise SystemExit("expected 16-bit PCM input")
        pcm = bytearray(reader.readframes(params.nframes))

    rng = random.Random(1604)
    # Approximately -36 dBFS deterministic noise: audible but speech remains clear.
    for offset in range(0, len(pcm), 2):
        sample = struct.unpack_from("<h", pcm, offset)[0]
        noisy = max(-32768, min(32767, sample + rng.randint(-520, 520)))
        struct.pack_into("<h", pcm, offset, noisy)

    with wave.open(str(target), "wb") as writer:
        writer.setparams(params)
        writer.writeframes(pcm)

    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    samples = list(manifest.get("samples", []))
    if target.name not in samples:
        samples.insert(1, target.name)
    manifest["samples"] = samples
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(target)


if __name__ == "__main__":
    main()
