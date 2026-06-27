///|
async fn main {
  let args : Array[String] = @env.args()

  if args.length() < 2 {
    println("Usage: zipx <command> [options]")
    println("Commands:")
    println("  unzip <file> [output_dir]  Extract files from a ZIP archive")
    println("  list <file>                List files in a ZIP archive")
    return
  }

  let cmd : String = args[1]

  match cmd {
    "unzip" => {
      if args.length() < 3 {
        println("Usage: zipx unzip <file> [output_dir]")
        return
      }
      let zip_path : String = args[2]
      let output_dir : String = if args.length() > 3 { args[3] } else { "." }

      println("Unzipping: " + zip_path + " to " + output_dir)

      try {
        let extracted = @zipx.unzip_file_path(zip_path, output_dir~)

        for entry in extracted.iter() {
          let (filename, _) = entry
          if filename.has_suffix("/") {
            println("  Created dir: " + filename)
          } else {
            println("  Extracted: " + filename)
          }
        }

        println("Done.")
      } catch {
        e => println("Error: " + e.to_string())
      }
    }
    "list" => {
      if args.length() < 3 {
        println("Usage: zipx list <file>")
        return
      }
      let zip_path : String = args[2]

      try {
        // 读取 zip 文件
        let zip_data = @fs.read_file(zip_path).binary()

        // 使用 zipx 包列出文件
        let zip = @zipx.zip_file_open(zip_data)
        let files = @zipx.zip_file_list(zip)

        println("Files in " + zip_path + ":")
        for filename in files.iter() {
          println("  " + filename)
        }
      } catch {
        e => println("Error: " + e.to_string())
      }
    }
    _ => println("Unknown command: " + cmd)
  }
}
