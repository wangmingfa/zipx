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
        // 检查输出目录是否存在
        let exists = @fs.exists(output_dir)
        if exists {
          // 检查是否是目录
          try {
            let kind = @fs.kind(output_dir)
            match kind {
              @fs.FileKind::Directory => ()
              _ => {
                println("Error: " + output_dir + " is not a directory")
                return
              }
            }
          } catch {
            _ => {
              println("Error: " + output_dir + " is not a directory")
              return
            }
          }
        } else {
          // 创建目录
          @fs.mkdir(output_dir, permission=0o755, recursive=true)
        }

        // 读取 zip 文件
        let zip_data = @fs.read_file(zip_path).binary()

        // 使用 zipx 包解压
        let extracted = @zipx.unzip_file(zip_data)

        // 写入解压的文件
        for entry in extracted.iter() {
          let (filename, data) = entry
          let output_path = output_dir + "/" + filename

          // 检查是否是目录（以 / 结尾）
          if filename.has_suffix("/") {
            // 创建目录
            try {
              @fs.mkdir(output_path, permission=0o755, recursive=true)
              println("  Created dir: " + filename)
            } catch {
              _ => println("  Skipped dir: " + filename)
            }
          } else {
            // 写入文件
            try {
              @fs.write_file(output_path, data, create_mode=CreateOrTruncate)
              println("  Extracted: " + filename)
            } catch {
              e => println("  Failed: " + filename + " (" + e.to_string() + ")")
            }
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
