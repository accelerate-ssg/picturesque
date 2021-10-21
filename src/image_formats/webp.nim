import std/[streams,bitops,strutils,endians]


proc get_size_from_vp8_header_block( stream: var FileStream ): (int,int)
proc get_size_from_vp8l_header_block( stream: var FileStream ): (int,int)
proc get_size_from_vp8_header_block( stream: var FileStream ): (int,int)

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
      get_size_from_vp8_header_block( stream )
    else:
      echo "Unknown Webp encoding: " & encoding
      return (-1,1)



proc read_basic_size_values_at_position( stream: var FileStream, pos: int ): uint32 =
  var buffer: array[4, byte]
  var section:uint32

  stream.set_position(pos)
  doAssert stream.readData(buffer.addr, 4) == 4
  section = cast[uint32](buffer)

  littleEndian32( result.addr, section.addr)

proc get_size_from_vp8_header_block( stream: var FileStream ): (int,int) =
  let raw = stream.read_basic_size_values_at_position(26)
  let w = raw.bitsliced(0 .. 13)
  let h = raw.bitsliced(16 .. 29)

  return (int(w),int(h))



proc get_size_from_vp8l_header_block( stream: var FileStream ): (int,int) =
  let raw = stream.read_basic_size_values_at_position(21)
  let w = raw.bitsliced(0 .. 13)
  let h = raw.bitsliced(14 .. 27)

  return (int(w)+1,int(h)+1)



proc read_extended_size_value_at_position( stream: var FileStream, pos: int ): int =
  var buffer: array[4, byte]
  var section:uint32
  var raw:uint32

  stream.set_position(24)
  doAssert stream.readData(buffer.addr, 4) == 4
  section = cast[uint32](buffer)

  littleEndian32( raw.addr, section.addr)

  int(raw.bitsliced(0 .. 23))


proc get_size_from_vp8_header_block( stream: var FileStream ): (int,int) =
    let w = stream.read_extended_size_value_at_position( 24 )
    let h = stream.read_extended_size_value_at_position( 27 )

    return (int(w)+1,int(h)+1)



assert get_size("examples/animated.webp") == (400,400)
assert get_size("examples/jonas_lossy.webp") == (512,512)
assert get_size("examples/jonas_lossless.webp") == (512,512)
