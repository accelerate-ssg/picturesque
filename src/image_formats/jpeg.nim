# See https://wiki.tcl-lang.org/page/Reading+JPEG+image+dimensions for some
# commented TCL code and
# https://github.com/cloudflare/jpegtran/blob/master/rdjpgcom.c for a reference
# implementation in C with comments.

import std/[streams,endians]

type
  FrameType = enum
    UDEF  = (uint8(0x00), "Undefined")
    SOF0  = (uint8(0xC0), "Baseline")
    SOF1  = (uint8(0xC1), "Extended sequential")
    SOF2  = (uint8(0xC2), "Progressive")
    SOF3  = (uint8(0xC3), "Lossless")
    DHT   = (uint8(0xC4), "Define Huffman Table")
    SOF5  = (uint8(0xC5), "Differential sequential")
    SOF6  = (uint8(0xC6), "Differential progressive")
    SOF7  = (uint8(0xC7), "Differential lossless")
    SOF9  = (uint8(0xC9), "Extended sequential, arithmetic coding")
    SOF10 = (uint8(0xCA), "Progressive, arithmetic coding")
    SOF11 = (uint8(0xCB), "Lossless, arithmetic coding")
    SOF13 = (uint8(0xCD), "Differential sequential, arithmetic coding")
    SOF14 = (uint8(0xCE), "Differential progressive, arithmetic coding")
    SOF15 = (uint8(0xCF), "Differential lossless, arithmetic coding")
    SOI   = (uint8(0xD8), "Start Of Image")
    EOI   = (uint8(0xD9), "End Of Image")
    SOS   = (uint8(0xDA), "Start Of Scan")
    DQT   = (uint8(0xDB), "Define Quantization Table")
    APP0  = (uint8(0xE0), "Application-specific marker 0")
    APP1  = (uint8(0xE1), "Application-specific marker 1")
    APP2  = (uint8(0xE2), "Application-specific marker 2")
    APP3  = (uint8(0xE3), "Application-specific marker 3")
    APP4  = (uint8(0xE4), "Application-specific marker 4")
    APP5  = (uint8(0xE5), "Application-specific marker 5")
    APP6  = (uint8(0xE6), "Application-specific marker 6")
    APP7  = (uint8(0xE7), "Application-specific marker 7")
    APP8  = (uint8(0xE8), "Application-specific marker 8")
    APP9  = (uint8(0xE9), "Application-specific marker 9")
    APP10 = (uint8(0xEA), "Application-specific marker 10")
    APP11 = (uint8(0xEB), "Application-specific marker 11")
    APP12 = (uint8(0xEC), "Application-specific marker 12")
    COM   = (uint8(0xFE), "COMment")
    FFB   = (uint8(0xFF), "First Frame Byte")

  Errors* = enum
    Invalid = (1, "File is not a valid JPEG")
    SizeNotFound = (2, "No valid frame found in the file")

proc read_int16( stream: FileStream ): int =
  var raw = stream.read_uint16()
  bigEndian16( result.addr, raw.addr )

proc get_size*( path: string ): (int,int) =
  let valid_start_of_frame_codes = [SOF0,SOF1,SOF2,SOF3,SOF5,SOF6,SOF7,SOF0,SOF9,SOF10,SOF11,SOF13,SOF14,SOF15]
  var last_byte:uint8 = FFB.ord

  var stream = new_file_stream( path, fm_read )
  defer: stream.close()

  # Return the invalid image code unless the magic bytes match
  onFailedAssert(msg):
    return (-1,1)
  doAssert stream.read_uint8() == FFB.ord
  doAssert stream.read_uint8() == SOI.ord

  # looping through the file
  while not stream.at_end:

    # skip to next FFB
    while stream.read_uint8() != FFB.ord:
      discard

    # and any following FFBs
    while last_byte == FFB.ord:
      last_byte = stream.read_uint8()

    let last_byte_is_start_of_frame_marker =
      valid_start_of_frame_codes.find( FrameType( last_byte )) != -1

    if last_byte_is_start_of_frame_marker:
      # read frame header
      discard stream.read_uint16() # frame size
      discard stream.read_uint8() # data precision
      let width = stream.read_int16()
      let height = stream.read_int16()

      # got what we need, return and ignore the rest of the file
      return ( width, height )
    else:
      # read curent frames size, frame size includes itself, so - two bytes
      let frame_size = stream.read_int16() - 2
      # reset last_byte for new search
      last_byte = FFB.ord
      # jump to start of next frame
      stream.set_position( stream.get_position() + frame_size )

  return (-1,2)

assert get_size("src/image_formats/examples/jonas.jpg") == (512,512)
assert get_size("src/image_formats/examples/jonas.jp2") == (-1,1)
