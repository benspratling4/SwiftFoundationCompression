//
//  WritingZipFiles.swift
//  SwiftFoundationCompression
//
//  Created by Ben Spratling on 10/14/16.
//
//

import Foundation
import SwiftPatterns


protocol ZipWriter : class {
	
	func finish()throws
	
	var currentByteCount:Int { get }
	
	func append(_ data:Data)
	
	func append(_ int:UInt16)
	
	func append(_ int:UInt32)
	
	func append(_ bytes:[UInt8])
	
	func addDirectoryEntry(_ entry:CentralDirectoryHeaderForWriting)
}



struct EndOfCentralDirectoryForWriting {
	var numberOfEntriesInTheCentralDirectory:UInt16
	var sizeOfTheCentralDirectory:UInt32
	var offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber:UInt32
	
	init(numberOfEntriesInTheCentralDirectory:UInt16, sizeOfTheCentralDirectory:UInt32, offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber:UInt32) {
		self.numberOfEntriesInTheCentralDirectory = numberOfEntriesInTheCentralDirectory
		self.sizeOfTheCentralDirectory = sizeOfTheCentralDirectory
		self.offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber = offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber
	}
}


extension ZipWriter {
	
	func append(_ eocd:EndOfCentralDirectoryForWriting) {
		append(UInt32(0x06054b50))	//signature
		append(UInt16(0))	//number of this disc
		append(UInt16(0))	//numberOfTheDiskWithTheCentralDirectory
		append(eocd.numberOfEntriesInTheCentralDirectory)//numberOfEntriesInTheCentralDirectoryOnThisDisk
		append(eocd.numberOfEntriesInTheCentralDirectory)//numberOfEntriesInTheCentralDirectory
		append(eocd.sizeOfTheCentralDirectory)//sizeOfTheCentralDirectory
		append(eocd.offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber)//offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber
		append(UInt16(0))//commentLength
	}
	
}


struct CentralDirectoryHeaderForWriting {
	var crc32:UInt32
	var compressedSize:UInt32
	var decompressedSize:UInt32
	var relativeOffsetOfLocalHeader:UInt32
	var filenameBytes:[UInt8]
	
	init(filename:String, crc32:UInt32, compressedSize:UInt32, decompressedSize:UInt32, fileNameLength:UInt16, relativeOffsetOfLocalHeader:UInt32)throws {
		guard let data = filename.data(using: .utf8), data.count < 65536 else {
			throw CompressionError.unsupportedFormat
		}
		filenameBytes = [UInt8](repeating:0, count:data.count)
		data.copyBytes(to: &filenameBytes, count: data.count)
		self.crc32 = crc32
		self.compressedSize = compressedSize
		self.decompressedSize = decompressedSize
		self.relativeOffsetOfLocalHeader = relativeOffsetOfLocalHeader
	}
}


extension ZipWriter {
	func append(_ header:CentralDirectoryHeaderForWriting) {
		append(UInt32(0x02014b50))	//signature
		append(UInt16(19<<8 | 20))	//versionMadeBy, 20 = "2.0", 19<<8 == "OS X"
		append(UInt16(20))	// versionNeededToExtract == "2.0"
		append(GeneralPurposeFlags.fileNameIsUnicode.rawValue)	//general purpose flags
		append(CompressionMethod.deflated.rawValue)
		append(UInt16(0))//modifiedFileTime
		append(UInt16(0))//modifiedFileDate
		append(header.crc32)	//if self is a data writer, includthese here.
		//if self is a file handle writer, write 0 and use the general purpose flag for storing the info in the central dir entry
		append(header.compressedSize)
		append(header.decompressedSize)
		append(UInt16(header.filenameBytes.count))	//fileNameLength
		append(UInt16(0))	// extraFieldLength
		append(UInt16(0))	// fileCommentLength
		append(UInt16(0))	// diskNumberStart
		append(UInt16(0))	// internalAttributes
		append(UInt32(0))	//externalFileAttributes
		append(header.relativeOffsetOfLocalHeader)	//externalFileAttributes
		append(header.filenameBytes)
	}
}


extension ZipWriter {
	func append (_ headers:[CentralDirectoryHeaderForWriting]) {
		let centralDirectoryOffset:Int = currentByteCount
		for header in headers {
			append(header)
		}
		let sizeOfCentralDirectory:UInt32 = UInt32(currentByteCount - centralDirectoryOffset)
		let eocd = EndOfCentralDirectoryForWriting(numberOfEntriesInTheCentralDirectory: UInt16(headers.count),
												   sizeOfTheCentralDirectory: sizeOfCentralDirectory,
												   offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber: UInt32(centralDirectoryOffset))
		append(eocd)
	}
}


struct LocalHeaderForWriting {
	var lastModifiedTime:UInt16 = 0
	var lastModifiedDate:UInt16 = 0
	var crc32:UInt32
	var compressedSize:UInt32
	var decompressedSize:UInt32
	var extraFieldLength:UInt16 = 0
	var filenameBytes:[UInt8]
	
	init(filename:String, crc32:UInt32, compressedSize:UInt32, decompressedSize:UInt32)throws {
		guard let data = filename.data(using: .utf8), data.count < 65536 else {
			throw CompressionError.unsupportedFormat
		}
		filenameBytes = [UInt8](repeating:0, count:data.count)
		data.copyBytes(to: &filenameBytes, count: data.count)
		self.crc32 = crc32
		self.compressedSize = compressedSize
		self.decompressedSize = decompressedSize
	}
	
}


extension ZipWriter {
	
	func append(_ header:LocalHeaderForWriting) throws {
		append(UInt32(0x04034b50))	//signature
		append(UInt16(20))	// "2.0"
		append(GeneralPurposeFlags.fileNameIsUnicode.rawValue)//general purpose bit flags
		append(CompressionMethod.deflated.rawValue)	//compression method
		append(header.lastModifiedTime)
		append(header.lastModifiedDate)
		append(header.crc32)
		append(header.compressedSize)
		append(header.decompressedSize)
		append(UInt16(header.filenameBytes.count))
		append(UInt16(0))	//extraFieldLength
		append(header.filenameBytes)
	}
}


extension CentralDirectoryHeaderForWriting {
	init(localHeader:LocalHeaderForWriting, offset:Int) {
		filenameBytes = localHeader.filenameBytes
		crc32 = localHeader.crc32
		compressedSize = localHeader.compressedSize
		decompressedSize = localHeader.decompressedSize
		relativeOffsetOfLocalHeader = UInt32(offset)
	}
}


extension ZipWriter {
	
	func compress(data:Data, path:String)throws {
		let (compressed, crc) = try data.deflate()
		let localHeader:LocalHeaderForWriting = try LocalHeaderForWriting(filename:path, crc32: crc, compressedSize: UInt32(compressed.count), decompressedSize: UInt32(data.count))
		let offset:Int = currentByteCount
		try append(localHeader)
		append(compressed)
		let centralHeader = CentralDirectoryHeaderForWriting(localHeader:localHeader, offset:offset)
		addDirectoryEntry(centralHeader)
	}
	
}


class ZipDataWriter : ZipWriter {
	
	var data:Data = Data()
	
	var currentByteCount:Int {
		get {
			return data.count
		}
	}
	
	var centralDirectoryHeaders:[CentralDirectoryHeaderForWriting] = []
	
	func finish()throws {
		append(centralDirectoryHeaders)
	}
	
	func addDirectoryEntry(_ entry: CentralDirectoryHeaderForWriting) {
		centralDirectoryHeaders.append(entry)
	}
	
	func append(_ data:Data) {
		self.data.append(data)
	}
	
	func append(_ int:UInt16) {
		data.append(value: int)
	}
	
	func append(_ int:UInt32) {
		data.append(value: int)
	}
	
	func append(_ bytes:[UInt8]) {
		data.append(bytes, count:bytes.count)
	}
	
}

/*
//TODO: write me
class ZipFileWriter : ZipWriter {
	let fileHandle:FileHandle
	init(fileHandle:FileHandle) {
		self.fileHandle = fileHandle
	}
}
*/

extension SubResourceWrapping {
	
	func recursiveCreateZipData(with writer:ZipWriter, pathPrefix:String)throws {
		for (_, subResource) in subResources {
			if let file = subResource as? DataWrapping {
				let filePath:String = pathPrefix + file.lastPathComponent
				try writer.compress(data: file.contents, path: filePath)
			} else if let directory = subResource as? SubResourceWrapping {
				let newPath:String = pathPrefix + directory.lastPathComponent + "/"
				try directory.recursiveCreateZipData(with: writer, pathPrefix: newPath)
			}
		}
	}
	
}

