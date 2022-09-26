import std/[tables,sequtils,options]
import dimage

type
  Units* {.pure.} = enum
    Pixels = "px",
    Percent = "%",
    Unknown = "?"

  ScrSet* = enum
    Width,
    Multiplier

  Resolution* = object
    kind*: ScrSet
    value*: float
    original_string*: string

  Focus* = object
    x*: float
    y*: float
    unit*: Units

  Variant* = object
    focus*: Option[Focus]
    mime_type*: MimeType
    resolution*: Resolution

  Image* = object
    variants*: seq[ Variant ]
    size*: (int,int)
    path*: string
    original_strings*: seq[ (string,string) ]

  ImageList* = TableRef[ string, Image ]

proc init_focus*( x: float = 50.0, y:float = 50.0, unit:Units = Units.Unknown ): Focus =
  Focus( x: x, y: y, unit: unit )



proc init_resolution*( kind:ScrSet = Multiplier, value:float = 1.0, original_string:string = "" ): Resolution =
  Resolution( kind: kind, value: value, original_string: original_string)



proc init_variant*( uri:string = "" ): Variant =
  result = Variant()
  result.mime_type = get_mime_type( uri )
  result.focus = none(Focus)
  result.resolution = init_resolution( original_string = uri )



proc init_image*(): Image =
  result = Image()
  result.variants = @[]
  result.size = (-1,-1)
  result.path = ""
  result.original_strings = @[]

proc merge*( a: Image, b: Image ): Image =
  result = Image()
  result.variants = (a.variants & b.variants).deduplicate
  result.size = if a.size[0] != -1:
    a.size
  else:
    b.size
  result.original_strings = a.original_strings & b.original_strings

proc add*( list: ImageList, image: Image ) =
  if list.hasKey( image.path ):
    list[ image.path ] = list[ image.path ].merge( image )
  else:
    list[ image.path ] = image
