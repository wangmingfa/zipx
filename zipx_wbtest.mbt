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

///|
test "BitReader read single bit" {
  let data = Bytes::from_array([0b00000001])
  let br = BitReader::new(data)
  assert_eq(br.read_bits(1), 1)
  assert_eq(br.read_bits(1), 0)
  assert_eq(br.read_bits(1), 0)
  assert_eq(br.read_bits(1), 0)
  assert_eq(br.read_bits(1), 0)
  assert_eq(br.read_bits(1), 0)
  assert_eq(br.read_bits(1), 0)
  assert_eq(br.read_bits(1), 0)
}

///|
test "BitReader read multiple bits" {
  let data = Bytes::from_array([0b11010010])
  let br = BitReader::new(data)
  assert_eq(br.read_bits(3), 0b010)
  assert_eq(br.read_bits(5), 0b11010)
}

///|
test "BitReader read across bytes" {
  let data = Bytes::from_array([0b11110000, 0b00001111])
  let br = BitReader::new(data)
  assert_eq(br.read_bits(6), 0b110000)
  assert_eq(br.read_bits(6), 0b111111)
  assert_eq(br.read_bits(4), 0b0000)
}

///|
test "BitReader align_to_byte" {
  let data = Bytes::from_array([0b11010010, 0xFF])
  let br = BitReader::new(data)
  assert_eq(br.read_bits(3), 0b010)
  br.align_to_byte()
  assert_eq(br.pos, 1)
  assert_eq(br.bit_pos, 0)
}

///|
test "inflate stored block" {
  let data = Bytes::from_array([
    0x01, 0x05, 0x00, 0xfa, 0xff, 0x48, 0x65, 0x6c, 0x6c, 0x6f,
  ])
  let result = inflate(data)
  assert_eq(result, b"Hello")
}

///|
test "inflate stored block multiple blocks" {
  let data = Bytes::from_array([
    0x00, 0x03, 0x00, 0xfc, 0xff, 0x48, 0x65, 0x6c, 0x01, 0x02, 0x00, 0xfd, 0xff,
    0x6c, 0x6f,
  ])
  let result = inflate(data)
  assert_eq(result, b"Hello")
}

///|
test "inflate fixed huffman simple" {
  let data = Bytes::from_array([0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00])
  let result = inflate(data)
  assert_eq(result, b"Hello")
}

///|
test "CompressionMethod variants" {
  let stored = CompressionMethod::Stored
  assert_true(stored is CompressionMethod::Stored)
  let deflated = CompressionMethod::Deflated
  assert_true(deflated is CompressionMethod::Deflated)
  let unsupported = CompressionMethod::Unsupported(99)
  assert_true(unsupported is CompressionMethod::Unsupported(99))
}
