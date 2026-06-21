///|
#cfg(target="native")
async test "unzip real zip file" {
  // 先用系统命令创建测试 zip 文件
  let test_dir = ".temp"
  let test_file = "\{test_dir}/test.txt"
  let zip_file = "\{test_dir}/test.zip"

  // 创建测试目录和文件
  @fs.mkdir(test_dir, permission=0o755)

  // 写入测试内容
  let content : Bytes = b"Hello, MoonBit ZIP test!\nThis is a test file for unzip.\n"
  @fs.write_file(test_file, content, create_mode=CreateOrTruncate)

  // 使用系统 zip 命令创建压缩包
  let exit_code = @process.run("zip", ["test.zip", "test.txt"], cwd=test_dir)
  assert_eq(exit_code, 0)

  // 读取 zip 文件
  let zip_data = @fs.read_file(zip_file).binary()

  // 使用我们的 unzip_file 函数解压
  let extracted = unzip_file(zip_data)

  // 验证解压结果
  assert_eq(extracted.length(), 1)
  let (filename, data) = extracted[0]
  assert_eq(filename, "test.txt")
  assert_eq(data, content)

  // 清理测试文件
  @fs.remove(zip_file)
  @fs.remove(test_file)
  @fs.rmdir(test_dir)
}
