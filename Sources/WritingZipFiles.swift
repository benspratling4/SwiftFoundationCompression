//
//  WritingZipFiles.swift
//  SwiftFoundationCompression
//
//  Created by Ben Spratling on 10/14/16.
//
//

import Foundation
import SwiftPatterns

///TODO: something is wrong with zip file writing

struct EndOfCentralDirectoryForWriting {
	var magicNumber:UInt32 = 0x06054b50
	var numberOfThisDisk:UInt16 = 0
	var numberOfTheDiskWithTheCentralDirectory:UInt16 = 0
	var numberOfEntriesInTheCentralDirectoryOnThisDisk:UInt16
	var numberOfEntriesInTheCentralDirectory:UInt16 {
		didSet {
			numberOfEntriesInTheCentralDirectoryOnThisDisk = numberOfEntriesInTheCentralDirectory
		}
	}
	var sizeOfTheCentralDirectory:UInt32
	var offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber:UInt32
	var commentLength:UInt16 = 0
	//We ignore the 
	
	init(numberOfEntriesInTheCentralDirectory:UInt16, sizeOfTheCentralDirectory:UInt32, offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber:UInt32) {
		self.numberOfEntriesInTheCentralDirectoryOnThisDisk = numberOfEntriesInTheCentralDirectory
		self.numberOfEntriesInTheCentralDirectory = numberOfEntriesInTheCentralDirectory
		self.sizeOfTheCentralDirectory = sizeOfTheCentralDirectory
		self.offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber = offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber
	}
}


struct CentralDirectoryHeaderForWriting {
	var signature:UInt32 = 0x02014b50
	var versionMadeBy:UInt16 = (19<<8 | 20)
	var versionNeededToExtract:UInt16	= 20
	var generalPurposeBitFlag:UInt16 = GeneralPurposeFlags.fileNameIsUnicode.rawValue	//TODO: write me
	var compressionMethod:UInt16 = CompressionMethod.deflated.rawValue
	var modifiedFileTime:UInt16 = 0
	var modifiedFileDate:UInt16 = 0
	var crc32:UInt32
	var compressedSize:UInt32
	var decompressedSize:UInt32
	var fileNameLength:UInt16
	var extraFieldLength:UInt16 = 0
	var fileCommentLength:UInt16 = 0
	var diskNumberStart:UInt16 = 0
	var internalAttributes:UInt16 = 0
	var externalFileAttributesLow:UInt16 = 0
	var externalFileAttributeshigh:UInt16 = 0
	var relativeOffsetOfLocalHeaderLow:UInt16	//we have to do this to prevent misalignment :)
	var relativeOffsetOfLocalHeaderHigh:UInt16
	
	//var relativeOffsetOfLocalHeader:UInt32
	
	init(crc32:UInt32, compressedSize:UInt32, decompressedSize:UInt32, fileNameLength:UInt16, relativeOffsetOfLocalHeader:UInt32) {
		self.crc32 = crc32
		self.compressedSize = compressedSize
		self.decompressedSize = decompressedSize
		self.fileNameLength = fileNameLength
		relativeOffsetOfLocalHeaderLow = UInt16(relativeOffsetOfLocalHeader & 0xFFFF)
		relativeOffsetOfLocalHeaderHigh = UInt16((relativeOffsetOfLocalHeader >> 16) & 0xFF)
		//self.relativeOffsetOfLocalHeader = relativeOffsetOfLocalHeader
		internalAttributes = 0
		//externalFileAttributes = 0
	}
}


struct CentralDirectoryEntryForWriting {
	var header:CentralDirectoryHeaderForWriting
	var filenameBytes:[UInt8]
	init(filename:String, header:CentralDirectoryHeaderForWriting)throws {
		guard let data = filename.data(using: .utf8), data.count < 65536 else {
			throw CompressionError.unsupportedFormat
		}
		filenameBytes = [UInt8](repeating:0, count:data.count)
		data.copyBytes(to: &filenameBytes, count: data.count)
		self.header = header
		self.header.fileNameLength = UInt16(filenameBytes.count)
	}
}


extension Data {
	mutating func append(value cd:CentralDirectoryEntryForWriting) {
		var valueCopy:CentralDirectoryHeaderForWriting = cd.header
		let dataSize:Int = 46//MemoryLayout<CentralDirectoryHeaderForWriting>.size	//should be 46
		let rawPointer = UnsafeRawPointer(UnsafeMutablePointer(&valueCopy))
		let tempData = Data(bytes:rawPointer, count: dataSize)
		self.append(tempData)
		
		//append filename
		self.append(cd.filenameBytes, count: cd.filenameBytes.count)
	}
}


struct EndOfCentralDirectoryDigitalSignature {
	var signature:UInt32 = 0x05054b50
	var lengthOfExtraBytes:UInt16 = 0
}


extension Data {
	mutating func append(value cd:[CentralDirectoryEntryForWriting])throws {
		let offsetToCentralDirectory:UInt32 = UInt32(self.count)
		
		//write each one
		for entry in cd {
			append(value:entry)
		}
		let sizeOfCentralDirectory:UInt32 = UInt32(count) - offsetToCentralDirectory
	//	let sig = EndOfCentralDirectoryDigitalSignature()
	//	try self.append(value:sig)
		let eocd = EndOfCentralDirectoryForWriting(numberOfEntriesInTheCentralDirectory: UInt16(cd.count), sizeOfTheCentralDirectory: sizeOfCentralDirectory, offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber: offsetToCentralDirectory)
		try self.append(value:eocd)
	}
}


struct LocalHeaderForWriting {
	var signature:UInt32 = 0x04034b50
	var versionToExtract:UInt16 = 20
	var generalPurposeBitFlags:UInt16 = GeneralPurposeFlags.fileNameIsUnicode.rawValue
	var compressionMethod:UInt16 = CompressionMethod.deflated.rawValue
	var lastModifiedTime:UInt16 = 0
	var lastModifiedDate:UInt16 = 0
	var crc32:UInt32
	var compressedSize:UInt32
	var decompressedSize:UInt32
	var fileNameLength:UInt16
	var extraFieldLength:UInt16 = 0
	
	init(crc32:UInt32, compressedSize:UInt32, decompressedSize:UInt32, fileNameLength:UInt16) {
		self.crc32 = crc32
		self.compressedSize = compressedSize
		self.decompressedSize = decompressedSize
		self.fileNameLength = fileNameLength
	}
	
}

extension Data {
	
	mutating func append(value:LocalHeaderForWriting) throws {
		try append(value:value.signature)
		try append(value:value.versionToExtract)
		try append(value:value.generalPurposeBitFlags)
		try append(value:value.compressionMethod)
		try append(value:value.lastModifiedTime)
		try append(value:value.lastModifiedDate)
		try append(value:value.crc32)
		try append(value:value.compressedSize)
		try append(value:value.decompressedSize)
		try append(value:value.fileNameLength)
		try append(value:value.extraFieldLength)
	}
}

struct LocalHeaderEntryForWriting {
	var header:LocalHeaderForWriting
	var filenameBytes:[UInt8]
	init(filename:String, header:LocalHeaderForWriting)throws {
		guard let data = filename.data(using: .utf8), data.count < 65536 else {
			throw CompressionError.unsupportedFormat
		}
		filenameBytes = [UInt8](repeating:0, count:data.count)
		data.copyBytes(to: &filenameBytes, count: data.count)
		self.header = header
		self.header.fileNameLength = UInt16(filenameBytes.count)
	}
}


extension CentralDirectoryEntryForWriting {
	init(_ localHeader:LocalHeaderEntryForWriting, offset:Int) {
		self.header = CentralDirectoryHeaderForWriting(crc32: localHeader.header.crc32, compressedSize: localHeader.header.compressedSize, decompressedSize: localHeader.header.decompressedSize, fileNameLength: localHeader.header.fileNameLength, relativeOffsetOfLocalHeader: UInt32(offset))
		self.filenameBytes = localHeader.filenameBytes
	}
}


extension Data {
	mutating func append(value:LocalHeaderEntryForWriting)throws {
		try append(value:value.header)
		append(value.filenameBytes, count: value.filenameBytes.count)
	}
}


extension Data {
	///compresses the data, and appends a local header to the file, and returns a central directoryHeader
	mutating func appendDeflated(data:Data, path:String)throws->CentralDirectoryEntryForWriting {
		let (compressed, crc) = try data.deflate()
		let localHeader = LocalHeaderForWriting(crc32: crc, compressedSize: UInt32(compressed.count), decompressedSize: UInt32(data.count), fileNameLength: 0)
		let localEntry = try LocalHeaderEntryForWriting(filename: path, header: localHeader)
		let currentByteCount:Int = count
		try append(value:localEntry)
		append(compressed)
		return CentralDirectoryEntryForWriting(localEntry,offset:currentByteCount)
	}
}


class ZipDataWriter {
	var data:Data = Data()
	
	var centralDirectoryEntries:[CentralDirectoryEntryForWriting] = []
	
	func finish()throws {
		try data.append(value: centralDirectoryEntries)
	}
	
}


extension SubResourceWrapping {
	
	func recursiveCreateZipData(with writer:ZipDataWriter, pathPrefix:String)throws {
		for (_, subResource) in subResources {
			if let file = subResource as? DataWrapping {
				let filePath:String = pathPrefix + file.lastPathComponent
				let dirEntry = try writer.data.appendDeflated(data: file.contents, path: filePath)
				writer.centralDirectoryEntries.append(dirEntry)
			} else if let directory = subResource as? SubResourceWrapping {
				let newPath:String = pathPrefix + directory.lastPathComponent + "/"
				try directory.recursiveCreateZipData(with: writer, pathPrefix: newPath)
			}
		}
	}
	
}

