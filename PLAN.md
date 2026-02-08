# Implementation Plan

## Overview

Picturesque takes a generated static site, scans its HTML and CSS files for
image references, expands them into all requested target formats with content-
hashed filenames, rewrites the source files in place, and outputs a JSON
manifest of variants that need generating.

The process is idempotent: generated markup is tagged so re-runs replace
previous output cleanly.

## Phase 1: Remove legacy code

The codebase contains features that have been superseded by other tools or
design changes. These need to be cleaned up before building new functionality.

### 1.1 Remove `dimage` dependency

Image size extraction is handled externally by the `imaginary` library.
All `dimage` imports, `get_size()` calls, `get_mime_type()` calls, and the
`size` field on `Image` should be removed.

**Files affected:**
- `picturesque.nimble` - remove `requires "dimage >= 0.1.0"`
- `src/image.nim` - remove `import dimage`, remove `size` field from `Image`,
  remove `MimeType` usage (replace with local string or enum)
- `src/builders/image.nim` - remove `import dimage`, remove `get_image_size`
  proc and all calls to it
- `src/builders/variant.nim` - remove `import dimage`, replace `MimeType`
  references
- `src/picturesque.nim` - remove size printing in `print_only` block

### 1.2 Remove template references

The `<template>` feature was deprecated in favour of expanding from real source
definitions. No code was implemented for it, but references exist in
documentation (already cleaned up in the README update).

### 1.3 Replace MimeType with local type

`dimage.MimeType` is used throughout. Replace with a simple local approach -
either a string-based MIME type or a minimal enum. A string is simplest since
the target formats come in as user-provided strings anyway.

### 1.4 Fix bug in `src/builders/image.nim:14`

`(-1, 1)` should be `(-1, -1)`. This becomes moot once `get_image_size` is
removed, but worth noting as the kind of bug that lack of tests let through.

## Phase 2: Rework the data model

### 2.1 New CLI parameters

Add `--formats` parameter: a comma-separated list of target MIME types.
Example: `--formats "image/webp,image/avif,image/jpeg"`

This is required for the expand/rewrite functionality.

### 2.2 Rework `Image` and `Variant` types

Current types are oriented around detection/cataloguing. The new model needs
to support the detect-expand-rewrite workflow.

**Image** should track:
- `source_path: string` - absolute path to the original image file on disk
- `original_strings: seq[(string, string)]` - where it was referenced (file, markup)
- `variants: seq[Variant]` - detected variants from the source

**Variant** should track:
- `uri: string` - the filename/path as it appears in the source
- `mime_type: string` - MIME type (from `type` attribute or file extension)
- `resolution: Resolution` - width descriptor or multiplier
- `focus: Option[Focus]` - focus point if specified

### 2.3 Content hashing

Add a proc that takes a file path, reads the file contents, and returns a
truncated hash (e.g. first 8 chars of MD5 or SHA-256). This hash is inserted
into generated filenames: `name.HASH.ext`.

The hash is computed from the **source image file contents only**. Same source
file = same hash across all variants and sizes.

### 2.4 Filename generation

Given a source filename, a target format, and a hash:
- `photo.jpg` + `image/webp` + `a3f8b2c1` -> `photo.a3f8b2c1.webp`
- `hero_small.jpg` + `image/avif` + `a3f8b2c1` -> `hero_small.a3f8b2c1.avif`

Need a proc to map MIME types to file extensions:
- `image/webp` -> `.webp`
- `image/avif` -> `.avif`
- `image/jpeg` -> `.jpg`
- `image/png` -> `.png`
- `image/svg+xml` -> `.svg`

### 2.5 Manifest type

A `ManifestEntry` for JSON output:
- `source: string` - path to the source image
- `output: string` - generated filename (with hash)
- `format: string` - target MIME type
- `width: int` (optional) - target width if from a width descriptor

The manifest is collected during processing and serialized to JSON at the end.

## Phase 3: Single-pass detect, expand, and rewrite

This is the core new functionality. Each file is read, processed, and written
back in a single pass.

### 3.1 Idempotency mechanism

Before expanding, strip all previously generated content:
- **HTML**: Remove all elements with `data-picturesque` attribute. Unwrap
  `<picture data-picturesque>` wrappers back to bare `<img>`.
- **CSS**: Remove `image-set()` blocks marked with `/* picturesque */` and
  restore the original `url()` (stored in a CSS comment or derived from the
  remaining entries).

This ensures the tool can be run repeatedly with the same result.

### 3.2 HTML: standalone `<img>` handling

When an `<img>` is found that is NOT inside a `<picture>`:

1. Read the `src` attribute to identify the source image
2. Compute the content hash of the source file
3. For each target format, create a `<source>` element with:
   - `data-picturesque` attribute (marks it as generated)
   - `type` attribute with the MIME type
   - `srcset` attribute with the hashed filename
4. Wrap the `<img>` in a new `<picture data-picturesque>` element containing
   the generated `<source>` elements followed by the original `<img>`
5. Add entries to the manifest

### 3.3 HTML: `<picture>` with `<source>` handling

When a `<picture>` is found:

1. Parse existing `<source>` elements to extract:
   - MIME types already covered
   - Resolution breakpoints (from srcset)
   - Focus points
2. Identify the source image from the `<img>` child's `src`
3. Compute the content hash
4. For each target format NOT already present:
   - Create a `<source data-picturesque>` with matching srcset breakpoints
     and hashed filenames
5. Insert generated sources before existing ones in the `<picture>`
6. Add entries to the manifest

### 3.4 CSS: `url()` handling

When a `url()` reference to an image is found (excluding `@font-face`,
`cursor`, and other non-image contexts):

1. Extract the image path
2. Compute the content hash
3. Replace with `image-set()` containing:
   - An entry for each target format with hashed filename and `type()`
   - A `/* picturesque */` comment marker for idempotency
4. Add entries to the manifest

### 3.5 CSS: `image-set()` handling

When an existing `image-set()` is found:

1. Parse existing entries to get URLs, resolutions, and types
2. Identify which formats are already present
3. For each target format not present:
   - Derive the new filename from the existing entry's filename pattern
   - Add an entry with the hashed filename and `type()`
4. Mark generated entries with `/* picturesque */`
5. Handle `-webkit-image-set()` prefix variant
6. Add entries to the manifest

### 3.6 CSS: `cross-fade()` handling (low priority)

Extract `url()` references inside `cross-fade()` and expand them. This is an
edge case but should be handled for completeness.

### 3.7 File writing

After processing all image references in a file, write the modified content
back to the same path. The file is overwritten in place.

## Phase 4: JSON manifest output

### 4.1 Implement default JSON output

When `--print_only` is not set, serialize the collected manifest entries as a
JSON array to stdout. Each entry contains:

```json
{
  "source": "path/to/original.jpg",
  "output": "path/to/generated.a3f8b2c1.webp",
  "format": "image/webp",
  "width": 300
}
```

The `width` field is only present when the variant came from a width descriptor.

### 4.2 Update `--print_only` output

Update the human-readable summary to reflect the new data model (no size info,
show hash, show generated filenames).

## Phase 5: Edge cases and robustness

### 5.1 Improve CSS `url()` detection

The current regex `url\([^\)]+\)` is minimal. Improve to:
- Handle single-quoted, double-quoted, and unquoted URLs
- Strip quotes when extracting the path
- Skip `url()` inside `@font-face` blocks (not images)
- Skip fragment-only URLs like `url(#id)` (SVG filter references)
- Handle whitespace inside the parentheses

### 5.2 Handle missing source files gracefully

If a source image file doesn't exist on disk, we can't compute its hash.
Options:
- Skip it and log a warning (preferred)
- Use a placeholder hash

### 5.3 Deduplication

Same image referenced in multiple files should produce only one set of manifest
entries. The current `ImageList` deduplication by path handles this and should
be preserved.

### 5.4 Relative path handling

Generated filenames in srcset/image-set should use the same relative path
convention as the original reference. If the source used a relative path,
generated variants should too.

## Implementation order

1. Phase 1 (cleanup) - removes dead code, simplifies the codebase
2. Phase 2 (data model) - establishes the foundation
3. Phase 3.1 (idempotency) - needed before any rewriting
4. Phase 3.2 (HTML `<img>`) - simplest rewrite case
5. Phase 3.3 (HTML `<picture>`) - builds on 3.2
6. Phase 3.4 (CSS `url()`) - independent of HTML work
7. Phase 3.5 (CSS `image-set()`) - builds on 3.4
8. Phase 4 (JSON output) - can be done any time after Phase 2
9. Phase 5 (edge cases) - polish
10. Phase 3.6 (CSS `cross-fade()`) - lowest priority

## Dependencies after cleanup

After removing `dimage`, the dependency list becomes:
- `nim >= 1.4.8`
- `regex >= 0.19.0` - CSS pattern matching
- `cligen >= 1.5.28` - CLI generation
- `fusion >= 1.1` - pattern matching

Standard library modules used:
- `std/htmlparser` and `std/xmltree` - HTML parsing and manipulation
- `std/json` - manifest serialization
- `std/os` - file operations
- `std/re` or `regex` - CSS pattern matching
- `std/strutils`, `std/sequtils` - string/sequence utilities
- `std/tables` - image deduplication
- `std/options` - optional focus points
- `std/hashes` or `std/md5` - content hashing
