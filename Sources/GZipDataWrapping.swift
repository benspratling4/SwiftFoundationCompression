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
	
	
	/// the serializedData will be a .gz file
	public init(_ dataWrapping:DataWrapping)throws {
		wrapper = FileWrapper(regularFileWithContents: dataWrapping.contents)
		wrapper.preferredFilename = dataWrapping.lastPathComponent
	}
	
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
		return (try? gzip(data: wrapper.regularFileContents!, named: wrapper.preferredFilename ?? "")) ?? Data()
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

//just like
func gzip(data:Data, named:String)throws->Data {
	let chunkSize:Int = memoryPageSize
	let strategy:Int32 = 0	//default
	let compressionLevel:Int32 = -1	//default
	let memoryLevel:Int32 = 8	//how much internal memory is used
	
	//do the dual-buffer thing
	var inBuffer:[UInt8] = [UInt8](repeating:0, count:chunkSize)
	let inBufferPointer = UnsafeMutableBufferPointer(start: &inBuffer, count: chunkSize)
	var outBuffer:[UInt8] = [UInt8](repeating:0, count:chunkSize)
	let outBufferPointer = UnsafeMutableBufferPointer(start: &outBuffer, count: chunkSize)
	
	//pre-fill the inBuffer
	let countInBuffer:Int = Swift.min(chunkSize, data.count)
	let copiedByteCount:Int = data.copyBytes(to: inBufferPointer, from: 0..<countInBuffer)
	
	//init the stream
	var stream = z_stream(next_in: inBufferPointer.baseAddress,
	                      avail_in: UInt32(copiedByteCount),
	                      total_in: 0, next_out: nil, avail_out: 0,
	                      total_out: 0, msg: nil, state: nil, zalloc: nil,
	                      zfree: nil, opaque: nil, data_type: 0, adler: 0,
	                      reserved: 0)
	let windowBits:Int32 = MAX_WBITS | 16//(method == "gzip") ? MAX_WBITS + 16 : MAX_WBITS
	let result = deflateInit2_(&stream, compressionLevel, Z_DEFLATED,
	                           windowBits, memoryLevel, strategy,
	                           ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
	//check for init errors
	if result != Z_OK {
		throw CompressionError.fail(result)
	}
	//defer clean up
	defer {
		deflateEnd(&stream)
	}
	var streamStatus:Int32 = Z_OK
	
	let timeDiff:TimeInterval = Date().timeIntervalSince1970.rounded()
	let time:UInt = UInt(timeDiff)
	let fileNameData:Data = named.data(using: .isoLatin1) ?? Data()
	var dataBytes = [UInt8](repeating:0, count:fileNameData.count + 1)
	let _ = fileNameData.copyBytes(to: UnsafeMutableBufferPointer(start:&dataBytes, count:fileNameData.count))
	var header:gz_header = gz_header(text: 0, time: time, xflags: 0, os: 0, extra: nil, extra_len: 0, extra_max: 0, name: &dataBytes, name_max: UInt32(fileNameData.count + 1), comment: nil, comm_max: 0, hcrc: 0, done: 0)
	
	streamStatus = deflateSetHeader(&stream, &header)
	if streamStatus != Z_OK {
		throw CompressionError.fail(streamStatus)
	}
	
	//loop over buffers
	var outData:Data = Data()
	
	while streamStatus == Z_OK {
		//always provide at least a whole buffer of data
		let readBytes = Int(stream.total_in)
		let countInBuffer:Int = Swift.min(chunkSize, data.count - readBytes)
		let copiedByteCount:Int = data.copyBytes(to: inBufferPointer, from: readBytes..<(readBytes+countInBuffer))
		stream.next_in = inBufferPointer.baseAddress
		stream.avail_in = UInt32(copiedByteCount)
		stream.next_out = outBufferPointer.baseAddress
		stream.avail_out = UInt32(chunkSize)
		//actual deflation
		let previousTotalOut:Int = Int(stream.total_out)
		streamStatus = CZlib.deflate(&stream, copiedByteCount > 0 ? Z_NO_FLUSH : Z_FINISH)
		//check for errors
		if streamStatus != Z_OK && streamStatus != Z_STREAM_END  && streamStatus != Z_BUF_ERROR {
			throw CompressionError.fail(streamStatus)
		}
		//always copy out all written bytes
		let newOutByteCount:Int = Int(stream.total_out) - previousTotalOut
		outData.append(&outBuffer, count: newOutByteCount)
	}
	
	return outData
}


