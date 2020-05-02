//
//  Data+Compression.swift
//  FoundationZip
//
//  Created by Ben Spratling on 10/9/16.
//
//

import Foundation
import CZlib	//thanks, IBM!


let memoryPageSize:Int = 4096

/// There are many ways to compress data, use this to pick which one.
public enum CompressionTechnique {
	///The default technique used in .zip files, aka "inflate" for decompression
	case deflate
	case gzip
	//If you would like additional techniques, like lz4, lzfsfzse or lzma, please request them.
}


extension Data {
	
	/// One shot data compression wrapping .zlib functionality
	/// TODO: add ability to get crc/adler values from the compression
	public func compressed(using technique:CompressionTechnique = .deflate,
	                       progress:CompressionProgressHandler? = nil)throws->Data {
		switch technique {
		case .deflate:
			return try deflate(progress:progress).data
		case .gzip:
			return try gzip(progress: progress)
		}
	}
	
	/// To decompress data, with the given technique.  May throw a CompressionError
	public func decompressed(using technique:CompressionTechnique,
						progress:CompressionProgressHandler? = nil)throws->Data {
		switch technique {
		case .deflate:
			return try inflate(progress:progress)
		case .gzip :
			return try gunzip(progress:progress)
		}
	}
	
	/*
	//TODO: write me
	/// for stream-like writing to file
	public func decompress(using technique:CompressionTechnique, appendingTo handle:FileHandle)throws {
		///TODO: write me
	}
	*/
	
	/// compresses the receiver into a "deflate" stream, does not provide file headers
	/// returns the data & crc of the uncompressed data
	func deflate(progress:CompressionProgressHandler? = nil)throws->(data:Data, crc:UInt32) {
		var data:Data = Data()
		let crc:UInt32 = try deflate(accumulator: { (pointer, newByteCount) in
			data.append(pointer, count: newByteCount)
		}, progress: progress)
		return (data, crc)
	}
	
	///returns the CRC, the accumulator is called when uncompressed bytes are available, with the count of the bytes
	func deflate(accumulator:(UnsafePointer<UInt8>, Int)->(), progress:CompressionProgressHandler? = nil)throws->UInt32 {
		
		let chunkSize:Int = memoryPageSize
		let strategy:Int32 = 0	//default
		let compressionLevel:Int32 = -1	//default
		let memoryLevel:Int32 = 8	//how much internal memory is used
		
		//do the dual-buffer thing
		let inBufferMemory:UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
		defer {
			inBufferMemory.deallocate()
		}
		let inBufferPointer = UnsafeMutableBufferPointer(start: inBufferMemory, count: chunkSize)
		let outBufferMemory:UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
		defer {
			outBufferMemory.deallocate()
		}
		
		//pre-fill the inBuffer
		let countInBuffer:Int = Swift.min(chunkSize, self.count)
		let copiedByteCount:Int = self.copyBytes(to: inBufferPointer, from: 0..<countInBuffer)
		
		//init the stream
		var stream = z_stream(next_in: inBufferPointer.baseAddress,
		                      avail_in: UInt32(copiedByteCount),
		                      total_in: 0, next_out: nil, avail_out: 0,
		                      total_out: 0, msg: nil, state: nil, zalloc: nil,
		                      zfree: nil, opaque: nil, data_type: 0, adler: 0,
		                      reserved: 0)
		let windowBits:Int32 = -MAX_WBITS//(method == "gzip") ? MAX_WBITS + 16 : MAX_WBITS
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
		//TODO: support crc32
		var crc:UInt = CZlib.crc32(0, nil, 0)
		
		//loop over buffers
		var streamStatus:Int32 = Z_OK
		while streamStatus == Z_OK {
			//always provide at least a whole buffer of data
			let readBytes = Int(stream.total_in)
			let countInBuffer:Int = Swift.min(chunkSize, self.count - readBytes)
			let copiedByteCount:Int = self.copyBytes(to: inBufferPointer, from: readBytes..<(readBytes+countInBuffer))
			stream.next_in = inBufferPointer.baseAddress
			stream.avail_in = UInt32(copiedByteCount)
			stream.next_out = outBufferMemory
			stream.avail_out = UInt32(chunkSize)
			//actual deflation
			let previousTotalOut:Int = Int(stream.total_out)
			streamStatus = CZlib.deflate(&stream, copiedByteCount > 0 ? Z_NO_FLUSH : Z_FINISH)
			//check for errors
			if streamStatus != Z_OK && streamStatus != Z_STREAM_END  && streamStatus != Z_BUF_ERROR {
				throw CompressionError.fail(streamStatus)
			}
			let readByteCount:Int = copiedByteCount - Int(stream.avail_in)
			crc = crc32(crc, inBufferPointer.baseAddress, UInt32(readByteCount))
			//always copy out all written bytes
			let newOutByteCount:Int = Int(stream.total_out) - previousTotalOut
			accumulator(outBufferMemory, newOutByteCount)
		}
		return UInt32(crc)
	}
	
	
	
	// decompresses the receiver, assuming it is a "deflate" stream, not the contents of a .zip file, i.e. no local file header
	func inflate(progress:CompressionProgressHandler? = nil)throws->Data {
		//create the first buffer before initializing the stream... because backwards API's are wonderful :(
		let chunkSize:Int = memoryPageSize
		let inputBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: chunkSize)
		inputBuffer.initialize(repeating: 0)
		defer {
			inputBuffer.deallocate()
		}
		let availableByteCount:Int = Swift.min(self.count, chunkSize)
		_ = self.copyBytes(to: inputBuffer, from: 0..<availableByteCount)
		var aStream:z_stream = z_stream(next_in: inputBuffer.baseAddress, avail_in: UInt32(availableByteCount), total_in: 0, next_out: nil, avail_out: 0, total_out: 0, msg: nil, state: nil, zalloc: nil, zfree: nil, opaque: nil, data_type: 0, adler: 0, reserved: 0)
		let windowBits:Int32 = -15 //some kind of magic value
		let initResult:Int32 = inflateInit2_(&aStream, windowBits, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
		//Check for init errors
		if initResult != Z_OK {
			throw CompressionError.fail(initResult)
		}
		//defer clean up
		defer {
			inflateEnd(&aStream)
		}
		//prepare an output buffer
		let outputBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: chunkSize)
		outputBuffer.initialize(repeating: 0)
		defer {
			outputBuffer.deallocate()
		}
		var outputData:Data = Data()
		let floatCount:Float32 = Float32(self.count)
		var streamStatus:Int32 = Z_OK
		while streamStatus == Z_OK {
			//copy next buffer-full of data
			let remainingByteCount:Int = self.count - Int(aStream.total_in)
			let countOfBytesToCopy:Int = Swift.min(remainingByteCount, chunkSize)
			let copiedByteCount:Int = self.copyBytes(to: inputBuffer, from: Int(aStream.total_in)..<(Int(aStream.total_in)+countOfBytesToCopy))
			let oldTotalOut:UInt = aStream.total_out
			//update stream values
			aStream.next_in = inputBuffer.baseAddress
			aStream.avail_in = UInt32(copiedByteCount)
			aStream.next_out = outputBuffer.baseAddress
			aStream.avail_out = UInt32(chunkSize)
			//decompress
			streamStatus = CZlib.inflate(&aStream, Z_SYNC_FLUSH)
			//check for decompression errors
			if streamStatus != Z_STREAM_END && streamStatus != Z_OK {
				throw CompressionError.fail(streamStatus)
			}
			//collect new data
			let newOutputByteCount:UInt = aStream.total_out - oldTotalOut
			if copiedByteCount > 0 {
				outputData.append(outputBuffer.baseAddress!, count: Int(newOutputByteCount))
			}
			//update progress
			var shouldCancel:Bool = false
			progress?(Float32(aStream.total_in)/floatCount, &shouldCancel)
			if shouldCancel {
				throw CompressionError.canceled
			}
		}
		return outputData
	}
	
	
	
	
	func gunzip(progress:CompressionProgressHandler? = nil)throws->Data {
		//create the first buffer before initializing the stream... because backwards API's are wonderful :(
		let chunkSize:Int = memoryPageSize
		let inputBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: chunkSize)
		inputBuffer.initialize(repeating: 0)
		defer {
			inputBuffer.deallocate()
		}
		let availableByteCount:Int = Swift.min(self.count, chunkSize)
		_ = self.copyBytes(to: inputBuffer, from: 0..<availableByteCount)
		var aStream:z_stream = z_stream(next_in: inputBuffer.baseAddress, avail_in: UInt32(availableByteCount), total_in: 0, next_out: nil, avail_out: 0, total_out: 0, msg: nil, state: nil, zalloc: nil, zfree: nil, opaque: nil, data_type: 0, adler: 0, reserved: 0)
		let windowBits:Int32 = 15 | 16 //some kind of magic value
		let initResult:Int32 = inflateInit2_(&aStream, windowBits, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
		//Check for init errors
		if initResult != Z_OK {
			throw CompressionError.fail(initResult)
		}
		//defer clean up
		defer {
			inflateEnd(&aStream)
		}
		//prepare an output buffer
		let outputBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: chunkSize)
		outputBuffer.initialize(repeating: 0)
		defer {
			outputBuffer.deallocate()
		}
		var outputData:Data = Data()
		let floatCount:Float32 = Float32(self.count)
		var streamStatus:Int32 = Z_OK
		while streamStatus == Z_OK {
			//copy next buffer-full of data
			let remainingByteCount:Int = self.count - Int(aStream.total_in)
			let countOfBytesToCopy:Int = Swift.min(remainingByteCount, chunkSize)
			let copiedByteCount:Int = self.copyBytes(to: inputBuffer, from: Int(aStream.total_in)..<(Int(aStream.total_in)+countOfBytesToCopy))
			let oldTotalOut:UInt = aStream.total_out
			//update stream values
			aStream.next_in = inputBuffer.baseAddress
			aStream.avail_in = UInt32(copiedByteCount)
			aStream.next_out = outputBuffer.baseAddress
			aStream.avail_out = UInt32(chunkSize)
			//decompress
			streamStatus = CZlib.inflate(&aStream, Z_SYNC_FLUSH)
			//check for decompression errors
			if streamStatus != Z_STREAM_END && streamStatus != Z_OK {
				throw CompressionError.fail(streamStatus)
			}
			//collect new data
			let newOutputByteCount:UInt = aStream.total_out - oldTotalOut
			if copiedByteCount > 0 {
				outputData.append(outputBuffer.baseAddress!, count: Int(newOutputByteCount))
			}
			//update progress
			var shouldCancel:Bool = false
			progress?(Float32(aStream.total_in)/floatCount, &shouldCancel)
			if shouldCancel {
				throw CompressionError.canceled
			}
		}
		return outputData
	}
	
	
	func gzip(progress:CompressionProgressHandler? = nil)throws->Data {
		
		let chunkSize:Int = memoryPageSize
		let strategy:Int32 = 0	//default
		let compressionLevel:Int32 = -1	//default
		let memoryLevel:Int32 = 8	//how much internal memory is used
		
		//do the dual-buffer thing
		let inBufferPointer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: chunkSize)
		inBufferPointer.initialize(repeating: 0)
		let outBufferPointer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: chunkSize)
		outBufferPointer.initialize(repeating: 0)
		defer {
			inBufferPointer.deallocate()
			outBufferPointer.deallocate()
		}
		//pre-fill the inBuffer
		let countInBuffer:Int = Swift.min(chunkSize, self.count)
		let copiedByteCount:Int = self.copyBytes(to: inBufferPointer, from: 0..<countInBuffer)
		
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
		//loop over buffers
		var outData:Data = Data()
		var streamStatus:Int32 = Z_OK
		while streamStatus == Z_OK {
			//always provide at least a whole buffer of data
			let readBytes = Int(stream.total_in)
			let countInBuffer:Int = Swift.min(chunkSize, self.count - readBytes)
			let copiedByteCount:Int = self.copyBytes(to: inBufferPointer, from: readBytes..<(readBytes+countInBuffer))
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
			outData.append(outBufferPointer.baseAddress!, count: newOutByteCount)
		}
		return outData
	}
	
}
