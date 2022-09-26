# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import std/[htmlparser,xmltree,os,re,strutils,tables,sequtils,options]
import fusion/matching
import dimage

import global,image
import builders/[variant]

{.experimental: "caseStmtMacros".}

type
  ParseError* = object of ValueError

var
  images = ImageList()
  current_file = ""
  current_path = ""



proc get_image_size( path:string ): (int, int) =
  if file_exists(path):
    return get_size(path)
  else:
    if verbose_logging:
      echo "Could not find file: " & path
    return (-1,1)



proc build_image_from_uri*( uri_string: string ): Image =
  result = init_image()

  var
    uri = uri_string

  if uri[0] == '/':
    uri = uri[1 .. ^1]
  result.original_strings = @[ (current_file, uri_string) ]
  result.path = absolute_path( uri, current_path )
  result.size = get_image_size( result.path )
  result.variants = @[ init_variant( uri )]



proc build_image_from_img*( img: XmlNode ): Image =
  result = init_image()
  result.original_strings = @[ (current_file, $img) ]
  result.path = absolute_path( img.attr("src"), current_path )
  result.size = get_image_size( result.path )
  if img.attr( "srcset" ) != "":
    result.variants = build_variants_from_node( img )
  else:
    result.variants = @[ build_variant_from_img( img )]



proc build_image_from_picture*( picture: XmlNode): Image =
  result = init_image()

  let
    img = picture.child( "img" )
    sources = picture.find_all( "source" )

  if not img.isNil:
    result.original_strings = @[ (current_file, $img) ]
    result.path = absolutePath( img.attr("src"), current_path )
    result.size = get_image_size( result.path )
  else:
    if verbose_logging:
      echo "Invalid <picture>, missing <img> - " & $picture

  result.variants = new_seq[Variant]()
  for source in sources:
    var variants = build_variants_from_node( source )
    for variant in variants:
      result.variants.add variant
  result.variants.add( build_variant_from_img( img ))
  result.variants = result.variants.deduplicate



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
