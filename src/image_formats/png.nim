import std/[streams, endians, strutils]

type
  Errors* = enum
    Invalid = (1, "File is not a valid PNG")

const PNG_SIGNATURE = 0x0A1A0A0D474E5089

proc read_int32( stream: FileStream ): int =
  var raw = stream.readUInt32()
  bigEndian32( result.addr, raw.addr)

proc get_size*( path: string ): (int,int) =
  var stream = new_file_stream( path, fm_read )
  defer: stream.close()

  onFailedAssert(msg):
    return (-1,1)
  doAssert stream.readInt64() == PNG_SIGNATURE

  stream.set_position(16)

  let width = stream.read_int32()
  let height = stream.read_int32()

  return ( width, height )

assert get_size( "src/image_formats/examples/jonas.png" ) == (512,512)
assert get_size( "src/image_formats/examples/jonas.jpg" ) == (-1,1)
