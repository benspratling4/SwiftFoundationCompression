//
//  GZip.swift
//  SwiftFoundationCompression
//
//  Created by Ben Spratling on 10/11/16.
//
//

import Foundation
import SwiftPatterns
import CZlib

///the purpose of GZip is to zip a "file", so it makes no sense to use .gzip on Data, it's just deflate with file info wrapped around it
public class GZipDataWrapping : DataWrapping {
	//TODO: figure out if a gzip file can contain multiple files, or just one
	
	var header:GZipHeader?
	
	/// it will gain the filename of the .gzip file, and contents will be the unzipped data
	public init(compressedData:Data)throws {
		let gHeader = try GZipHeader(data: compressedData)
		header = gHeader
		let subData:Data = compressedData.subdata(in:gHeader.offsetToCompressedData..<compressedData.count)
		let decompressed = try subData.decompressed(using: .deflate)
		wrapper = FileWrapper(regularFileWithContents: decompressed)
		wrapper.preferredFilename = gHeader.filename
	}
	
	/*
	/// the serializedData will be a .gz file
	public init(_ dataWrapping:DataWrapping)throws {
		
		
	}
	*/
	
	
	weak public var parentResourceWrapper:SubResourceWrapping?
	
	public var lastPathComponent: String {
		get {
			return wrapper.preferredFilename ?? ""
		}
		set {
			parentResourceWrapper?.child(named: lastPathComponent, changedNameTo: newValue)
			wrapper.preferredFilename = newValue
		}
	}
	
	public var contents: Data {
		get {
			return wrapper.regularFileContents ?? Data()
		}
		set {
			let newWrapper = FileWrapper(regularFileWithContents:newValue)
			newWrapper.preferredFilename = wrapper.preferredFilename
			wrapper = newWrapper
		}
	}
	
	public var serializedRepresentation: Data {
		//TODO: compress
		fatalError()
	}
	
	fileprivate var wrapper:FileWrapper
	
	
	private init(regularFileWrapper:FileWrapper) {
		self.wrapper = regularFileWrapper
	}

	
	///returns nil if the file wrapper is not a regular file
	public convenience init?(wrapper:FileWrapper) {
		if !wrapper.isRegularFile { return nil }
		self.init(regularFileWrapper:wrapper)
	}
	
	public convenience init(data:Data, name:String) {
		let wrapper = FileWrapper(regularFileWithContents:data)
		wrapper.preferredFilename = name
		self.init(wrapper:wrapper)!
	}
	
	
}



struct GZipHeader {
	enum OperatingSystem : UInt8 {
		case FAT, Amiga, VMS, Unix, VMCMS, Atari, HPFS, Macintosh, ZSystem, CPM, TOPS20, NTFS, QDOS, Acorn
	}
	
	struct Flags : OptionSet {
		let rawValue:UInt8
		static let isText:Flags = Flags(rawValue:1)
		static let headerCRC:Flags = Flags(rawValue:2)
		static let hasExtraFields:Flags = Flags(rawValue:4)
		static let hasFileName:Flags = Flags(rawValue:8)
		static let hasComment:Flags = Flags(rawValue:16)
	}
	
	
	let flags:Flags
	let modifiedTime:Date?
	let extraFlags:UInt8
	let os:OperatingSystem?
	let extraLength:Int
	let extraBytes:[UInt8]?
	let filename:String?
	let fileNameLength:Int
	let comment:String?
	let commentLength:Int
	let crc:UInt16?
	
	var offsetToCompressedData:Int {	//from the beginning of the header
		return 10 +
			(flags.contains(.hasExtraFields) ? 2 +
				extraLength : 0) +
			fileNameLength +
			commentLength +
			(flags.contains(.headerCRC) ? 2 : 0)
	}
	
	init(data:Data)throws {
		let reader = DataReader(data: data, offset: 0)
		//verify this is a .gzip file
		let id1:UInt8 = try reader.read()
		if id1 != 31 { throw CompressionError.invalidFormat }
		let id2:UInt8 = try reader.read()
		if id2 != 139 { throw CompressionError.invalidFormat }
		let compressionMethod:UInt8 = try reader.read()
		if compressionMethod != 8 { throw CompressionError.unsuppotedFormat }
		//load header info
		let flagsByte:UInt8 = try reader.read()
		flags = Flags(rawValue:flagsByte)
		let modifiedTimeBytes:Int32 = try reader.read()
		if modifiedTimeBytes == 0 {
			modifiedTime = nil
		} else {
			modifiedTime = Date(timeIntervalSince1970: TimeInterval(modifiedTimeBytes))
		}
		
		extraFlags = try reader.read()
		let osByte:UInt8 = try reader.read()
		os = OperatingSystem(rawValue: osByte)
		
		if flags.contains(.hasExtraFields) {
			let extraBytesLength:UInt16 = try reader.read()
			extraLength = Int(extraBytesLength)
			extraBytes = try reader.readBytes(count: Int(extraBytesLength))
		} else {
			extraLength = 0
			extraBytes = nil
		}
		
		if flags.contains(.hasFileName) {
			//collect bytes until hitting nil
			var fileNameBytes:[UInt8] = []
			while true {
				let aByte:UInt8 = try reader.read()
				if aByte == 0 { break }
				fileNameBytes.append(aByte)
			}
			filename = String(bytes: fileNameBytes, encoding: .isoLatin1)
			fileNameLength = fileNameBytes.count + 1
		} else {
			fileNameLength = 0
			filename = nil
		}
		
		if flags.contains(.hasComment) {
			var commentBytes:[UInt8] = []
			while true {
				let aByte:UInt8 = try reader.read()
				if aByte == 0 { break }
				commentBytes.append(aByte)
			}
			comment = String(bytes: commentBytes, encoding: .isoLatin1)
			commentLength = commentBytes.count + 1
		} else {
			commentLength = 0
			comment = nil
		}
		
		if flags.contains(.headerCRC) {
			crc = try reader.read()
		} else {
			crc = nil
		}
	}
	
}










