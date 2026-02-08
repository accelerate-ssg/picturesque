## Tests for JSON manifest output

import std/[unittest, json, os, strutils]

import picturesque/manifest

const fixtures_dir = currentSourcePath().parentDir / "fixtures"


suite "manifest: JSON serialization":
  test "serializes empty manifest as empty array":
    let entries: seq[ManifestEntry] = @[]
    let output = to_json(entries)
    check output == parseJson("[]")

  test "serializes single entry with required fields":
    let entries = @[ManifestEntry(
      source: "photo.jpg",
      output: "photo.a3f8b2.webp",
      format: "image/webp"
    )]
    let output = to_json(entries)
    let parsed = output[0]

    check parsed["source"].getStr == "photo.jpg"
    check parsed["output"].getStr == "photo.a3f8b2.webp"
    check parsed["format"].getStr == "image/webp"

  test "includes width field when present":
    let entries = @[ManifestEntry(
      source: "hero.jpg",
      output: "hero_small.a3f8b2.avif",
      format: "image/avif",
      width: 300
    )]
    let output = to_json(entries)

    check output[0]["width"].getInt == 300

  test "omits width field when zero":
    let entries = @[ManifestEntry(
      source: "photo.jpg",
      output: "photo.a3f8b2.webp",
      format: "image/webp",
      width: 0
    )]
    let output = to_json(entries)

    check "width" notin output[0]

  test "includes multiplier field when present":
    let entries = @[ManifestEntry(
      source: "icon.jpg",
      output: "icon_2x.a3f8b2.webp",
      format: "image/webp",
      multiplier: 2.0
    )]
    let output = to_json(entries)

    check output[0]["multiplier"].getFloat == 2.0

  test "omits multiplier field when zero":
    let entries = @[ManifestEntry(
      source: "photo.jpg",
      output: "photo.a3f8b2.webp",
      format: "image/webp",
      multiplier: 0.0
    )]
    let output = to_json(entries)

    check "multiplier" notin output[0]


suite "manifest: deduplication":
  test "same source+output+format produces only one entry":
    var entries = @[
      ManifestEntry(source: "a.jpg", output: "a.abc.webp", format: "image/webp"),
      ManifestEntry(source: "a.jpg", output: "a.abc.webp", format: "image/webp"),
    ]
    let deduped = deduplicate(entries)
    check deduped.len == 1

  test "different formats of same source are kept":
    var entries = @[
      ManifestEntry(source: "a.jpg", output: "a.abc.webp", format: "image/webp"),
      ManifestEntry(source: "a.jpg", output: "a.abc.avif", format: "image/avif"),
    ]
    let deduped = deduplicate(entries)
    check deduped.len == 2


suite "manifest: from multiple files":
  test "same image in two HTML files produces one set of manifest entries":
    # Simulate processing two files that reference the same image
    var all_entries: seq[ManifestEntry] = @[]

    # File 1 references photo.jpg -> webp
    all_entries.add(ManifestEntry(
      source: "photo.jpg",
      output: "photo.a3f8b2.webp",
      format: "image/webp"
    ))
    # File 2 also references photo.jpg -> webp
    all_entries.add(ManifestEntry(
      source: "photo.jpg",
      output: "photo.a3f8b2.webp",
      format: "image/webp"
    ))

    let deduped = deduplicate(all_entries)
    check deduped.len == 1
