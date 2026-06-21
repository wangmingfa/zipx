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

```moonbit
import { unzip_file, zip_file_open, zip_file_list } from "wangmingfa/zipx"

// Extract all files from a ZIP archive
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

### `unzip_file`

```moonbit
pub fn unzip_file(data : Bytes) -> Array[(String, Bytes)] raise
```

Extracts all files from a ZIP archive. Returns an array of (filename, data) tuples.

### `zip_file_open`

```moonbit
pub fn zip_file_open(data : Bytes) -> ZipFile raise
```

Opens a ZIP archive for reading. Returns a `ZipFile` handle.

### `zip_file_list`

```moonbit
pub fn zip_file_list(zip : ZipFile) -> Array[String]
```

Returns a list of all filenames in the ZIP archive.

### `zip_file_extract`

```moonbit
pub fn zip_file_extract(zip : ZipFile, index : Int) -> (String, Bytes) raise
```

Extracts a single file by index. Returns (filename, data) tuple.

### `inflate`

```moonbit
pub fn inflate(data : Bytes) -> Bytes
```

Low-level DEFLATE decompression function.

## Supported Compression Methods

| Method | Description |
|--------|-------------|
| Store (0) | No compression |
| Deflate (8) | DEFLATE compression |

## License

Apache-2.0