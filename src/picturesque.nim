import std/[htmlparser,xmltree,os,re,strutils,tables,options]

import global
from image as image_types import add
import builders/image

proc deepth_first_search( current: XmlNode, spaces: int = 0 ) =
  if current.kind == xnElement:
    if current.tag == "img":
      images.add( build_image_from_img( current ))
    elif current.tag == "picture":
      images.add( build_image_from_picture( current ))
    else:
      for child in current:
        deepth_first_search( child, spaces + 2 )



proc regex_search( path: string ) =
  var urls: seq[string]
  let file = readFile(path)

  urls = file.findAll(re"url\([^\)]+\)")

  for url in urls:
    images.add( build_image_from_uri( url[4 .. ^2] ))



proc main(verbose=false, print_only=false, args: seq[string]) =
  var
    errors: seq[string]
    html: XmlNode

  for path in args:
    errors = @[]
    html = loadHtml( path, errors )
    current_file = absolute_path( path )
    current_path = split_file( current_file )[0]
    verbose_logging = verbose

    if verbose_logging:
      if errors.len > 0:
        echo "HTML parsing errors while processing " & path
        for error in errors:
          echo "   " & error.replace(path)

    if html.len == 0: # Not HTML, regex scan instead - assuming CSS in some form
      regex_search( path )
    else:
      deepth_first_search( html )

  if print_only:
    if verbose_logging:
      echo "\n\n\n"
    for image_path, image in images:
      echo "Image " & image_path
      echo "  intrinsic size: " & $image.size[0] & "px x " & $image.size[1] & "px"
      echo "  Referenced in the following places:"
      for (path, original_string) in image.original_strings:
        echo "    file: " & path
        echo "    line: " & original_string
        echo ""

      echo "  The following variants were detected:"
      for variant in image.variants:
        echo "    " & $variant.mime_type
        echo "    " & $variant.resolution
        if variant.focus.isSome:
          echo "    " & $variant.focus.get()
        echo ""
      echo ""

  quit(0)



when isMainModule:
  import cligen; dispatch main, help={"verbose": "Log any errors found while processing", "print_only": "Print summary of result instead of returning a JSON structure"}
