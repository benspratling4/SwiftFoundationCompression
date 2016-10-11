//
//  FileHandle+Compression.swift
//  SwiftFoundationCompression
//
//  Created by Ben Spratling on 10/11/16.
//
//

import Foundation
import CZlib	//thanks, IBM!

extension FileHandle {
	/// compress the data and write it to the filehandle
	/// reading from Data is optimized when it is created, but not when written, use this to write out in an optimized way
	public func writeDecompressed(data:Data, using technique:CompressionTechnique, progress:CompressionProgressHandler? = nil)throws {
		switch technique {
		case .deflate:
			try writeInflated(data:data, progress: progress)
		}
	}
	
	public func writeCompressed(data:Data, using technique:CompressionTechnique, progress:CompressionProgressHandler? = nil)throws {
		switch technique {
		case .deflate:
			try writeDeflated(data:data, progress: progress)
		}
	}

	
	
	// decompresses the receiver, assuming it is a "deflate" stream, not the contents of a .zip file, i.e. no local file header
	func writeInflated(data:Data, progress:CompressionProgressHandler? = nil)throws {
		//create the first buffer before initializing the stream... because backwards API's are wonderful :(
		let chunkSize:Int = memoryPageSize
		var copyBuffer:[UInt8] = [UInt8](repeating:0, count:chunkSize)
		let inputBuffer = UnsafeMutableBufferPointer(start: &copyBuffer, count: chunkSize)
		let availableByteCount:Int = Swift.min(data.count, chunkSize)
		let copiedByteCount:Int = data.copyBytes(to: inputBuffer, from: 0..<availableByteCount)
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
		var decompressBuffer:[UInt8] = [UInt8](repeating:0, count:chunkSize)
		let outputBuffer = UnsafeMutableBufferPointer(start: &decompressBuffer, count: chunkSize)
		
		let floatCount:Float32 = Float32(data.count)
		var streamStatus:Int32 = Z_OK
		while streamStatus == Z_OK {
			//copy next buffer-full of data
			let remainingByteCount:Int = data.count - Int(aStream.total_in)
			let countOfBytesToCopy:Int = Swift.min(remainingByteCount, chunkSize)
			let copiedByteCount:Int = data.copyBytes(to: inputBuffer, from: Int(aStream.total_in)..<(Int(aStream.total_in)+countOfBytesToCopy))
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
				let tempData:Data = Data(bytes:outputBuffer.baseAddress!, count:Int(newOutputByteCount))
				self.write(tempData)
			}
			//update progress
			var shouldCancel:Bool = false
			progress?(Float32(aStream.total_in)/floatCount, &shouldCancel)
			if shouldCancel {
				throw CompressionError.canceled
			}
		}
	}
	
	
	/// compresses the receiver into a "deflate" stream, does not provide file headers
	func writeDeflated(data:Data, progress:CompressionProgressHandler? = nil)throws {
		
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
		//loop over buffers
		
		var streamStatus:Int32 = Z_OK
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
			let tempData:Data = Data(bytes:outBufferPointer.baseAddress!, count:Int(newOutByteCount))
			self.write(tempData)
		}
		
	}
	
}
