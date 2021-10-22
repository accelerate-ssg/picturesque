import std/[streams,bitops,endians]


type
  Errors* = enum
    Invalid = (1, "File is not a valid Webp")



# Helper to read 4 byte integers in little endian.
proc read_int32( stream: FileStream ): int =
  var raw = stream.read_uint32()
  littleEndian32( result.addr, raw.addr)


# Lossy - Size is two bytes, 14 bits length and 2 bits scale, one based starting
# at byte 26.
proc get_size_from_vp8_header_block( stream: var FileStream ): (int,int) =
  stream.set_position( 26 )
  let raw = stream.read_int32()
  let width = int( raw.bitsliced( 0 .. 13 ))
  let height = int( raw.bitsliced( 16 .. 29 ))

  return (width, height)



# Lossless - Size is two 14 bit values, back to back, starting at byte 21.
# Size is also zero based, actual size - 1, so we need to add one.
proc get_size_from_vp8l_header_block( stream: var FileStream ): (int,int) =
  stream.set_position( 21 )
  let raw = stream.read_int32()
  let width = int( raw.bitsliced( 0 .. 13 )) + 1
  let height = int( raw.bitsliced( 14 .. 27 )) + 1

  return (width, height)



# Extended - Size is two 3 byte integers starting at byte 24 resp. 27
# Size is also zero based, actual size - 1, so we need to add one.
proc get_size_from_vp8x_header_block( stream: var FileStream ): (int,int) =
    var raw:int

    stream.set_position( 24 )
    raw = stream.read_int32()
    let width = int( raw.bitsliced( 0 .. 23 )) + 1

    stream.set_position( 27 )
    raw = stream.read_int32()
    let height = int( raw.bitsliced( 0 .. 23 )) + 1

    return ( width, height )



proc get_size*( path:string ): (int,int) =
  var stream = new_file_stream( path, fm_read )
  defer: stream.close()

  stream.set_position(12)
  let encoding = stream.read_str(4)
  case encoding:
    of "VP8 ":
      get_size_from_vp8_header_block( stream )
    of "VP8L":
      get_size_from_vp8l_header_block( stream )
    of "VP8X":
      get_size_from_vp8x_header_block( stream )
    else:
      return (-1,1)



assert get_size("src/image_formats/examples/animated.webp") == (400,400)
assert get_size("src/image_formats/examples/jonas_lossy.webp") == (512,512)
assert get_size("src/image_formats/examples/jonas_lossless.webp") == (512,512)
assert get_size("src/image_formats/examples/jonas.png") == (-1,1)
