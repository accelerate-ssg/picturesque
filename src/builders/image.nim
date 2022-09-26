import std/[xmltree,os,sequtils]
import dimage

import ../global
import ../image
import variant

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
