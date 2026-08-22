#!/usr/bin/env bash
# Builds Solla sound packs from the Salamander Grand Piano V3+ recordings.
#
# Outputs:
#   ios/Resources/SoundPacks/salamander-lite/   (committed, bundled with the app)
#   scripts/dist/salamander-standard-<ver>.zip  (GitHub Release asset)
#   scripts/dist/salamander-full-<ver>.zip      (GitHub Release asset)
#
# Source archive (412 MB) is cached in scripts/.cache/ (gitignored).
# Requires: curl, tar (xz), ffmpeg, python3, zip.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CACHE="$SCRIPT_DIR/.cache"
DIST="$SCRIPT_DIR/dist"
ARCHIVE_NAME="SalamanderGrandPianoV3+20161209_44khz16bit.tar.xz"
ARCHIVE_URL="https://freepats.zenvoid.org/Piano/SalamanderGrandPiano/$ARCHIVE_NAME"
WAV_DIR="$CACHE/SalamanderGrandPianoV3_44.1khz16bit/44.1khz16bit"

mkdir -p "$CACHE" "$DIST"

if [[ ! -f "$CACHE/$ARCHIVE_NAME" ]]; then
    echo "Downloading Salamander archive (412 MB)..."
    curl -L -o "$CACHE/$ARCHIVE_NAME" "$ARCHIVE_URL"
fi

if [[ ! -d "$WAV_DIR" ]]; then
    echo "Extracting archive..."
    tar -xJf "$CACHE/$ARCHIVE_NAME" -C "$CACHE"
fi

# Prefer Apple's AAC encoder when the ffmpeg build has it.
if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q aac_at; then
    AAC_CODEC=aac_at
else
    AAC_CODEC=aac
fi
echo "Using AAC encoder: $AAC_CODEC"

# All 30 sampled notes, low to high (minor-3rd spacing, A0=21 ... C8=108).
ALL_NOTES=(A0 C1 D#1 F#1 A1 C2 D#2 F#2 A2 C3 D#3 F#3 A3 C4 D#4 F#4 A4 C5 D#5 F#5 A5 C6 D#6 F#6 A6 C7 D#7 F#7 A7 C8)
# The bundled pack covers the exercise range A1..C6 (18 notes).
LITE_NOTES=(A1 C2 D#2 F#2 A2 C3 D#3 F#3 A3 C4 D#4 F#4 A4 C5 D#5 F#5 A5 C6)

# build_pack <id> <name> <version> <notes...> -- <layer:gain...> -- <trim> <fadeStart> <bitrate> <outDir>
build_pack() {
    local id="$1" name="$2" version="$3"
    shift 3
    local notes=()
    while [[ "$1" != "--" ]]; do notes+=("$1"); shift; done
    shift
    local layers=()
    while [[ "$1" != "--" ]]; do layers+=("$1"); shift; done
    shift
    local trim="$1" fade_start="$2" bitrate="$3" out_dir="$4"

    echo "== Building $id ($name) -> $out_dir"
    rm -rf "$out_dir"
    mkdir -p "$out_dir"

    local fade_len
    fade_len=$(python3 -c "print($trim - $fade_start)")
    local note layer_spec layer
    for note in "${notes[@]}"; do
        for layer_spec in "${layers[@]}"; do
            layer="${layer_spec%%:*}"
            local src="$WAV_DIR/${note}v${layer}.wav"
            local dst="$out_dir/${note}v${layer}.m4a"
            [[ -f "$src" ]] || { echo "MISSING SOURCE: $src" >&2; exit 1; }
            ffmpeg -hide_banner -loglevel error -y -i "$src" \
                -ac 1 -t "$trim" \
                -af "afade=t=out:st=${fade_start}:d=${fade_len}" \
                -c:a "$AAC_CODEC" -b:a "$bitrate" \
                "$dst"
        done
    done

    PACK_ID="$id" PACK_NAME="$name" PACK_VERSION="$version" \
    PACK_LAYERS="$(IFS=,; echo "${layers[*]}")" PACK_DIR="$out_dir" \
    python3 - <<'PYEOF'
import json, os, re

NOTE_OFFSETS = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
                "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}

def midi(note_name):
    m = re.fullmatch(r"([A-G]#?)(\d)", note_name)
    return (int(m.group(2)) + 1) * 12 + NOTE_OFFSETS[m.group(1)]

pack_dir = os.environ["PACK_DIR"]
layer_gains = {}
for spec in os.environ["PACK_LAYERS"].split(","):
    layer_id, gain = spec.split(":")
    layer_gains[int(layer_id)] = float(gain)

samples = []
for filename in sorted(os.listdir(pack_dir)):
    m = re.fullmatch(r"([A-G]#?\d)v(\d+)\.m4a", filename)
    if not m:
        continue
    samples.append({"file": filename, "rootMidi": midi(m.group(1)), "layer": int(m.group(2))})
samples.sort(key=lambda s: (s["layer"], s["rootMidi"]))
assert samples, "no samples found in " + pack_dir

manifest = {
    "formatVersion": 1,
    "id": os.environ["PACK_ID"],
    "name": os.environ["PACK_NAME"],
    "version": os.environ["PACK_VERSION"],
    "instrument": "piano",
    "sampleRate": 44100,
    "channels": 1,
    "releaseSeconds": 0.35,
    "attribution": {
        "title": "Salamander Grand Piano V3+",
        "author": "Alexander Holm",
        "license": "CC-BY-3.0",
        "url": "https://freepats.zenvoid.org/Piano/acoustic-grand-piano.html",
    },
    "layers": [{"id": i, "nominalGain": g} for i, g in sorted(layer_gains.items())],
    "samples": samples,
}
with open(os.path.join(pack_dir, "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=2)
print(f"  manifest.json: {len(samples)} samples, {len(layer_gains)} layer(s)")
PYEOF

    du -sh "$out_dir"
}

VERSION="1.0.0"

# Bundled pack: single medium-loud layer, short tail, tiny.
build_pack salamander-lite "Piano (built-in)" "$VERSION" \
    "${LITE_NOTES[@]}" -- 8:0.85 -- \
    4.5 3.5 96k "$REPO_ROOT/ios/Resources/SoundPacks/salamander-lite"

# Downloadable: three dynamics, longer tails.
build_pack salamander-standard "Salamander Standard" "$VERSION" \
    "${ALL_NOTES[@]}" -- 4:0.4 8:0.7 12:1.0 -- \
    8 6.5 96k "$CACHE/packs/salamander-standard"

# Downloadable: six dynamics, full tails, higher bitrate.
build_pack salamander-full "Salamander Full" "$VERSION" \
    "${ALL_NOTES[@]}" -- 2:0.2 5:0.4 8:0.6 11:0.75 14:0.9 16:1.0 -- \
    12 10 128k "$CACHE/packs/salamander-full"

for id in salamander-standard salamander-full; do
    zipfile="$DIST/${id}-${VERSION}.zip"
    rm -f "$zipfile"
    (cd "$CACHE/packs/$id" && zip -q -r "$zipfile" .)
    du -sh "$zipfile"
done

echo "Done. Release with:"
echo "  gh release create sound-packs-v1 scripts/dist/salamander-standard-${VERSION}.zip scripts/dist/salamander-full-${VERSION}.zip \\"
echo "    --title 'Sound Packs v1' --notes 'Salamander Grand Piano packs (CC-BY 3.0, Alexander Holm)'"
