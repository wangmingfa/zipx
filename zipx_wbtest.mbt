///|
test "read_u16 little endian" {
  let bytes : Array[Byte] = Array::make(2, 0)
  let v1 : UInt = 0x34
  let v2 : UInt = 0x12
  bytes[0] = v1.to_byte()
  bytes[1] = v2.to_byte()
  let data : Bytes = Bytes::from_iter(bytes.iter())
  assert_eq(read_u16(data, 0), 0x1234)
}

///|
test "read_u32 little endian" {
  let bytes : Array[Byte] = Array::make(4, 0)
  let v1 : UInt = 0x78
  let v2 : UInt = 0x56
  let v3 : UInt = 0x34
  let v4 : UInt = 0x12
  bytes[0] = v1.to_byte()
  bytes[1] = v2.to_byte()
  bytes[2] = v3.to_byte()
  bytes[3] = v4.to_byte()
  let data : Bytes = Bytes::from_iter(bytes.iter())
  assert_eq(read_u32(data, 0), 0x12345678)
}

///|
test "parse_compression_method" {
  assert_true(parse_compression_method(0) is CompressionMethod::Stored)
  assert_true(parse_compression_method(8) is CompressionMethod::Deflated)
  assert_true(parse_compression_method(1) is CompressionMethod::Unsupported(1))
}
