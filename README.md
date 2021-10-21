# Picturesque

While this toll was built to be part of the Accelerate toolchain, it is a
standalone command line tool that anyone can use.

## Why?

Most static site frameworks use some kind of side channel to keep track of the
image variants that a site needs - different resolutions and formats etc.

Accelerate uses a standards first approach and wanted to keep as much of this
information as possible in the actual HTML, CSS and JS. By using `<picture>`,
`<img>` and `<template>` tags we have an approach that will let you define all
the variant information where you need it in the end anyway: the source.

## How?

Let us look at an example:

```
<picture>
  <template>
    <source data-focus="10% 50%" srcset="_small 300w, _medium 600w, _large 900w 1.5x">
  </template>
  <source data-focus="10% 50%" type="image/svg+xml" srcset="pyramid.svg 2x">
  <source type="image/webp" srcset="pyramid_small.webp 300w,pyramid_medium.webp 600w, pyramid_large.webp 900w 1.5x">
  <img src="pyramid.png" alt="regular pyramid built from four equilateral triangles" />
</picture>
```

This is all standards compliant HTML that works directly in the browser. It also
contains almost all the data you need to create a list of all the variants you
need to create in order for this to actually work.

Picturesque will parse this to an internal representation that keeps track of
all the images and their variants across all the documents it processes. That
means that even if you use the same image in different documents it would only
be one entry in the final list.

By parsing the `srcset`, `type` and `src` attributes we can extract all the
relative sizes we need.

Picturesque will then find out which of the references versions is an actual
file on disk and create variants based on the extracted data plus the size of
that image.

The above block would result in the following abstract variants being created:
* pyramid.svg that will be used for x2 resolutions (this better be an actual
  file since it is infeasible to create a good SVG from a raster original)
* pyramid_small.webp 300px wide
* pyramid_medium.webp 600px wide
* pyramid_large.webp 900px wide
* pyramid.png of unknown size

### Ex 1

If we focus on the raster versions and assume that pyramid.png exists on disk
and has the size 600px x 400px we would get the following output:
* pyramid_small.webp 300px x 200px
* pyramid_medium.webp 600px x 400px
* pyramid_large.webp 900px x 600px

These are all the _new_ variants that we need to create.

### Ex 2

If we focus on the raster versions and assume that pyramid.svg exists on disk
we would get the following output:
* pyramid_small.webp 300px x 200px
* pyramid_medium.webp 600px x 400px
* pyramid_large.webp 900px x 600px
* pyramid.png 300 x 200px

Because Picturesque will assume the smallest variant size for files with
unspecified size, or the original size if the file already exists.

You can solve this by declaring one of the variants as the fallback:
`<img src="pyramid_medium.webp" alt="regular pyramid built from four equilateral triangles" />`
would have resulted in that variant being used, since the filename is the same.

## Templates

You can define templates as well, as above, and these can be used to have
Picturesque fill in other formats when processing the files. So with the given
template above and a directive to create variants for the `image/png`,
`image/jpeg` and `image/avif` you would get the following:

```
<picture>
  <source data-focus="10% 50%" type="image/png" srcset="pyramid_small.png 300w, pyramid_medium.png 600w, pyramid_large.png 900w 1.5x">
  <source data-focus="10% 50%" type="image/jpeg" srcset="pyramid_small.jpg 300w, pyramid_medium.jpg 600w, pyramid_large.jpg 900w 1.5x">
  <source data-focus="10% 50%" type="image/avif" srcset="pyramid_small.avif 300w, pyramid_medium.avif 600w, pyramid_large.avif 900w 1.5x">
  <source data-focus="10% 50%" type="image/svg+xml" srcset="pyramid.svg 2x">
  <source type="image/webp" srcset="pyramid_small.webp 300w,pyramid_medium.webp 600w, pyramid_large.webp 900w 1.5x">
  <img src="pyramid.png" alt="regular pyramid built from four equilateral triangles" />
</picture>
```

With an accompanying list of all the variants that needs to be created.

This allows you to process files and add new formats without having to touch the
source files manually.
