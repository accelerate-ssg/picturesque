

import std/[streams,endians]

type
  Errors* = enum
    Invalid = (1, "File is not a valid JPEG")
    SizeNotFound = (2, "No valid 'ispe' box found in the file")



proc read_int32( stream: FileStream ): int =
  var raw = stream.read_uint32()
  bigEndian32( result.addr, raw.addr )

proc get_size*( path: string ): (int,int) =
  var stream = new_file_stream( path, fm_read )
  defer: stream.close()

  # Return the invalid image code unless the magic bytes match
  onFailedAssert(msg):
    return (-1,1)
  doAssert stream.read_uint8() == 0
  doAssert stream.read_uint8() == 0
  doAssert stream.read_uint8() == 0

  var fourcc = ""
  var position = 0

  while not stream.at_end():
    stream.set_position( position )
    fourcc = stream.read_str(4)
    position += 1

    if fourcc == "ispe":
      discard stream.readUint32() # Box version and flags
      let width = stream.read_int32()
      let height = stream.read_int32()

      return ( width, height )

  return ( -1, 2 )

assert get_size("src/image_formats/examples/jonas.heic") == (512,512)
assert get_size("src/image_formats/examples/jonas.gif") == (-1,1)
