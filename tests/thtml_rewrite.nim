## Tests for HTML detection and rewriting

import std/[unittest, os, strutils, xmltree, htmlparser]

import picturesque/html_rewrite

const fixtures_dir = currentSourcePath().parentDir / "fixtures"

# Helper to count elements with a given attribute
proc count_elements_with_attr(html: XmlNode, attr: string): int =
  result = 0
  if html.kind == xnElement:
    if html.attr(attr) != "":
      inc result
    for child in html:
      result += count_elements_with_attr(child, attr)

# Helper to find all elements by tag name (recursive)
proc find_all_recursive(html: XmlNode, tag: string): seq[XmlNode] =
  result = @[]
  if html.kind == xnElement:
    if html.tag == tag:
      result.add(html)
    for child in html:
      result.add(find_all_recursive(child, tag))


suite "HTML: standalone <img> expansion":
  test "wraps bare <img> in <picture> with generated sources":
    let
      formats = @["image/webp", "image/avif"]
      input = readFile(fixtures_dir / "standalone_img.html")
      (output, manifest) = rewrite_html(input, formats, fixtures_dir)
      html = parseHtml(output)
      pictures = html.find_all_recursive("picture")

    check pictures.len == 1
    let picture = pictures[0]

    # Should have data-picturesque since we generated the wrapper
    check picture.attr("data-picturesque") != ""

    # Should contain source elements for each format
    let sources = picture.find_all_recursive("source")
    check sources.len == 2

    for source in sources:
      check source.attr("data-picturesque") != ""
      check source.attr("type") in ["image/webp", "image/avif"]
      check source.attr("srcset").len > 0

    # Original <img> should still be there
    let imgs = picture.find_all_recursive("img")
    check imgs.len == 1
    check imgs[0].attr("src") == "photo.jpg"

  test "generates manifest entries for standalone <img>":
    let
      formats = @["image/webp", "image/avif"]
      input = readFile(fixtures_dir / "standalone_img.html")
      (_, manifest) = rewrite_html(input, formats, fixtures_dir)

    check manifest.len == 2
    for entry in manifest:
      check entry.source == "photo.jpg"
      check entry.format in ["image/webp", "image/avif"]
      check entry.output.contains(".")  # has hash in filename

  test "hashed filenames contain content hash from source file":
    let
      formats = @["image/webp"]
      input = readFile(fixtures_dir / "standalone_img.html")
      (output, manifest) = rewrite_html(input, formats, fixtures_dir)

    # The output filename should have the pattern name.HASH.ext
    let parts = manifest[0].output.split('.')
    check parts.len == 3  # photo, hash, webp
    check parts[0] == "photo"
    check parts[2] == "webp"
    check parts[1].len >= 6  # hash is at least 6 chars


suite "HTML: <picture> with srcset expansion":
  test "adds sources for missing formats, preserving breakpoints":
    let
      formats = @["image/webp", "image/avif"]
      input = readFile(fixtures_dir / "picture_with_srcset.html")
      (output, manifest) = rewrite_html(input, formats, fixtures_dir)
      html = parseHtml(output)
      pictures = html.find_all_recursive("picture")

    check pictures.len == 1
    let sources = pictures[0].find_all_recursive("source")

    # Original source (jpeg) + 2 generated (webp, avif)
    check sources.len == 3

    # Generated sources should have data-picturesque
    var generated_count = 0
    for source in sources:
      if source.attr("data-picturesque") != "":
        generated_count += 1
    check generated_count == 2

  test "preserves width descriptors in generated srcsets":
    let
      formats = @["image/webp"]
      input = readFile(fixtures_dir / "picture_with_srcset.html")
      (output, manifest) = rewrite_html(input, formats, fixtures_dir)
      html = parseHtml(output)
      pictures = html.find_all_recursive("picture")
      sources = pictures[0].find_all_recursive("source")

    # Find the generated webp source
    for source in sources:
      if source.attr("type") == "image/webp":
        let srcset = source.attr("srcset")
        check srcset.contains("300w")
        check srcset.contains("900w")

  test "generates manifest entry per format per width variant":
    let
      formats = @["image/webp", "image/avif"]
      input = readFile(fixtures_dir / "picture_with_srcset.html")
      (_, manifest) = rewrite_html(input, formats, fixtures_dir)

    # 2 formats x 2 widths = 4 manifest entries
    check manifest.len == 4

    var webp_entries = 0
    var avif_entries = 0
    for entry in manifest:
      if entry.format == "image/webp": inc webp_entries
      if entry.format == "image/avif": inc avif_entries
      check entry.width > 0  # width descriptors present

    check webp_entries == 2
    check avif_entries == 2

  test "does not duplicate already-present formats":
    let
      formats = @["image/jpeg", "image/webp"]  # jpeg already in source
      input = readFile(fixtures_dir / "picture_with_srcset.html")
      (output, manifest) = rewrite_html(input, formats, fixtures_dir)
      html = parseHtml(output)
      pictures = html.find_all_recursive("picture")
      sources = pictures[0].find_all_recursive("source")

    # Original jpeg + 1 generated webp (jpeg not duplicated)
    var jpeg_sources = 0
    for source in sources:
      if source.attr("type") == "image/jpeg":
        jpeg_sources += 1
    check jpeg_sources == 1


suite "HTML: <picture> with multiplier descriptors":
  test "preserves multiplier descriptors in generated srcsets":
    let
      formats = @["image/webp"]
      input = readFile(fixtures_dir / "picture_with_multiplier.html")
      (output, manifest) = rewrite_html(input, formats, fixtures_dir)
      html = parseHtml(output)
      pictures = html.find_all_recursive("picture")
      sources = pictures[0].find_all_recursive("source")

    for source in sources:
      if source.attr("type") == "image/webp":
        let srcset = source.attr("srcset")
        check srcset.contains("1x")
        check srcset.contains("2x")


suite "HTML: focus point preservation":
  test "copies data-focus to generated sources":
    let
      formats = @["image/webp"]
      input = readFile(fixtures_dir / "picture_with_focus.html")
      (output, manifest) = rewrite_html(input, formats, fixtures_dir)
      html = parseHtml(output)
      pictures = html.find_all_recursive("picture")
      sources = pictures[0].find_all_recursive("source")

    for source in sources:
      if source.attr("data-picturesque") != "":
        check source.attr("data-focus") == "25% 75%"


suite "HTML: multiple images in one file":
  test "expands all image references in a single file":
    let
      formats = @["image/webp"]
      input = readFile(fixtures_dir / "multiple_images.html")
      (output, manifest) = rewrite_html(input, formats, fixtures_dir)
      html = parseHtml(output)
      pictures = html.find_all_recursive("picture")

    # 2 standalone imgs wrapped + 1 existing picture = 3 pictures
    check pictures.len == 3

  test "generates manifest entries for all images":
    let
      formats = @["image/webp"]
      input = readFile(fixtures_dir / "multiple_images.html")
      (_, manifest) = rewrite_html(input, formats, fixtures_dir)

    # logo.png (1) + banner (2 widths) + footer.png (1) = 4 entries
    check manifest.len >= 3


suite "HTML: idempotency":
  test "running twice produces identical output":
    let
      formats = @["image/webp", "image/avif"]
      input = readFile(fixtures_dir / "standalone_img.html")
      (first_pass, _) = rewrite_html(input, formats, fixtures_dir)
      (second_pass, _) = rewrite_html(first_pass, formats, fixtures_dir)

    check first_pass == second_pass

  test "strips previously generated sources before re-expanding":
    let
      formats = @["image/webp", "image/avif"]
      input = readFile(fixtures_dir / "already_expanded.html")
      (output, _) = rewrite_html(input, formats, fixtures_dir)
      html = parseHtml(output)
      pictures = html.find_all_recursive("picture")
      sources = pictures[0].find_all_recursive("source")

    # Should have exactly 2 generated sources (not 4)
    var generated = 0
    for source in sources:
      if source.attr("data-picturesque") != "":
        generated += 1
    check generated == 2

  test "unwraps generated <picture> wrapper before re-expanding":
    let
      formats = @["image/webp", "image/avif"]
      input = readFile(fixtures_dir / "wrapped_img.html")
      (output, _) = rewrite_html(input, formats, fixtures_dir)
      html = parseHtml(output)
      pictures = html.find_all_recursive("picture")

    # Should still be 1 picture, not nested
    check pictures.len == 1

  test "changing format list produces correct output":
    let
      input = readFile(fixtures_dir / "already_expanded.html")
      (output_webp_only, _) = rewrite_html(input, @["image/webp"], fixtures_dir)
      html = parseHtml(output_webp_only)
      pictures = html.find_all_recursive("picture")
      sources = pictures[0].find_all_recursive("source")

    # Only 1 generated source now (webp), not 2
    var generated = 0
    for source in sources:
      if source.attr("data-picturesque") != "":
        generated += 1
    check generated == 1


suite "HTML: generated source ordering":
  test "generated sources appear before original sources":
    let
      formats = @["image/webp", "image/avif"]
      input = readFile(fixtures_dir / "picture_with_srcset.html")
      (output, _) = rewrite_html(input, formats, fixtures_dir)
      html = parseHtml(output)
      pictures = html.find_all_recursive("picture")
      sources = pictures[0].find_all_recursive("source")

    # First sources should be generated, last should be original
    var seen_original = false
    for source in sources:
      if source.attr("data-picturesque") == "":
        seen_original = true
      else:
        # Generated source should come before any original
        check seen_original == false
