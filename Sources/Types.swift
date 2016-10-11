//
//  Errors.swift
//  FoundationZip
//
//  Created by Ben Spratling on 10/9/16.
//
//

import Foundation

/// An error which may be thrown from one of the compression or decompression values
public enum CompressionError : Error {
	/// The bits are incompatible with the .zip spec
	case invalidFormat
	
	/// The file may be a valid format, but is not supported
	/// Examples include encryption, and compresions other than deflate
	case unsuppotedFormat
	
	case fileNotFound
	
	/// the process was canceled
	case canceled
	
	///Thrown when writing to disk
	case diskFull
	
	///Theoretically, you should get memory pressure warnings before this happens.
	case outOfMemory
	
	/// a zlib error code
	case fail(Int32)
}

/// provides a float from 0.0...1.0 for progress
/// set the Bool to true to cancel, ignore it to continue
/// make them _fast_, it will be called often
public typealias CompressionProgressHandler = (Float32, inout Bool)->()
