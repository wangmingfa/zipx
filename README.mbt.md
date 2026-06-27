# wangmingfa/zipx

A pure MoonBit implementation of ZIP archive extraction, without FFI or system commands.

## Features

- Pure MoonBit implementation (no FFI, no system calls)
- DEFLATE decompression support
- Store (no compression) support
- CLI tool for extracting and listing ZIP files
- Async file I/O support

## Installation

```bash
moon add wangmingfa/zipx
```

## Usage

### As a Library

#### Simple Usage (Async)

```moonbit nocheck
import { unzip_file_path } from "wangmingfa/zipx"

async fn {
  // Extract all files from a ZIP archive by path
  let extracted = unzip_file_path("/path/to/archive.zip")
  for entry in extracted.iter() {
    let (filename, data) = entry
    // Process extracted file...
  }
}
```

#### Advanced Usage (Sync)

```moonbit nocheck
import { unzip_file, zip_file_open, zip_file_list } from "wangmingfa/zipx"

// Extract all files from a ZIP archive (requires pre-loaded data)
let extracted : Array[(String, Bytes)] = unzip_file(zip_data)
for entry in extracted.iter() {
  let (filename, data) = entry
  // Process extracted file...
}

// Or use lower-level API
let zip = zip_file_open(zip_data)
let files = zip_file_list(zip)  // Get list of filenames
let (filename, data) = zip_file_extract(zip, 0)  // Extract by index
```

### CLI Tool

```bash
# Build the CLI tool
moon build cmd/main/

# List files in a ZIP archive
moon run cmd/main/ list /path/to/archive.zip

# Extract files from a ZIP archive
moon run cmd/main/ unzip /path/to/archive.zip ./output_dir
```

## API Reference

### `unzip_file_path` (Async)

```moonbit nocheck
pub async fn unzip_file_path(path : String) -> Array[(String, Bytes)] raise
```

Extracts all files from a ZIP archive specified by file path.
This is an async function that reads the file from disk.

**Parameters:**
- `path`: The path to the ZIP file

**Returns:**
An array of `(filename, data)` tuples for all extracted files

**Example:**
```moonbit nocheck
async fn {
  let extracted = unzip_file_path("/path/to/archive.zip")
  for entry in extracted.iter() {
    let (filename, data) = entry
    println("Extracted: " + filename)
  }
}
```

### `unzip_file`

```moonbit nocheck
pub fn unzip_file(data : Bytes) -> Array[(String, Bytes)] raise
```

Extracts all files from a ZIP archive. Returns an array of `(filename, data)` tuples.

### `zip_file_open`

```moonbit nocheck
pub fn zip_file_open(data : Bytes) -> ZipFile raise
```

Opens a ZIP archive for reading. Returns a `ZipFile` handle.

### `zip_file_list`

```moonbit nocheck
pub fn zip_file_list(zip : ZipFile) -> Array[String]
```

Returns a list of all filenames in the ZIP archive.

### `zip_file_extract`

```moonbit nocheck
pub fn zip_file_extract(zip : ZipFile, index : Int) -> (String, Bytes) raise
```

Extracts a single file by index. Returns `(filename, data)` tuple.

### `inflate`

```moonbit nocheck
pub fn inflate(data : Bytes) -> Bytes
```

Low-level DEFLATE decompression function.

### `CompressionMethod`

```moonbit nocheck
///|
pub enum CompressionMethod {
  Stored // No compression
  Deflated // DEFLATE compression
  Unsupported(UInt16) // Unsupported method
}
```

The compression method used in a ZIP file entry.

## Supported Compression Methods

| Method | Description |
|--------|-------------|
| Store (0) | No compression |
| Deflate (8) | DEFLATE compression |

## License

Apache-2.0
