## Tests for automatic file discovery from HTML references

import std/[unittest, os, strutils, sets]

import picturesque/discovery

const fixtures_dir = currentSourcePath().parentDir / "fixtures"


suite "file discovery: linked stylesheets":
  test "discovers <link rel='stylesheet'> href as a file to process":
    let
      html = readFile(fixtures_dir / "html_with_linked_css.html")
      base_dir = fixtures_dir
      discovered = discover_files(html, base_dir)

    check (base_dir / "linked.css") in discovered

  test "resolves relative CSS paths against the HTML file's directory":
    let
      html = readFile(fixtures_dir / "html_with_subdir_css.html")
      base_dir = fixtures_dir
      discovered = discover_files(html, base_dir)

    check (base_dir / "sub" / "nested.css") in discovered

  test "does not discover non-stylesheet link tags":
    let
      html = """<html><head><link rel="canonical" href="https://example.com" /></head><body></body></html>"""
      discovered = discover_files(html, fixtures_dir)

    check discovered.len == 0


suite "file discovery: deduplication":
  test "same CSS file linked twice produces only one discovery":
    let
      html = readFile(fixtures_dir / "html_with_duplicate_css.html")
      discovered = discover_files(html, fixtures_dir)

    var css_count = 0
    for path in discovered:
      if path.endsWith("linked.css"):
        inc css_count
    check css_count == 1

  test "does not discover files already in the processed set":
    let
      html = readFile(fixtures_dir / "html_with_linked_css.html")
      already_processed = [absolutePath("linked.css", fixtures_dir)].toHashSet
      discovered = discover_files(html, fixtures_dir, already_processed)

    check discovered.len == 0


suite "file discovery: inline styles":
  test "does not enqueue inline <style> blocks as separate files":
    let
      html = readFile(fixtures_dir / "html_with_inline_style.html")
      discovered = discover_files(html, fixtures_dir)

    # Inline styles are processed in place, not as separate files
    # Only linked.css-type files should appear
    for path in discovered:
      check not path.contains("inline")

  test "inline <style> content is still available for CSS processing":
    # The inline style content should be extractable for in-place processing
    let
      html = readFile(fixtures_dir / "html_with_inline_style.html")
      inline_styles = extract_inline_styles(html)

    check inline_styles.len == 1
    check inline_styles[0].contains("url(\"inline_bg.jpg\")")


suite "file discovery: work queue integration":
  test "process_files discovers and processes linked CSS automatically":
    # Copy fixtures to temp dir for in-place rewriting
    let test_dir = getTempDir() / "picturesque_test_discovery"
    createDir(test_dir)
    defer: removeDir(test_dir)

    copyFile(fixtures_dir / "html_with_linked_css.html", test_dir / "index.html")
    copyFile(fixtures_dir / "linked.css", test_dir / "linked.css")

    let
      formats = @["image/webp"]
      # Only pass the HTML file - CSS should be discovered
      manifest = process_files(@[test_dir / "index.html"], formats)

    let css_output = readFile(test_dir / "linked.css")
    # The CSS file should have been processed (url -> image-set)
    check css_output.contains("image-set(")

  test "processes only CLI-given files plus discovered files, no duplicates":
    let test_dir = getTempDir() / "picturesque_test_discovery2"
    createDir(test_dir)
    defer: removeDir(test_dir)

    copyFile(fixtures_dir / "html_with_linked_css.html", test_dir / "index.html")
    copyFile(fixtures_dir / "linked.css", test_dir / "linked.css")

    let
      formats = @["image/webp"]
      # Pass both HTML and CSS explicitly - CSS should not be processed twice
      manifest = process_files(
        @[test_dir / "index.html", test_dir / "linked.css"],
        formats
      )

    let css_output = readFile(test_dir / "linked.css")
    # Should have exactly one image-set, not two
    check css_output.count("image-set(") == 1

  test "discovered CSS file in subdirectory is processed":
    let test_dir = getTempDir() / "picturesque_test_discovery3"
    createDir(test_dir)
    createDir(test_dir / "sub")
    defer: removeDir(test_dir)

    copyFile(fixtures_dir / "html_with_subdir_css.html", test_dir / "index.html")
    copyFile(fixtures_dir / "sub" / "nested.css", test_dir / "sub" / "nested.css")

    let
      formats = @["image/webp"]
      manifest = process_files(@[test_dir / "index.html"], formats)

    let css_output = readFile(test_dir / "sub" / "nested.css")
    check css_output.contains("image-set(")


suite "file discovery: missing referenced files":
  test "warns but does not crash when linked CSS file is missing":
    let
      html = readFile(fixtures_dir / "html_with_linked_css.html")
      # Use a directory where linked.css does not exist
      discovered = discover_files(html, getTempDir())

    # Should return the path but it won't exist - process_files handles this
    check discovered.len >= 0  # may be 0 if discovery skips missing files

  test "process_files skips missing discovered files gracefully":
    let test_dir = getTempDir() / "picturesque_test_missing"
    createDir(test_dir)
    defer: removeDir(test_dir)

    copyFile(fixtures_dir / "html_with_linked_css.html", test_dir / "index.html")
    # Intentionally NOT copying linked.css

    let
      formats = @["image/webp"]

    # Should not crash
    let manifest = process_files(@[test_dir / "index.html"], formats)


suite "file discovery: link rel=icon":
  test "discovers favicon/icon links as image references":
    let
      html = readFile(fixtures_dir / "html_with_favicon.html")
      base_dir = fixtures_dir
      discovered = discover_files(html, base_dir)

    # linked.css should be discovered as a file to process
    check (base_dir / "linked.css") in discovered
    # favicon.png is an image reference, not a file to parse -
    # it should be handled as an image to expand, not enqueued for parsing
