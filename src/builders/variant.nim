import std/[xmltree,strutils,sequtils,options]

import dimage

import ../image
import ../global

import resolution, focus

proc build_variant_from_img*( img: XmlNode ): Variant =
  result = init_variant( uri = img.attr( "src" ) )
  result.resolution.original_string = $img
  try:
    result.focus = build_focus_from_data_attribute( img.attr( "data-focus" ))
  except FocusParseError:
    let msg = getCurrentExceptionMsg()
    if verbose_logging:
      echo "Error while processing " & $img & " - " & msg



proc build_variant_from_srcset_string( srcset: string, parent_mime_type: MimeType, focus: Option[Focus] ): Variant =
  result = init_variant()

  let split = srcset.strip.split( ' ' ).map(proc (s :string): string = s.strip)
  let mime_type = get_mime_type( split[0] )

  result.resolution = build_resolution_from_srcset_string( srcset )
  result.focus = focus
  result.mime_type = if parent_mime_type == MimeType.Unknown: mime_type else: parent_mime_type


proc build_variants_from_node*( node: XmlNode ): seq[Variant] =
  result = newSeq[Variant]()

  let
    srcsets = node.attr( "srcset" ).split( ',' )
    mime_type = parse_enum[MimeType]( node.attr( "type" ).strip, MimeType.Unknown )
  var
    focus = none(Focus)

  try:
    focus = build_focus_from_data_attribute( node.attr( "data-focus" ))
  except FocusParseError:
    let msg = getCurrentExceptionMsg()
    if verbose_logging:
      echo "Error while processing " & $node & " - " & msg

  for srcset in srcsets:
    try:
      result.add( build_variant_from_srcset_string( srcset, mime_type, focus ))
    except SrcsetParseError:
      let msg = getCurrentExceptionMsg()
      if verbose_logging:
        echo "Error while processing " & $node & " - " & msg
