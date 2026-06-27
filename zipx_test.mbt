///|
#cfg(target="native")
async test "unzip real zip file" {
  let test_dir = ".temp"
  let test_file = "\{test_dir}/test.txt"
  let zip_file = "\{test_dir}/test.zip"

  guard @fs.exists(test_dir) else {
    @fs.mkdir(test_dir, permission=0o755, recursive=true)
  }

  let content : Bytes = b"Hello, MoonBit ZIP test!\nThis is a test file for unzip.\n"
  @fs.write_file(test_file, content, create_mode=CreateOrTruncate)

  let exit_code = @process.run("zip", ["test.zip", "test.txt"], cwd=test_dir)
  assert_eq(exit_code, 0)

  let zip_data = @fs.read_file(zip_file).binary()

  let extracted = unzip_file(zip_data)

  assert_eq(extracted.length(), 1)
  let (filename, data) = extracted[0]
  assert_eq(filename, "test.txt")
  assert_eq(data, content)

  @fs.remove(zip_file)
  @fs.remove(test_file)
  @fs.rmdir(test_dir)
}
