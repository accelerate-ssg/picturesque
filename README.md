# Picturesque

While this tool was built to be part of the Accelerate toolchain, it is a
standalone command line tool that anyone can use.

## Why?

Most static site frameworks use some kind of side channel to keep track of the
image variants that a site needs - different resolutions and formats etc.

Accelerate uses a standards first approach and keeps this information in the
actual HTML and CSS source files. By using standard `<picture>`, `<img>` and
`<source>` tags, along with CSS `image-set()`, all variant information lives
where it's needed: in the source.

Picturesque takes a generated static site, detects all image references, expands
them into the requested formats, rewrites the source files, and outputs a
manifest of all image variants that need to be generated.

## How it works

Picturesque operates in a single pass per file:

1. **Detect** - Scan HTML and CSS files for image references
2. **Expand** - For each image, generate entries for every requested target
   format, with content-hashed filenames for cache invalidation
3. **Rewrite** - Update the source file in place with the expanded references
4. **Manifest** - Output a JSON list of all image variants that need generating

The process is **idempotent**. Generated elements are marked with
`data-picturesque` (HTML) or `/* picturesque */` (CSS) so that re-running
the tool strips previous output before re-expanding.

## Examples

### HTML: standalone `<img>`

Given this input and target formats `image/webp,image/avif`:

```html
<img src="photo.jpg" alt="A photo" />
```

Picturesque wraps it in a `<picture>` and adds `<source>` elements:

```html
<picture>
  <source data-picturesque type="image/avif" srcset="photo.a3f8b2.avif" />
  <source data-picturesque type="image/webp" srcset="photo.a3f8b2.webp" />
  <img src="photo.jpg" alt="A photo" />
</picture>
```

### HTML: `<picture>` with srcset

Given this input and target formats `image/webp,image/avif`:

```html
<picture>
  <source type="image/jpeg" srcset="hero_small.jpg 300w, hero_large.jpg 900w" />
  <img src="hero.jpg" alt="Hero image" />
</picture>
```

Picturesque adds sources for the missing formats, preserving the resolution
breakpoints:

```html
<picture>
  <source data-picturesque type="image/avif" srcset="hero_small.a3f8b2.avif 300w, hero_large.a3f8b2.avif 900w" />
  <source data-picturesque type="image/webp" srcset="hero_small.a3f8b2.webp 300w, hero_large.a3f8b2.webp 900w" />
  <source type="image/jpeg" srcset="hero_small.jpg 300w, hero_large.jpg 900w" />
  <img src="hero.jpg" alt="Hero image" />
</picture>
```

### CSS: `url()`

Given this input and target formats `image/webp,image/avif`:

```css
.hero {
  background-image: url("bg.jpg");
}
```

Picturesque replaces it with `image-set()`:

```css
.hero {
  background-image: image-set( /* picturesque */
    "bg.a3f8b2.avif" type("image/avif"),
    "bg.a3f8b2.webp" type("image/webp"),
    "bg.a3f8b2.jpg" type("image/jpeg")
  );
}
```

### CSS: `image-set()`

Existing `image-set()` declarations are expanded with missing formats in the
same way.

## Manifest output

The default output is a JSON manifest listing every variant that needs to be
generated:

```json
[
  {
    "source": "photo.jpg",
    "output": "photo.a3f8b2.webp",
    "format": "image/webp"
  },
  {
    "source": "photo.jpg",
    "output": "photo.a3f8b2.avif",
    "format": "image/avif"
  }
]
```

When a srcset with width descriptors is present, each size produces a separate
manifest entry:

```json
[
  {
    "source": "hero.jpg",
    "output": "hero_small.a3f8b2.avif",
    "format": "image/avif",
    "width": 300
  },
  {
    "source": "hero.jpg",
    "output": "hero_large.a3f8b2.avif",
    "format": "image/avif",
    "width": 900
  }
]
```

Image size extraction is handled externally by the `imaginary` library and is
not part of Picturesque's responsibility.

## Cache invalidation

All generated filenames include a content hash derived from the source image
file. This ensures that when a source image changes, all generated variant
filenames change too, busting any caches.

The hash is inserted before the file extension: `name.HASH.ext`.

## Usage

```
picturesque run [options] [paths to files]
```

### Options

- `--formats` - Comma-separated list of target MIME types
  (e.g. `image/webp,image/avif,image/jpeg`)
- `--print_only` - Print a human-readable summary instead of JSON
- `--verbose` - Log any errors encountered during processing

### Examples

```sh
picturesque run --formats "image/webp,image/avif" index.html css/main.css
```

## Development

Build and run using nimble:

```sh
nimble run picturesque run --formats "image/webp,image/avif" index.html
```

Run tests:

```sh
nimble test
```
