## Tests for utility functions: content hashing, filename generation, MIME type mapping

import std/[unittest, os, strutils]

import picturesque/utils

const fixtures_dir = currentSourcePath().parentDir / "fixtures"

suite "MIME type to file extension mapping":
  test "maps image/webp to .webp":
    check mime_to_ext("image/webp") == ".webp"

  test "maps image/avif to .avif":
    check mime_to_ext("image/avif") == ".avif"

  test "maps image/jpeg to .jpg":
    check mime_to_ext("image/jpeg") == ".jpg"

  test "maps image/png to .png":
    check mime_to_ext("image/png") == ".png"

  test "maps image/svg+xml to .svg":
    check mime_to_ext("image/svg+xml") == ".svg"

  test "maps image/gif to .gif":
    check mime_to_ext("image/gif") == ".gif"


suite "file extension to MIME type mapping":
  test "maps .jpg to image/jpeg":
    check ext_to_mime(".jpg") == "image/jpeg"

  test "maps .jpeg to image/jpeg":
    check ext_to_mime(".jpeg") == "image/jpeg"

  test "maps .png to image/png":
    check ext_to_mime(".png") == "image/png"

  test "maps .webp to image/webp":
    check ext_to_mime(".webp") == "image/webp"

  test "maps .avif to image/avif":
    check ext_to_mime(".avif") == "image/avif"

  test "maps .svg to image/svg+xml":
    check ext_to_mime(".svg") == "image/svg+xml"

  test "maps .gif to image/gif":
    check ext_to_mime(".gif") == "image/gif"


suite "content hashing":
  test "produces a non-empty hash string":
    let hash = content_hash(fixtures_dir / "photo.jpg")
    check hash.len > 0

  test "produces a stable hash for the same file":
    let hash1 = content_hash(fixtures_dir / "photo.jpg")
    let hash2 = content_hash(fixtures_dir / "photo.jpg")
    check hash1 == hash2

  test "hash is a reasonable length (6-16 hex chars)":
    let hash = content_hash(fixtures_dir / "photo.jpg")
    check hash.len >= 6
    check hash.len <= 16

  test "hash contains only hex characters":
    let hash = content_hash(fixtures_dir / "photo.jpg")
    for c in hash:
      check c in {'0'..'9', 'a'..'f'}


suite "hashed filename generation":
  test "generates hashed filename from source path and target format":
    let result = hashed_filename("photo.jpg", "image/webp", "a3f8b2")
    check result == "photo.a3f8b2.webp"

  test "preserves path prefix":
    let result = hashed_filename("images/photo.jpg", "image/avif", "a3f8b2")
    check result == "images/photo.a3f8b2.avif"

  test "handles filenames with multiple dots":
    let result = hashed_filename("my.photo.name.jpg", "image/webp", "a3f8b2")
    check result == "my.photo.name.a3f8b2.webp"

  test "preserves srcset suffixes in filename":
    let result = hashed_filename("hero_small.jpg", "image/avif", "a3f8b2")
    check result == "hero_small.a3f8b2.avif"
