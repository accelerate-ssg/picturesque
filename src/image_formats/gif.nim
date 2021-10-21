# The following GIF Signature identifies  the  data  following  as  a valid GIF
# image stream.  It consists of the following six characters: G I F 8 7 a
#
# LSB first
#
# Width  7-0 byte 1 and 7-0 byte 2
# Height 7-0 byte 1 and 7-0 byte 2

import std/[streams, endians]

proc get_size*( path: string ): (int,int) =
  var stream = new_file_stream( path, fm_read )
  defer: stream.close()

  stream.setPosition(0)
  onFailedAssert(msg):
    return (-1,1)

  doAssert stream.readChar() == 'G'
  doAssert stream.readChar() == 'I'
  doAssert stream.readChar() == 'F'
  doAssert stream.readChar() == '8'
  doAssert stream.readChar() == '7' or stream.readChar() == '9'
  doAssert stream.readChar() == 'a'

  var section:uint16
  var raw:uint16

  section = stream.readUInt16()
  littleEndian16( raw.addr, section.addr)
  let w = int(raw)
  section = stream.readUInt16()
  littleEndian16( raw.addr, section.addr)
  let h = int(raw)

  return (w,h)

assert get_size( "src/image_formats/examples/jonas.gif" ) == (512,512)
assert get_size( "src/image_formats/examples/jonas.jpg" ) == (-1,1)
