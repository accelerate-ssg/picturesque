## Integration tests: end-to-end processing of files

import std/[unittest, os, strutils, json]

import picturesque/process

const
  fixtures_dir = currentSourcePath().parentDir / "fixtures"
  output_dir = currentSourcePath().parentDir / "output"


# Helper to set up a temporary copy of fixture files for in-place rewriting
proc setup_test_dir(): string =
  let dir = output_dir / "test_run"
  createDir(dir)
  return dir

proc copy_fixture(fixture: string, dest_dir: string): string =
  let dest = dest_dir / extractFilename(fixture)
  copyFile(fixture, dest)
  return dest

proc cleanup_test_dir() =
  if dirExists(output_dir):
    removeDir(output_dir)


suite "integration: single HTML file processing":
  setup:
    let test_dir = setup_test_dir()
  teardown:
    cleanup_test_dir()

  test "processes standalone img and writes back":
    let
      file = copy_fixture(fixtures_dir / "standalone_img.html", test_dir)
      # Also copy the image fixture so hashing works
      _ = copy_fixture(fixtures_dir / "photo.jpg", test_dir)
      formats = @["image/webp", "image/avif"]
      manifest = process_files(@[file], formats)

    let output = readFile(file)
    check output.contains("<picture")
    check output.contains("data-picturesque")
    check output.contains("image/webp")
    check output.contains("image/avif")
    check manifest.len == 2

  test "processes picture with srcset and writes back":
    let
      file = copy_fixture(fixtures_dir / "picture_with_srcset.html", test_dir)
      formats = @["image/webp"]
      manifest = process_files(@[file], formats)

    let output = readFile(file)
    check output.contains("image/webp")
    check output.contains("300w")
    check output.contains("900w")


suite "integration: single CSS file processing":
  setup:
    let test_dir = setup_test_dir()
  teardown:
    cleanup_test_dir()

  test "processes css with url() and writes back":
    let
      file = copy_fixture(fixtures_dir / "styles.css", test_dir)
      formats = @["image/webp", "image/avif"]
      manifest = process_files(@[file], formats)

    let output = readFile(file)
    check output.contains("image-set(")
    check output.contains("/* picturesque */")
    # 3 url() references x 2 formats = 6 manifest entries
    check manifest.len == 6


suite "integration: multiple files":
  setup:
    let test_dir = setup_test_dir()
  teardown:
    cleanup_test_dir()

  test "processes mix of HTML and CSS files":
    let
      html_file = copy_fixture(fixtures_dir / "standalone_img.html", test_dir)
      css_file = copy_fixture(fixtures_dir / "styles.css", test_dir)
      _ = copy_fixture(fixtures_dir / "photo.jpg", test_dir)
      formats = @["image/webp"]
      manifest = process_files(@[html_file, css_file], formats)

    let html_output = readFile(html_file)
    let css_output = readFile(css_file)

    check html_output.contains("<picture")
    check css_output.contains("image-set(")

    # 1 from HTML + 3 from CSS = 4 manifest entries
    check manifest.len == 4


suite "integration: idempotency across full run":
  setup:
    let test_dir = setup_test_dir()
  teardown:
    cleanup_test_dir()

  test "running process_files twice gives identical files":
    let
      file = copy_fixture(fixtures_dir / "standalone_img.html", test_dir)
      _ = copy_fixture(fixtures_dir / "photo.jpg", test_dir)
      formats = @["image/webp", "image/avif"]

    discard process_files(@[file], formats)
    let after_first = readFile(file)

    discard process_files(@[file], formats)
    let after_second = readFile(file)

    check after_first == after_second

  test "running process_files twice gives identical manifest":
    let
      file = copy_fixture(fixtures_dir / "standalone_img.html", test_dir)
      _ = copy_fixture(fixtures_dir / "photo.jpg", test_dir)
      formats = @["image/webp", "image/avif"]

    let manifest1 = process_files(@[file], formats)
    let manifest2 = process_files(@[file], formats)

    check manifest1.len == manifest2.len
    for i in 0 ..< manifest1.len:
      check manifest1[i].source == manifest2[i].source
      check manifest1[i].output == manifest2[i].output
      check manifest1[i].format == manifest2[i].format


suite "integration: JSON output":
  setup:
    let test_dir = setup_test_dir()
  teardown:
    cleanup_test_dir()

  test "manifest serializes to valid JSON":
    let
      file = copy_fixture(fixtures_dir / "standalone_img.html", test_dir)
      _ = copy_fixture(fixtures_dir / "photo.jpg", test_dir)
      formats = @["image/webp"]
      manifest = process_files(@[file], formats)
      json_output = manifest_to_json(manifest)

    # Should be parseable JSON
    let parsed = parseJson(json_output)
    check parsed.kind == JArray
    check parsed.len == 1
    check parsed[0]["format"].getStr == "image/webp"


suite "integration: missing source file handling":
  setup:
    let test_dir = setup_test_dir()
  teardown:
    cleanup_test_dir()

  test "logs warning for missing source image but does not crash":
    let
      file = copy_fixture(fixtures_dir / "standalone_img.html", test_dir)
      # Intentionally NOT copying photo.jpg
      formats = @["image/webp"]

    # Should not raise an exception
    let manifest = process_files(@[file], formats)
    # No manifest entries since we can't hash the source
    check manifest.len == 0


suite "integration: deduplication across files":
  setup:
    let test_dir = setup_test_dir()
  teardown:
    cleanup_test_dir()

  test "same image referenced in two HTML files produces deduplicated manifest":
    let
      file1 = test_dir / "page1.html"
      file2 = test_dir / "page2.html"
      _ = copy_fixture(fixtures_dir / "photo.jpg", test_dir)
      formats = @["image/webp"]

    # Both files reference the same photo.jpg
    writeFile(file1, """<html><body><img src="photo.jpg" alt="test" /></body></html>""")
    writeFile(file2, """<html><body><img src="photo.jpg" alt="test" /></body></html>""")

    let manifest = process_files(@[file1, file2], formats)

    # Same image, same format -> only 1 manifest entry
    check manifest.len == 1
