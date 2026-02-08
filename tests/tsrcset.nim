## Tests for srcset parsing (existing functionality, expanded coverage)

import std/[unittest, options]

import picturesque/image
import picturesque/builders/resolution
import picturesque/builders/focus


suite "srcset: width descriptor parsing":
  test "parses width descriptor like '300w'":
    let res = build_resolution_from_srcset_string("image.jpg 300w")
    check res.kind == Width
    check res.value == 300.0

  test "parses large width descriptor":
    let res = build_resolution_from_srcset_string("image.jpg 1920w")
    check res.kind == Width
    check res.value == 1920.0

  test "rejects missing descriptor":
    expect SrcsetParseError:
      discard build_resolution_from_srcset_string("image.jpg")

  test "rejects invalid descriptor suffix":
    expect SrcsetParseError:
      discard build_resolution_from_srcset_string("image.jpg 300q")


suite "srcset: multiplier descriptor parsing":
  test "parses integer multiplier like '2x'":
    let res = build_resolution_from_srcset_string("image.jpg 2x")
    check res.kind == Multiplier
    check res.value == 2.0

  test "parses fractional multiplier like '1.5x'":
    let res = build_resolution_from_srcset_string("image.jpg 1.5x")
    check res.kind == Multiplier
    check res.value == 1.5

  test "parses 1x multiplier":
    let res = build_resolution_from_srcset_string("image.jpg 1x")
    check res.kind == Multiplier
    check res.value == 1.0


suite "srcset: whitespace handling":
  test "handles leading whitespace":
    let res = build_resolution_from_srcset_string("  image.jpg 300w")
    check res.kind == Width
    check res.value == 300.0

  test "handles trailing whitespace":
    let res = build_resolution_from_srcset_string("image.jpg 300w  ")
    check res.kind == Width
    check res.value == 300.0


suite "focus point: percentage values":
  test "parses percentage focus point":
    let focus = build_focus_from_data_attribute("25% 75%")
    check focus.isSome
    let f = focus.get()
    check f.x == 25.0
    check f.y == 75.0
    check f.unit == Percent

  test "parses 50% 50% center focus":
    let focus = build_focus_from_data_attribute("50% 50%")
    check focus.isSome
    let f = focus.get()
    check f.x == 50.0
    check f.y == 50.0

  test "parses decimal percentages":
    let focus = build_focus_from_data_attribute("33.3% 66.7%")
    check focus.isSome
    let f = focus.get()
    check f.x == 33.3
    check f.y == 66.7


suite "focus point: pixel values":
  test "parses pixel focus point":
    let focus = build_focus_from_data_attribute("100px 200px")
    check focus.isSome
    let f = focus.get()
    check f.x == 100.0
    check f.y == 200.0
    check f.unit == Pixels


suite "focus point: edge cases":
  test "returns none for empty string":
    let focus = build_focus_from_data_attribute("")
    check focus.isNone

  test "rejects mixed units":
    expect FocusParseError:
      discard build_focus_from_data_attribute("100px 50%")

  test "rejects missing units":
    expect FocusParseError:
      discard build_focus_from_data_attribute("100 200")
