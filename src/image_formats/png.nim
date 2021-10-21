# The first eight bytes of a PNG file always contain the following (decimal) values:
#   137 80 78 71 13 10 26 10
# IHDR:
#   Width:              4 bytes max 2^31, not 0
#   Height:             4 bytes max 2^31, not 0

import std/[streams, endians]

proc get_size*( path: string ): (int,int) =
  var stream = new_file_stream( path, fm_read )
  defer: stream.close()

  stream.setPosition(0)
  onFailedAssert(msg):
    return (-1,1)
  doAssert stream.readUInt8() == 137
  doAssert stream.readUInt8() == 80
  doAssert stream.readUInt8() == 78
  doAssert stream.readUInt8() == 71
  doAssert stream.readUInt8() == 13
  doAssert stream.readUInt8() == 10
  doAssert stream.readUInt8() == 26
  doAssert stream.readUInt8() == 10

  stream.set_position(16)

  var section:uint32
  var raw:uint32

  section = stream.readUInt32()
  bigEndian32( raw.addr, section.addr)
  let w = int(raw)
  section = stream.readUInt32()
  bigEndian32( raw.addr, section.addr)
  let h = int(raw)

  return (w,h)

assert get_size( "src/image_formats/examples/jonas.png" ) == (512,512)
assert get_size( "src/image_formats/examples/jonas.jpg" ) == (-1,1)
