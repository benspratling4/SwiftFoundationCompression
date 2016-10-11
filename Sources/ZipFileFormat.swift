//
//  ZipFileFormat.swift
//  SwiftFoundationCompression
//
//  Created by Ben Spratling on 10/9/16.
//
//

import Foundation
import SwiftPatterns


// Based on documentation found at https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT


/*
	This file contains essential types for reading the structure of a .zip file.
*/

//for reading things from Data
class DataReader {
	
	let data:Data
	
	init(data:Data, offset:Int = 0) {
		self.data = data
		self.offset = offset
	}
	
	var offset:Int
	
	func read<ContentType>()throws->ContentType {
		let dataSize:Int = MemoryLayout<ContentType>.size
		if offset < 0 || offset + dataSize > data.count {
			throw CompressionError.invalidFormat
		}
		let value:ContentType = data.extract(at: offset)
		offset += dataSize
		return value
	}
	
	func readString(count:Int, encoding:String.Encoding = .utf8)throws->String {
		var fileNameBytes = [UInt8](repeating:0, count:count)
		fileNameBytes.withUnsafeMutableBufferPointer { (bufferPointer) -> () in
			//TODO: write loop
			let _ = data.copyBytes(to: bufferPointer, from: (offset)..<(offset + count))	//TODO: verify the bytes are copied
		}
		guard let name:String =  String(bytes: fileNameBytes, encoding: encoding) else { throw CompressionError.invalidFormat }
		offset += count
		return name
	}
	
	
	func readBytes(count:Int)throws->[UInt8] {
		var arrayBytes = [UInt8](repeating:0, count:count)
		arrayBytes.withUnsafeMutableBufferPointer { (bufferPointer) -> () in
			let _ = data.copyBytes(to: bufferPointer, from: (offset)..<(offset + count))	//TODO: verify the bytes are copied
		}
		offset += count
		return arrayBytes
	}
	
	
}


struct EndOfCentralDirectoryRecord {
	let fileOffsetToBeginningOfEndOfCentralDirectory:Int
	
	let numberOfRecords:Int
	let offsetToCentralDirectory:Int
	let centralDirectorySize:Int
	
	
	static func offsetToStart(in data:Data)->Int? {
		//start at count - 22
		//scan backwards up to 65536 additional bytes
		//search for the end of central record magic cookie followed by the right value at the "comment length" position
		for commentLength in 0...65535 {
			let magicCookieIndex = data.count - 22 - commentLength
			let commentCountStartIndex = data.count - commentLength - 2
			if magicCookieIndex < 0 { return nil }
			
			let readMagicCookie:UInt32 = data.extract(at: magicCookieIndex)
			if readMagicCookie != 0x06054b50 { continue }
			
			//check the comment length
			let shortCommentLength = UInt16(commentLength)
			let commentLengthInFile:UInt16 = data.extract(at: commentCountStartIndex)
			if shortCommentLength != commentLengthInFile { continue }
			//suceeded!
			return data.count - commentLength - 22
		}
		return nil
	}
	
	init(data:Data)throws {
		guard let eocdIndex:Int = EndOfCentralDirectoryRecord.offsetToStart(in: data) else { throw CompressionError.invalidFormat }
		fileOffsetToBeginningOfEndOfCentralDirectory = eocdIndex
		let reader = DataReader(data: data, offset:eocdIndex + 4)	//skip the magic number
		let numberOfThisDisc:UInt16 = try reader.read()
		let numberOfTheDiscWithCentralDirectory:UInt16 = try reader.read()
		if numberOfThisDisc != 0 || numberOfTheDiscWithCentralDirectory != 0 {
			throw CompressionError.unsuppotedFormat
		}
		let numberOfEntries:UInt16 = try reader.read()	//total number of entries in central dir on this disc
		reader.offset += 2//skip duplicate of above
		let cdSize:UInt32 = try reader.read()
		let cdOffset:UInt32 = try reader.read()
		//determine if this is a zip file & read the end of central directory
		offsetToCentralDirectory = Int(cdOffset)
		numberOfRecords = Int(numberOfEntries)
		centralDirectorySize = Int(cdSize)
		//TODO: detect & reject encrypted files
	}
	
}

struct GeneralPurposeFlags : OptionSet {
	let rawValue:UInt16
	static var encrypted:GeneralPurposeFlags = GeneralPurposeFlags(rawValue: 1 << 0)
	static var sizesAndCRCAreInDataDescriptor:GeneralPurposeFlags = GeneralPurposeFlags(rawValue: 1 << 3)
	static var strongEnctyption:GeneralPurposeFlags = GeneralPurposeFlags(rawValue: 1 << 6)
	static var fileNameIsUnicode:GeneralPurposeFlags = GeneralPurposeFlags(rawValue: 1 << 11)
	static var centralDirectoryValuesAreOmittedDueToEncyption:GeneralPurposeFlags = GeneralPurposeFlags(rawValue: 1 << 13)
}


struct Version {
	let version:Int8
	let os:UInt8
	init(dataReader:DataReader)throws {
		version = try dataReader.read()
		os = try dataReader.read()
	}
}

/*
struct ZipDateTime {
	//TODO: write me
	init(zipDate:UInt32) {
		
	}
	
	var date:Date {
		
	}
	
}
*/

struct CentralDirectoryEntry {
	
	/// get the index in the Data to the next CentralDirectoryEntry
	var nextEntryIndex:Int {
		return 46 + Int(fileNameLength) + Int(extraFieldLength) + Int(fileCommentLength)
	}
	
	var versionMadeBy:Version
	var versionNeededToExtract:UInt16
	var generalBitFlags:GeneralPurposeFlags
	let method:CompressionMethod
	let lastModifiedTime:UInt16
	let lastModifiedDate:UInt16
	let crc32:UInt32
	var compressedSize:UInt32
	var uncompressedSize:UInt32
	var fileNameLength:UInt16
	var extraFieldLength:UInt16
	var fileCommentLength:UInt16
	
	let localHeaderRelativeOffset:Int
	
	var fileName:String
	
	init(data:Data, at index:Int)throws {
		//verify it is an entry
		let reader = DataReader(data: data, offset:index)
		let magic:UInt32 = try reader.read()
		if magic != 0x02014b50 { throw CompressionError.invalidFormat }
		versionMadeBy = try Version(dataReader:reader)
		versionNeededToExtract = try reader.read()
		generalBitFlags = GeneralPurposeFlags(rawValue:try reader.read())
		guard let compressionMethod = CompressionMethod(rawValue: try reader.read()) else { throw CompressionError.invalidFormat }
		method = compressionMethod
		lastModifiedTime = try reader.read()
		lastModifiedDate = try reader.read()
		crc32 = try reader.read()
		compressedSize = try reader.read()
		uncompressedSize = try reader.read()
		fileNameLength = try reader.read()
		extraFieldLength = try reader.read()
		fileCommentLength = try reader.read()
		reader.offset += 8
		let localOffset:UInt32 = try reader.read()
		localHeaderRelativeOffset = Int(localOffset)
		
		fileName = try reader.readString(count: Int(fileNameLength), encoding:(generalBitFlags.contains(.fileNameIsUnicode) ? .utf8 : .ascii))
	}
	
	
}

enum CompressionMethod : UInt16 {
	case stored, shrunk, reduced1, reduced2, reduced3, reduced4, imploded, tokenized, deflated, deflated64, PKWareDataCompressionImploding
	case BZip2 = 12
	case LZMA = 14
	case IBMTerseNew = 18
	case LZ77z = 19
	case WavPack = 97
	case PPMd = 98
}


struct LocalFileHeader {
	let offset:Int
	let versionToExtract:Version
	let generalPurposeBitFlags:GeneralPurposeFlags
	let method:CompressionMethod
	let lastModifiedTime:UInt16
	let lastModifiedDate:UInt16
	let crc32:UInt32
	let compressedSize:UInt32
	let uncompressedSize:UInt32
	let fileNameLength:UInt16
	let extraFieldLength:UInt16
	
	var compressedDataOffset:Int {
		return offset + 30 + Int(fileNameLength) + Int(extraFieldLength)
	}
	
	var fileName:String
	
	init(data:Data, at index:Int)throws {
		//check the
		let reader:DataReader = DataReader(data:data, offset:index)
		let magic:UInt32 = try reader.read()
		if magic != 0x04034b50 {
			throw CompressionError.invalidFormat
		}
		
		offset = index
		versionToExtract = try Version(dataReader:reader)
		let generalFlags:UInt16 = try reader.read()
		generalPurposeBitFlags = GeneralPurposeFlags(rawValue:generalFlags)
		guard let compressionMethod = CompressionMethod(rawValue: try reader.read()) else {
			throw CompressionError.invalidFormat
		}
		method = compressionMethod
		lastModifiedTime = try reader.read()
		lastModifiedDate = try reader.read()
		crc32 = try reader.read()
		compressedSize = try reader.read()
		uncompressedSize = try reader.read()
		fileNameLength = try reader.read()
		extraFieldLength = try reader.read()
		
		fileName = try reader.readString(count: Int(fileNameLength), encoding:(generalPurposeBitFlags.contains(.fileNameIsUnicode) ? .utf8 : .ascii))
	}
	
	
}


/**
Used internally, to own the zipped data, and inflate them on demand.
*/
class ZippedDataOwner {
	
	private var data:Data
	
	let centralDirectoryEntries:[CentralDirectoryEntry]
	
	init(data:Data)throws {
		let eocd = try EndOfCentralDirectoryRecord(data:data)
		var entries:[CentralDirectoryEntry] = []
		var entryOffset:Int = eocd.offsetToCentralDirectory
		for _ in 0..<eocd.numberOfRecords {
			let entry = try CentralDirectoryEntry(data:data, at:entryOffset)
			entries.append(entry)
			entryOffset += entry.nextEntryIndex
		}
		centralDirectoryEntries = entries
		self.data = data
	}
	
	func inflated(file:CentralDirectoryEntry)throws->Data {
		//create a wrapper around the sub data, call inflate on it
		let localHeader:LocalFileHeader = try LocalFileHeader(data: data, at: file.localHeaderRelativeOffset)
		let compressedSize:Int
		if localHeader.generalPurposeBitFlags.contains(.sizesAndCRCAreInDataDescriptor) {
			compressedSize = Int(file.compressedSize)
		} else {
			compressedSize = Int(localHeader.compressedSize)
		}
		//print("compressedSize = \(compressedSize)")
		let endOfCompressedDataOffset:Int = localHeader.compressedDataOffset + compressedSize
		//var subData:Data = data.subdata(in: file.localHeaderRelativeOffset..<(endOfCompressedDataOffset))
		let subData:Data = data.subdata(in: localHeader.compressedDataOffset..<(endOfCompressedDataOffset))
		switch localHeader.method {
		case .deflated:
			return try subData.inflate()
		case .stored:
			//TODO: verify if this is correct and we don't need to account for "blocks"
			return subData
		default:
			throw CompressionError.unsuppotedFormat
		}
	}
	
	/*
	//iterate buffer for file at index
	func readCompressed(file:CentralDirectoryEntry, maxBufferSize:Int = 4096, handler:(Data, Float32, inout Bool)->()) {
	
	//	data.copyBytes(to: <#T##UnsafeMutablePointer<UInt8>#>, from: <#T##Range<Data.Index>#>)
	
	}
	*/
	
}
