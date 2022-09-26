import std/[strutils,sequtils,options]
import fusion/matching

import ../image

{.experimental: "caseStmtMacros".}

type
  FocusParseError* = object of ValueError

proc build_focus_from_data_attribute*( data_focus: string ): Option[Focus] =
  if data_focus == "":
    return none(Focus)

  let
    focus_string = data_focus.strip
    split = focus_string.split(' ', 2).map( proc (s:string):string = s.strip )

  var
    x, y = 50.0
    unit = Units.Unknown

  case split:
    of [ @x_string.ends_with("px"), @y_string.ends_with("px") ]:
      x = parse_float( x_string[0..^3] )
      y = parse_float( y_string[0..^3] )
      unit = Units.Pixels
    of [ @x_string.ends_with("%"), @y_string.ends_with("%") ]:
      x = parse_float( x_string[0..^2] )
      y = parse_float( y_string[0..^2] )
      unit = Units.Percent
    else:
      raise newException(FocusParseError, "Invalid data-focus attribute.\n   Expects int or float values separated with space.\n   '%' or 'px' unit are allowed.\n   Both values have to have the same unit")

  some(init_focus( x, y, unit ))
