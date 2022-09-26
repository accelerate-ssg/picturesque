import std/[uri,strutils,sequtils]
import fusion/matching

import ../image

{.experimental: "caseStmtMacros".}

type
  SrcsetParseError* = object of ValueError

proc build_resolution_from_srcset_string*( srcset_string: string ): Resolution =
  result = init_resolution( original_string = srcset_string )

  let directives = srcset_string.strip.split( ' ' ).map(proc (s :string): string = s.strip)

  try:
    assert( directives.len == 2 )
  except:
    raise newException(SrcsetParseError, "Requires URI and width or pixel density descriptor")

  try:
    assert $parse_uri( directives[0] ) == directives[0]
  except:
    raise newException(SrcsetParseError, "Invalid URI")

  case directives:
    of [ _ ]: # Just a URI, no size info
        raise newException(SrcsetParseError, "Missing size directive")
    of [ _, @width.ends_with('w') ]:
      result.kind = Width
      result.value = width[0..^2].parse_float
    of [ _, @multiplier.ends_with('x') ]:
      result.kind = Multiplier
      result.value = multiplier[0..^2].parse_float
    else:
      raise newException(SrcsetParseError, "Too many directives")
