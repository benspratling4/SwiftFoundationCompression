# SwiftFoundationCompression

## Introduction

This package wraps file & data compression behavior available in zlib with Swift wrappers written to feel at home with the Foundation module.  No `UnsafePointer`s, no file descriptors, no `String` paths.  This behavior is available in 3 levels:

- Working with `Data`.  Behavior is designed to work with data small enough to be entirely loaded in RAM, but is optimized to read mapped `Data`.

- Working with files at `URL`s, use the `FileManager` extensions.  Methods are provided for compressing a directory into a file

- Representing a .zip or .tar.gz file as an in-ram file/folder structure with `ZipDirectoryWrapping` (similar to a directory `FileWrapper`).  Individual files in the .zip file conform to `DataWrapping` (a SwiftPatterns protocol similar to Foundation's `FileWrapper`).  For .zip files, each individual file is not decompressed until it is accessed.

## Status

Rudimentary .zip file opening, reading, and inflate have been implemented.  Optimized file writing is not implemented.

.gzip read has been implemented.

## Data

Compress or uncompress a `Data` with `.compressed(using:progress:)` (or `.decompressed(using:progress:)`), optionally choosing to use `.gzip` instead of `.deflate`.

`Data` compression with .deflate does not generate a header., and decompression works on the stream after the header. 
`Data` compression with `gzip` generates a header, suitable for wrapping, and requires the wrapper when uncompressing.

## FileManager

To decompress a number of existing files, use `FileManager`.

  func decompress(item:, with:, into:progress:)
  
which opens a compressed file and expands its contents into the supplied directory.

## Compressed on disk / file/folder in RAM

For file formats which exist as zipped on disk, but structured file/folders in RAM, something akin to  "zipped" `FileWrapper` would be nice.  `FileWrapper` has a design problem: both directories and regular files are the same class, meaning the API's are not compilar-enforced.  Using the `SerializedResourceWrapping` protocol from the `SwiftPatterns` module, this module introduces the `ZipDirectoryWrapping` class, which conforms to the `SubResourceWrapping` protocol.  You can browse it similarly to a directory `FileWrapper`, but individual files (which conform to `DataWrapping`) are not decompressed until you access the `.contents` property on them (for .zip files).

## Optimizations

`Data` methods access data in page-sized groups to reduce dirty memory footprint, but no optimization is made for the output data.  You should only use this for data you know to be useful in memory.

Not yet implemented:  `FileManager` methods make use of the page-size mapping of Data, and FileHandles to write as if it were a stream.

## Contributions

There are many corners with compression.  If you'd like to contribute, fork it, write it, and make a PR.

Here are some non-goals:

- Supporting more CRC.  Detecting error storage/transmission errors should be provided by the data storage & transmision layer.  It is not suitable for the internal contents of a file.

- Supporting encryption.  Nowadays, encryption is facilitated by the device for the filesystem as a whole.  It is not suitable for the internal contents of a file, except under exceptional cirucmstances.
