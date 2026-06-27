/// # zipx - Pure MoonBit ZIP Extraction Library
///
/// A pure MoonBit implementation of ZIP archive extraction with no FFI
/// and no system command dependencies.
///
/// ## Basic Usage
///
/// Extract all files from a ZIP archive:
///
/// ```moonbit nocheck
/// let zip_data = @fs.read_file("archive.zip").binary()
/// let files = unzip_file(zip_data)
/// for (name, data) in files.iter() {
///   println("Extracted: " + name)
/// }
/// ```
///
/// List files without extracting:
///
/// ```moonbit nocheck
/// let zip = zip_file_open(zip_data)
/// let names = zip_file_list(zip)
/// for name in names.iter() {
///   println(name)
/// }
/// ```

///|
/// ## Compression Method
///
/// The compression method used in a ZIP file entry.
///
/// - `Stored`: No compression (stored as-is)
/// - `Deflated`: DEFLATE compression
/// - `Unsupported(UInt16)`: Unsupported compression method
pub enum CompressionMethod {
  Stored
  Deflated
  Unsupported(UInt16)
}

///|
/// ## Central Directory File Header
///
/// Represents a file entry in the ZIP archive's central directory.
/// Contains metadata about each file in the archive.
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
/// ## ZipFile
///
/// Represents an open ZIP archive file.
/// Use `zip_file_open` to create an instance.
pub struct ZipFile {
  data : Bytes
  eocd : EndOfCentralDirectoryRecord
  cd_entries : Array[CentralDirectoryFileHeader]
}

///|
/// ## Open a ZIP File
///
/// Opens a ZIP archive from byte data and returns a `ZipFile` handle.
///
/// # Parameters
/// - `data`: The raw bytes of the ZIP file
///
/// # Returns
/// A `ZipFile` handle for reading the archive
///
/// # Throws
/// - If the end of central directory record cannot be found
/// - If the central directory is corrupted
///
/// # Example
/// ```moonbit nocheck
/// let zip = zip_file_open(zip_data)
///
/// let files = zip_file_list(zip)
/// ```
pub fn zip_file_open(data : Bytes) -> ZipFile raise {
  match parse_end_of_central_directory_record(data) {
    None => fail("Cannot find end of central directory record")
    Some(e) => {
      let len : Int = e.cd_entries_total.to_int()
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
/// ## Extract a Single File
///
/// Extracts a single file from the ZIP archive by index.
///
/// # Parameters
/// - `zip`: The open ZIP file handle
/// - `index`: The zero-based index of the file to extract
///
/// # Returns
/// A tuple of `(filename, data)` containing the extracted file
///
/// # Throws
/// - If the index is out of bounds
/// - If the local file header cannot be found
/// - If decompression fails
///
/// # Example
/// ```moonbit nocheck
/// let (filename, data) = zip_file_extract(zip, 0)
/// ```
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
/// ## List Files in ZIP
///
/// Returns a list of all filenames in the ZIP archive.
///
/// # Parameters
/// - `zip`: The open ZIP file handle
///
/// # Returns
/// An array of filenames in the order they appear in the archive
///
/// # Example
/// ```moonbit nocheck
/// let files = zip_file_list(zip)
/// for filename in files.iter() {
///   println(filename)
/// }
/// ```
pub fn zip_file_list(zip : ZipFile) -> Array[String] {
  let len : Int = zip.cd_entries.length()
  let names : Array[String] = Array::make(len, "")

  for i in 0..<len {
    names[i] = zip.cd_entries[i].filename
  }

  names
}

///|
/// ## DEFLATE Decompression
///
/// Decompresses DEFLATE-compressed data using the inflate algorithm.
///
/// # Parameters
/// - `data`: The compressed data bytes
///
/// # Returns
/// The decompressed data as Bytes
///
/// # Example
/// ```moonbit nocheck
/// let decompressed = inflate(compressed_data)
/// ```
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
/// ## Unzip All Files
///
/// Extracts all files from a ZIP archive at once.
///
/// # Parameters
/// - `data`: The raw bytes of the ZIP file
///
/// # Returns
/// An array of tuples `(filename, data)` for all extracted files
///
/// # Throws
/// - If the ZIP file is invalid or corrupted
/// - If decompression fails for any file
///
/// # Example
/// ```moonbit nocheck
/// let extracted = unzip_file(zip_data)
/// for entry in extracted.iter() {
///   let (filename, data) = entry
///   println("Extracted: " + filename)
/// }
/// ```
pub fn unzip_file(data : Bytes) -> Array[(String, Bytes)] raise {
  let zip : ZipFile = zip_file_open(data)
  let len : Int = zip.cd_entries.length()
  let result : Array[(String, Bytes)] = Array::make(len, ("", Bytes::new(0)))

  for i in 0..<len {
    result[i] = zip_file_extract(zip, i)
  }

  result
}

///|
/// ## Unzip from File Path
///
/// Extracts all files from a ZIP archive specified by file path.
/// This is an async function that reads the file from disk.
///
/// If `output_dir` is provided, files will be written to that directory.
/// Otherwise, the extracted files are returned as an array.
///
/// # Parameters
/// - `path`: The path to the ZIP file
/// - `output_dir`: Optional output directory to extract files to
///
/// # Returns
/// An array of tuples `(filename, data)` for all extracted files
///
/// # Throws
/// - If the file cannot be read
/// - If the ZIP file is invalid or corrupted
/// - If decompression fails for any file
///
/// # Example
/// ```moonbit nocheck
/// async fn {
///   // Just get the files in memory
///   let extracted = unzip_file_path("/path/to/archive.zip")
///
///   // Extract to a directory
///   let extracted = unzip_file_path("/path/to/archive.zip", output_dir="./output")
/// }
/// ```
pub async fn unzip_file_path(
  path : String,
  output_dir? : String,
) -> Array[(String, Bytes)] {
  let data = @fs.read_file(path).binary()
  let files = unzip_file(data)
  match output_dir {
    Some(dir) => {
      let exists = @fs.exists(dir)
      if exists {
        let kind = @fs.kind(dir)
        match kind {
          @fs.FileKind::Directory => ()
          _ => fail("Output path is not a directory: " + dir)
        }
      } else {
        @fs.mkdir(dir, permission=0o755, recursive=true)
      }

      for entry in files.iter() {
        let (filename, file_data) = entry
        let output_path = dir + "/" + filename
        if filename.has_suffix("/") {
          @fs.mkdir(output_path, permission=0o755, recursive=true) catch {
            _ => ()
          }
        } else {
          let last_slash = find_last_slash(filename)
          if last_slash >= 0 {
            let sub_dir = dir + "/" + filename[0:last_slash].to_owned()
            @fs.mkdir(sub_dir, permission=0o755, recursive=true) catch {
              _ => ()
            }
          }
          @fs.write_file(output_path, file_data, create_mode=CreateOrTruncate) catch {
            _ => ()
          }
        }
      }
      files
    }
    None => files
  }
}

///|
fn find_last_slash(s : String) -> Int {
  let bytes = @utf8.encode(s)
  let mut last = -1
  let mut i = 0
  while i < bytes.length() {
    if bytes[i].to_uint() == 0x2F {
      last = i
    }
    i = i + 1
  }
  last
}
