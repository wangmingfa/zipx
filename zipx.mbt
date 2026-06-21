///|
pub enum CompressionMethod {
  Stored
  Deflated
  Unsupported(UInt16)
}

///|
pub struct LocalFileHeader {
  signature : UInt
  version_needed : UInt16
  flags : UInt16
  compression_method : CompressionMethod
  last_mod_time : UInt16
  last_mod_date : UInt16
  crc32 : UInt
  compressed_size : UInt
  uncompressed_size : UInt
  filename_length : UInt16
  extra_field_length : UInt16
  filename : String
  extra_field : Bytes
}

///|
pub struct CentralDirectoryFileHeader {
  signature : UInt
  version_made_by : UInt16
  version_needed : UInt16
  flags : UInt16
  compression_method : CompressionMethod
  last_mod_time : UInt16
  last_mod_date : UInt16
  crc32 : UInt
  compressed_size : UInt
  uncompressed_size : UInt
  filename_length : UInt16
  extra_field_length : UInt16
  comment_length : UInt16
  disk_number_start : UInt16
  internal_file_attrs : UInt16
  external_file_attrs : UInt
  local_header_offset : UInt
  filename : String
  extra_field : Bytes
  comment : String
}

///|
pub struct EndOfCentralDirectoryRecord {
  signature : UInt
  disk_number : UInt16
  cd_start_disk : UInt16
  cd_entries_on_disk : UInt16
  cd_entries_total : UInt16
  cd_size : UInt
  cd_offset : UInt
  comment_length : UInt16
  comment : String
}

///|
pub struct BitReader {
  data : Bytes
  mut pos : Int
  mut bit_pos : Int
}

///|
fn BitReader::new(data : Bytes) -> BitReader {
  BitReader::{ data, pos: 0, bit_pos: 0 }
}

///|
fn BitReader::read_bits(self : BitReader, n : Int) -> UInt {
  if n <= 0 {
    0
  } else {
    let mut result : UInt = 0
    let mut remaining : Int = n
    while remaining > 0 {
      if self.pos >= self.data.length() {
        return result
      } else {
        let byte : UInt = self.data[self.pos].to_uint()
        let bits_in_byte : Int = 8 - self.bit_pos
        let take : Int = if remaining < bits_in_byte {
          remaining
        } else {
          bits_in_byte
        }
        let mask : UInt = ((1 << take) - 1) << (bits_in_byte - take)
        result = (result << take) | ((byte & mask) >> (bits_in_byte - take))
        self.bit_pos = self.bit_pos + take
        if self.bit_pos >= 8 {
          self.bit_pos = 0
          self.pos = self.pos + 1
        }
        remaining = remaining - take
      }
    }
    result
  }
}

///|
fn BitReader::align_to_byte(self : BitReader) -> Unit {
  if self.bit_pos != 0 {
    self.bit_pos = 0
    self.pos = self.pos + 1
  }
}

///|
fn BitReader::read_bytes(self : BitReader, n : Int) -> Bytes {
  let start : Int = self.pos
  let end : Int = if start + n <= self.data.length() {
    start + n
  } else {
    self.data.length()
  }
  self.pos = end
  match self.data.get_view(start~, end~) {
    None => Bytes::new(0)
    Some(v) => v.to_owned()
  }
}

///|
pub struct HuffmanTree {
  codes : Array[Int]
  lengths : Array[Int]
  max_code_len : Int
}

///|
fn HuffmanTree::new(code_lengths : Array[Int], max_code : Int) -> HuffmanTree {
  let len : Int = max_code + 1
  let codes : Array[Int] = Array::make(len, 0)
  let lengths : Array[Int] = Array::make(len, 0)

  let mut code : Int = 0
  let prev_len : Int = code_lengths[0]

  for i in 0..<len {
    let current_len : Int = code_lengths[i]
    if current_len != 0 {
      if i > 0 && current_len < prev_len {
        code = code << (prev_len - current_len)
      } else if i > 0 && current_len > prev_len {
        code = code + 1
        code = code << (current_len - prev_len)
      } else if i > 0 {
        code = code + 1
      }
      codes[i] = code
      lengths[i] = current_len
    }
  }

  let mut max_code_len : Int = 0
  for i in 0..<len {
    if lengths[i] > max_code_len {
      max_code_len = lengths[i]
    }
  }

  HuffmanTree::{ codes, lengths, max_code_len }
}

///|
fn HuffmanTree::decode(self : HuffmanTree, br : BitReader) -> Int {
  let mut bits : UInt = 0
  let mut len : Int = 0

  while len < self.max_code_len {
    bits = (bits << 1) | br.read_bits(1)
    len = len + 1

    for i in 0..<self.codes.length() {
      if self.lengths[i] == len && self.codes[i] == bits.reinterpret_as_int() {
        return i
      }
    }
  }

  -1
}

///|
fn inflate_block(br : BitReader, result : Array[Byte]) -> Bool {
  let bfinal : Int = br.read_bits(1).reinterpret_as_int()
  let btype : Int = br.read_bits(2).reinterpret_as_int()

  if btype == 0 {
    br.align_to_byte()
    let len : UInt16 = br.read_bits(16).to_uint16()
    let nlen : UInt16 = br.read_bits(16).to_uint16()
    if (len ^ 0xFFFF) != nlen {
      false
    } else {
      let data : Bytes = br.read_bytes(len.to_int())
      for b in data.iter() {
        result.push(b)
      }
      bfinal != 0
    }
  } else if btype == 1 || btype == 2 {
    let literal_len_count : Int = if btype == 1 { 288 } else { 286 }
    let dist_count : Int = if btype == 1 { 32 } else { 30 }

    let literal_code_lengths : Array[Int] = Array::make(literal_len_count, 0)
    let dist_code_lengths : Array[Int] = Array::make(dist_count, 0)

    if btype == 2 {
      let hlit : Int = br.read_bits(5).reinterpret_as_int() + 257
      let hdist : Int = br.read_bits(5).reinterpret_as_int() + 1
      let hclen : Int = br.read_bits(4).reinterpret_as_int() + 4

      let code_length_code_lengths : Array[Int] = Array::make(19, 0)
      let order : Array[Int] = [
        16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
      ]

      for i in 0..<hclen {
        code_length_code_lengths[order[i]] = br
          .read_bits(3)
          .reinterpret_as_int()
      }

      let code_length_tree : HuffmanTree = HuffmanTree::new(
        code_length_code_lengths, 18,
      )

      let mut pos : Int = 0
      while pos < hlit + hdist {
        let code : Int = code_length_tree.decode(br)
        if code == -1 {
          return false
        } else if code < 16 {
          if pos < hlit {
            literal_code_lengths[pos] = code
          } else {
            dist_code_lengths[pos - hlit] = code
          }
          pos = pos + 1
        } else if code == 16 {
          let repeat : Int = 3 + br.read_bits(2).reinterpret_as_int()
          let prev : Int = if pos > 0 {
            if pos <= hlit {
              literal_code_lengths[pos - 1]
            } else {
              dist_code_lengths[pos - hlit - 1]
            }
          } else {
            0
          }
          for _ in 0..<repeat {
            if pos < hlit {
              literal_code_lengths[pos] = prev
            } else {
              dist_code_lengths[pos - hlit] = prev
            }
            pos = pos + 1
          }
        } else if code == 17 {
          let repeat : Int = 3 + br.read_bits(3).reinterpret_as_int()
          for _ in 0..<repeat {
            if pos < hlit {
              literal_code_lengths[pos] = 0
            } else {
              dist_code_lengths[pos - hlit] = 0
            }
            pos = pos + 1
          }
        } else if code == 18 {
          let repeat : Int = 11 + br.read_bits(7).reinterpret_as_int()
          for _ in 0..<repeat {
            if pos < hlit {
              literal_code_lengths[pos] = 0
            } else {
              dist_code_lengths[pos - hlit] = 0
            }
            pos = pos + 1
          }
        }
      }
    } else {
      for i in 0..<288 {
        if i >= 0 && i <= 143 {
          literal_code_lengths[i] = 8
        } else if i >= 144 && i <= 255 {
          literal_code_lengths[i] = 9
        } else if i >= 256 && i <= 279 {
          literal_code_lengths[i] = 7
        } else {
          literal_code_lengths[i] = 8
        }
      }
      for i in 0..<32 {
        dist_code_lengths[i] = 5
      }
    }

    let literal_tree : HuffmanTree = HuffmanTree::new(
      literal_code_lengths,
      literal_len_count - 1,
    )
    let dist_tree : HuffmanTree = HuffmanTree::new(
      dist_code_lengths,
      dist_count - 1,
    )

    let keep_going : Bool = true
    while keep_going {
      let code : Int = literal_tree.decode(br)
      if code == -1 {
        return false
      } else if code == 256 {
        return bfinal != 0
      } else if code < 256 {
        result.push(code.to_byte())
      } else {
        let len_val : Int = code - 257
        let base_len : Int = if len_val < 4 {
          len_val + 3
        } else if len_val < 28 {
          let extra_bits : Int = (len_val - 2) / 4
          let offset : Int = (len_val - 2) % 4 * (1 << extra_bits)
          offset +
          3 +
          (1 << extra_bits) +
          br.read_bits(extra_bits).reinterpret_as_int()
        } else {
          let extra_bits : Int = 1 + br.read_bits(2).reinterpret_as_int()
          138 + br.read_bits(extra_bits).reinterpret_as_int()
        }

        let dist_code : Int = dist_tree.decode(br)
        if dist_code == -1 {
          return false
        } else {
          let dist : Int = if dist_code < 4 {
            dist_code + 1
          } else {
            let extra_bits : Int = dist_code / 2 - 1
            let offset : Int = (dist_code % 2) << extra_bits
            offset +
            1 +
            (1 << extra_bits) +
            br.read_bits(extra_bits).reinterpret_as_int()
          }

          let start : Int = result.length() - dist
          for i in 0..<base_len {
            let idx : Int = start + i
            if idx >= 0 && idx < result.length() {
              result.push(result[idx])
            }
          }
        }
      }
    }
    true
  } else {
    false
  }
}

///|
pub fn inflate(data : Bytes) -> Bytes {
  let br : BitReader = BitReader::new(data)
  let result : Array[Byte] = Array::new()

  while br.pos < br.data.length() {
    let done : Bool = inflate_block(br, result)
    if done {
      break
    }
  }

  Bytes::from_iter(result.iter())
}

///|
fn read_u16(data : Bytes, offset : Int) -> UInt16 {
  if offset + 1 >= data.length() {
    0
  } else {
    data[offset].to_uint16() | (data[offset + 1].to_uint16() << 8)
  }
}

///|
fn read_u32(data : Bytes, offset : Int) -> UInt {
  if offset + 4 > data.length() {
    0
  } else {
    data[offset].to_uint() |
    (data[offset + 1].to_uint() << 8) |
    (data[offset + 2].to_uint() << 16) |
    (data[offset + 3].to_uint() << 24)
  }
}

///|
fn parse_compression_method(method_val : UInt16) -> CompressionMethod {
  match method_val {
    0 => CompressionMethod::Stored
    8 => CompressionMethod::Deflated
    m => CompressionMethod::Unsupported(m)
  }
}

///|
fn parse_local_file_header(data : Bytes, offset : Int) -> LocalFileHeader? {
  if offset + 30 > data.length() {
    None
  } else {
    let signature : UInt = read_u32(data, offset)
    if signature != 0x04034B50 {
      None
    } else {
      let version_needed : UInt16 = read_u16(data, offset + 4)
      let flags : UInt16 = read_u16(data, offset + 6)
      let compression_method : CompressionMethod = parse_compression_method(
        read_u16(data, offset + 8),
      )
      let last_mod_time : UInt16 = read_u16(data, offset + 10)
      let last_mod_date : UInt16 = read_u16(data, offset + 12)
      let crc32 : UInt = read_u32(data, offset + 14)
      let compressed_size : UInt = read_u32(data, offset + 18)
      let uncompressed_size : UInt = read_u32(data, offset + 22)
      let filename_length : UInt16 = read_u16(data, offset + 26)
      let extra_field_length : UInt16 = read_u16(data, offset + 28)

      let header_size : Int = 30 +
        filename_length.to_int() +
        extra_field_length.to_int()
      if offset + header_size > data.length() {
        None
      } else {
        let filename_view = data.get_view(
          start=offset + 30,
          end=offset + 30 + filename_length.to_int(),
        )
        let extra_field_view = data.get_view(
          start=offset + 30 + filename_length.to_int(),
          end=offset + header_size,
        )

        match (filename_view, extra_field_view) {
          (Some(fv), Some(ev)) =>
            Some(LocalFileHeader::{
              signature,
              version_needed,
              flags,
              compression_method,
              last_mod_time,
              last_mod_date,
              crc32,
              compressed_size,
              uncompressed_size,
              filename_length,
              extra_field_length,
              filename: @utf8.decode_lossy(fv),
              extra_field: ev.to_owned(),
            })
          _ => None
        }
      }
    }
  }
}

///|
fn parse_central_directory_file_header(
  data : Bytes,
  offset : Int,
) -> CentralDirectoryFileHeader? {
  if offset + 46 > data.length() {
    None
  } else {
    let signature : UInt = read_u32(data, offset)
    if signature != 0x02014B50 {
      None
    } else {
      let version_made_by : UInt16 = read_u16(data, offset + 4)
      let version_needed : UInt16 = read_u16(data, offset + 6)
      let flags : UInt16 = read_u16(data, offset + 8)
      let compression_method : CompressionMethod = parse_compression_method(
        read_u16(data, offset + 10),
      )
      let last_mod_time : UInt16 = read_u16(data, offset + 12)
      let last_mod_date : UInt16 = read_u16(data, offset + 14)
      let crc32 : UInt = read_u32(data, offset + 16)
      let compressed_size : UInt = read_u32(data, offset + 20)
      let uncompressed_size : UInt = read_u32(data, offset + 24)
      let filename_length : UInt16 = read_u16(data, offset + 28)
      let extra_field_length : UInt16 = read_u16(data, offset + 30)
      let comment_length : UInt16 = read_u16(data, offset + 32)
      let disk_number_start : UInt16 = read_u16(data, offset + 34)
      let internal_file_attrs : UInt16 = read_u16(data, offset + 36)
      let external_file_attrs : UInt = read_u32(data, offset + 38)
      let local_header_offset : UInt = read_u32(data, offset + 42)

      let header_size : Int = 46 +
        filename_length.to_int() +
        extra_field_length.to_int() +
        comment_length.to_int()
      if offset + header_size > data.length() {
        None
      } else {
        let filename_view = data.get_view(
          start=offset + 46,
          end=offset + 46 + filename_length.to_int(),
        )
        let extra_field_view = data.get_view(
          start=offset + 46 + filename_length.to_int(),
          end=offset +
            46 +
            filename_length.to_int() +
            extra_field_length.to_int(),
        )
        let comment_view = data.get_view(
          start=offset +
            46 +
            filename_length.to_int() +
            extra_field_length.to_int(),
          end=offset + header_size,
        )

        match (filename_view, extra_field_view, comment_view) {
          (Some(fv), Some(ev), Some(cv)) =>
            Some(CentralDirectoryFileHeader::{
              signature,
              version_made_by,
              version_needed,
              flags,
              compression_method,
              last_mod_time,
              last_mod_date,
              crc32,
              compressed_size,
              uncompressed_size,
              filename_length,
              extra_field_length,
              comment_length,
              disk_number_start,
              internal_file_attrs,
              external_file_attrs,
              local_header_offset,
              filename: @utf8.decode_lossy(fv),
              extra_field: ev.to_owned(),
              comment: @utf8.decode_lossy(cv),
            })
          _ => None
        }
      }
    }
  }
}

///|
fn parse_end_of_central_directory_record(
  data : Bytes,
) -> EndOfCentralDirectoryRecord? {
  let len : Int = data.length()

  // 结束记录最小长度是 22 字节
  if len < 22 {
    return None
  }

  // 从文件末尾向前搜索，最多搜索 65536 字节（ZIP 规范允许的最大注释长度）
  let mut offset : Int = if len > 65536 + 22 { len - 65536 - 22 } else { 0 }
  while offset <= len - 22 {
    if read_u32(data, offset) == 0x06054B50 {
      let comment_length : UInt16 = read_u16(data, offset + 20)
      // 验证注释长度是否正确（结束记录应该在文件末尾）
      if offset + 22 + comment_length.to_int() == len {
        let signature : UInt = read_u32(data, offset)
        let disk_number : UInt16 = read_u16(data, offset + 4)
        let cd_start_disk : UInt16 = read_u16(data, offset + 6)
        let cd_entries_on_disk : UInt16 = read_u16(data, offset + 8)
        let cd_entries_total : UInt16 = read_u16(data, offset + 10)
        let cd_size : UInt = read_u32(data, offset + 12)
        let cd_offset : UInt = read_u32(data, offset + 16)
        let comment_view = data.get_view(
          start=offset + 22,
          end=offset + 22 + comment_length.to_int(),
        )

        match comment_view {
          Some(cv) =>
            return Some(EndOfCentralDirectoryRecord::{
              signature,
              disk_number,
              cd_start_disk,
              cd_entries_on_disk,
              cd_entries_total,
              cd_size,
              cd_offset,
              comment_length,
              comment: @utf8.decode_lossy(cv),
            })
          None => ()
        }
      }
    }
    offset = offset + 1
  }

  None
}

///|
pub struct ZipFile {
  data : Bytes
  eocd : EndOfCentralDirectoryRecord
  cd_entries : Array[CentralDirectoryFileHeader]
}

///|
pub fn zip_file_open(data : Bytes) -> ZipFile raise {
  match parse_end_of_central_directory_record(data) {
    None => fail("Cannot find end of central directory record")
    Some(e) => {
      let len : Int = e.cd_entries_total.to_int()
      // 创建一个空的数组，稍后填充
      let cd_entries : Array[CentralDirectoryFileHeader] = []

      let mut offset : Int = e.cd_offset.reinterpret_as_int()
      let end_offset : Int = offset + e.cd_size.reinterpret_as_int()

      while offset < end_offset {
        match parse_central_directory_file_header(data, offset) {
          None => break
          Some(entry) => {
            cd_entries.push(entry)
            offset = offset +
              46 +
              entry.filename_length.to_int() +
              entry.extra_field_length.to_int() +
              entry.comment_length.to_int()
          }
        }
      }

      if cd_entries.length() != len {
        fail("Central directory entry count mismatch")
      }

      ZipFile::{ data, eocd: e, cd_entries }
    }
  }
}

///|
pub fn zip_file_extract(zip : ZipFile, index : Int) -> (String, Bytes) raise {
  if index < 0 || index >= zip.cd_entries.length() {
    fail("Invalid file index")
  }

  let entry : CentralDirectoryFileHeader = zip.cd_entries[index]
  match
    parse_local_file_header(
      zip.data,
      entry.local_header_offset.reinterpret_as_int(),
    ) {
    None => fail("Cannot find local file header")
    Some(h) => {
      let data_start : Int = entry.local_header_offset.reinterpret_as_int() +
        30 +
        h.filename_length.to_int() +
        h.extra_field_length.to_int()
      let compressed_data_view = zip.data.get_view(
        start=data_start,
        end=data_start + h.compressed_size.reinterpret_as_int(),
      )

      match compressed_data_view {
        None => fail("Cannot read compressed data")
        Some(cdv) => {
          let compressed_data : Bytes = cdv.to_owned()
          match h.compression_method {
            CompressionMethod::Stored => (entry.filename, compressed_data)
            CompressionMethod::Deflated =>
              (entry.filename, inflate(compressed_data))
            CompressionMethod::Unsupported(m) =>
              fail("Unsupported compression method: " + m.to_int().to_string())
          }
        }
      }
    }
  }
}

///|
pub fn zip_file_list(zip : ZipFile) -> Array[String] {
  let len : Int = zip.cd_entries.length()
  let names : Array[String] = Array::make(len, "")

  for i in 0..<len {
    names[i] = zip.cd_entries[i].filename
  }

  names
}

///|
pub fn unzip_file(data : Bytes) -> Array[(String, Bytes)] raise {
  let zip : ZipFile = zip_file_open(data)
  let len : Int = zip.cd_entries.length()
  let result : Array[(String, Bytes)] = Array::make(len, ("", Bytes::new(0)))

  for i in 0..<len {
    result[i] = zip_file_extract(zip, i)
  }

  result
}
