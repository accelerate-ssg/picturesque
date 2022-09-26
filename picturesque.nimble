# Package

version       = "0.1.0"
author        = "Jonas Schubert Erlandsson"
description   = "Tool to extract image information from HTML, CSS and JS files."
license       = "MIT"
srcDir        = "src"
bin           = @["picturesque"]


# Dependencies

requires "nim >= 1.4.8"
requires "regex >= 0.19.0"
requires "dimage >= 0.1.0"
requires "cligen >= 1.5.28"
requires "fusion >= 1.1"
