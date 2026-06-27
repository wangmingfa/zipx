// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "wangmingfa/zipx"

version = "0.1.2"

readme = "README.mbt.md"

repository = "https://github.com/wangmingfa/zipx"

license = "Apache-2.0"

keywords = [ ]

description = "A pure MoonBit implementation of ZIP archive extraction"

import {
  "moonbitlang/async@0.19.4",
}

preferred_target = "native"
