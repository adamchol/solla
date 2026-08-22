# Scripts

## build-sample-packs.sh

Builds the app's piano sound packs from the Salamander Grand Piano V3+
recordings (Alexander Holm, CC-BY 3.0). Downloads the 412 MB source archive
into `scripts/.cache/` on first run (both `.cache/` and `dist/` are
gitignored), transcodes with ffmpeg to mono AAC, and emits:

- `ios/Resources/SoundPacks/salamander-lite/` — the bundled pack (committed).
- `scripts/dist/salamander-standard-<ver>.zip` and
  `scripts/dist/salamander-full-<ver>.zip` — downloadable packs.

Publish the downloadable packs as GitHub Release assets (the in-app catalog
in `ios/Solla/Audio/SoundPackCatalog.swift` points at this tag):

```sh
gh release create sound-packs-v1 \
  scripts/dist/salamander-standard-1.0.0.zip \
  scripts/dist/salamander-full-1.0.0.zip \
  --title 'Sound Packs v1' \
  --notes 'Salamander Grand Piano packs (CC-BY 3.0, Alexander Holm)'
```

When changing pack contents, bump `VERSION` in the script, use a new release
tag, and update the catalog entries (URL + version) to match.
