## Tests for CSS detection and rewriting

import std/[unittest, os, strutils]

import picturesque/css_rewrite

const fixtures_dir = currentSourcePath().parentDir / "fixtures"


suite "CSS: url() expansion to image-set()":
  test "replaces url() with image-set() containing all formats":
    let
      formats = @["image/webp", "image/avif", "image/jpeg"]
      input = ".hero { background-image: url(\"bg.jpg\"); }"
      (output, manifest) = rewrite_css(input, formats, fixtures_dir)

    check output.contains("image-set(")
    check output.contains("/* picturesque */")
    check output.contains("type(\"image/webp\")")
    check output.contains("type(\"image/avif\")")
    check output.contains("type(\"image/jpeg\")")

  test "does not contain original url() after expansion":
    let
      formats = @["image/webp", "image/avif"]
      input = ".hero { background-image: url(\"bg.jpg\"); }"
      (output, _) = rewrite_css(input, formats, fixtures_dir)

    # The standalone url("bg.jpg") should be replaced
    check not output.contains("url(\"bg.jpg\")")

  test "handles single-quoted urls":
    let
      formats = @["image/webp"]
      input = ".hero { background-image: url('bg.jpg'); }"
      (output, _) = rewrite_css(input, formats, fixtures_dir)

    check output.contains("image-set(")

  test "handles unquoted urls":
    let
      formats = @["image/webp"]
      input = ".hero { background-image: url(bg.jpg); }"
      (output, _) = rewrite_css(input, formats, fixtures_dir)

    check output.contains("image-set(")

  test "generates manifest entries for each format":
    let
      formats = @["image/webp", "image/avif"]
      input = ".hero { background-image: url(\"bg.jpg\"); }"
      (_, manifest) = rewrite_css(input, formats, fixtures_dir)

    check manifest.len == 2
    for entry in manifest:
      check entry.source == "bg.jpg"
      check entry.format in ["image/webp", "image/avif"]

  test "hashed filenames appear in generated image-set":
    let
      formats = @["image/webp"]
      input = ".hero { background-image: url(\"bg.jpg\"); }"
      (output, manifest) = rewrite_css(input, formats, fixtures_dir)

    # Output filename should be in the CSS
    check output.contains(manifest[0].output)


suite "CSS: multiple url() references in one file":
  test "expands all url() references":
    let
      formats = @["image/webp"]
      input = readFile(fixtures_dir / "styles.css")
      (output, manifest) = rewrite_css(input, formats, fixtures_dir)

    # 3 url() references -> 3 image-set() blocks
    check output.count("image-set(") == 3
    check manifest.len == 3

  test "each url() gets its own hashed filename":
    let
      formats = @["image/webp"]
      input = readFile(fixtures_dir / "styles.css")
      (_, manifest) = rewrite_css(input, formats, fixtures_dir)

    # All outputs should be different files
    var outputs: seq[string] = @[]
    for entry in manifest:
      check entry.output notin outputs
      outputs.add(entry.output)


suite "CSS: image-set() expansion":
  test "adds missing formats to existing image-set":
    let
      formats = @["image/webp", "image/avif", "image/jpeg"]
      input = readFile(fixtures_dir / "styles_with_image_set.css")
      (output, manifest) = rewrite_css(input, formats, fixtures_dir)

    # The first image-set already has jpeg, should add webp and avif
    check output.contains("type(\"image/webp\")")
    check output.contains("type(\"image/avif\")")

  test "preserves resolution descriptors when expanding image-set":
    let
      formats = @["image/webp"]
      input = readFile(fixtures_dir / "styles_with_image_set.css")
      (output, manifest) = rewrite_css(input, formats, fixtures_dir)

    # The retina image-set has 1x/2x, generated entries should too
    check output.contains("1x")
    check output.contains("2x")

  test "does not duplicate already-present formats":
    let
      formats = @["image/jpeg", "image/webp"]  # jpeg already present
      input = """
.hero {
  background-image: image-set(
    "bg.jpg" type("image/jpeg")
  );
}
"""
      (output, _) = rewrite_css(input, formats, fixtures_dir)

    # Should only have one jpeg entry
    check output.count("type(\"image/jpeg\")") == 1


suite "CSS: -webkit-image-set() handling":
  test "expands -webkit-image-set() alongside image-set()":
    let
      formats = @["image/webp", "image/avif"]
      input = readFile(fixtures_dir / "styles_webkit_prefix.css")
      (output, manifest) = rewrite_css(input, formats, fixtures_dir)

    # Both prefixed and unprefixed should be expanded
    check output.contains("-webkit-image-set(")
    check output.contains("image-set(")


suite "CSS: @font-face exclusion":
  test "does not expand url() inside @font-face":
    let
      formats = @["image/webp"]
      input = readFile(fixtures_dir / "styles_font_face.css")
      (output, manifest) = rewrite_css(input, formats, fixtures_dir)

    # Font URLs should be untouched
    check output.contains("url(\"myfont.woff2\")")
    check output.contains("url(\"myfont.woff\")")

    # Only the bg.jpg should be expanded
    check manifest.len == 1
    check manifest[0].source == "bg.jpg"


suite "CSS: fragment-only URLs excluded":
  test "does not expand fragment-only url() references":
    let
      formats = @["image/webp"]
      input = ".icon { filter: url(#blur); }"
      (output, manifest) = rewrite_css(input, formats, fixtures_dir)

    # Fragment URLs are SVG references, not images
    check output.contains("url(#blur)")
    check manifest.len == 0


suite "CSS: idempotency":
  test "running twice produces identical output":
    let
      formats = @["image/webp", "image/avif"]
      input = ".hero { background-image: url(\"bg.jpg\"); }"
      (first_pass, _) = rewrite_css(input, formats, fixtures_dir)
      (second_pass, _) = rewrite_css(first_pass, formats, fixtures_dir)

    check first_pass == second_pass

  test "strips previously generated image-set before re-expanding":
    let
      formats = @["image/webp", "image/avif"]
      input = readFile(fixtures_dir / "styles_already_expanded.css")
      (output, _) = rewrite_css(input, formats, fixtures_dir)

    # Should have exactly one image-set, not nested or duplicated
    check output.count("image-set(") == 1

  test "changing format list updates output correctly":
    let
      input = readFile(fixtures_dir / "styles_already_expanded.css")
      (output, _) = rewrite_css(input, @["image/webp"], fixtures_dir)

    # Only webp now, no avif
    check output.contains("type(\"image/webp\")")
    check not output.contains("type(\"image/avif\")")


suite "CSS: non-image url() preservation":
  test "preserves cursor url() references":
    let
      formats = @["image/webp"]
      input = ".pointer { cursor: url(\"cursor.cur\"), auto; }"
      (output, manifest) = rewrite_css(input, formats, fixtures_dir)

    # .cur files are not images to expand
    check output.contains("url(\"cursor.cur\")")
    check manifest.len == 0
