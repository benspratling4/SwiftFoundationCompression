//
//  FileManager+Zipping.swift
//  FoundationZip
//
//  Created by Ben Spratling on 10/9/16.
//
//

import Foundation
import SwiftPatterns

extension FileManager {
	
	/// Given a .zip-format file, this function unzips all the files it contains into the provided directory, which it creates as necessary.  Any existing files are overwritten if needed.
	/// The optional `progress` handler provides a normalized progress as a Float32, (0.0...1.0)
	///	Cancellation of progress is done by setting the progress block's inout Bool to true
	/// Throws errors when:
	///		the original file does not exist
	///		the zlib has an error
	///		the disk runs out of space
	public func decompress(item compressedFile:URL, using technique:CompressionTechnique, into directory:URL, progress:CompressionProgressHandler? = nil)throws->[URL] {
		switch technique {
		case .deflate:
			return try unzip(item: compressedFile, into: directory, progress: progress)
		case .gzip:
			return try gunzip(item: compressedFile, into: directory, progress: progress)
		}
	}
	
	/// items must exist, item must be a file, which might be overwritten
	/// if using .deflate, either provide many file URL's (supported), or a single directory (TBD)
	public func compress(items:[URL], using technique:CompressionTechnique, to item:URL, progress:CompressionProgressHandler? = nil)throws {
		switch technique {
		case .deflate:
			try zip(items:items, to:item, progress:progress)
		case .gzip:
			try gzip(item: items, to: item, progress: progress)
		}
	}
	
	func zip(items:[URL], to item:URL, progress:CompressionProgressHandler?)throws {
		//unpack all path components
		let fullRelativePaths:[[String]] = items.map { (url) -> [String] in
			return url.pathComponents.filter { $0 != "/" }
		}
		
		let containingDirections:[[String]] = fullRelativePaths.map { (components) -> [String] in
			return [String](components.dropLast())
		}
		
		//find deepest common parent
		let commonParentLength:Int = longestCommonPrefix(of: containingDirections).count
		
		//get suffixes
		let suffixes:[[String]] = fullRelativePaths.map { (components) -> [String] in
			return [String](components.dropFirst(commonParentLength))
		}
		
		//form mappings
		var mappings:[URL:[String]] = [:]
		for i in 0..<items.count  {
			mappings[items[i]] = suffixes[i]
		}
		
		try zip(itemMappings: mappings, to: item, progress: progress)
	}
	
	func zip(itemMappings:[URL:[String]], to destination:URL, progress:CompressionProgressHandler?)throws {
		//migrate to filehandle writing
		let writer:ZipDataWriter = ZipDataWriter()
		
		for (url, pathComponents) in itemMappings {
			let data:Data = try Data(contentsOf: url)
			try writer.compress(data: data, path: pathComponents.joined(separator: "/"))
		}
		
		try writer.data.write(to: destination)
	}
	
	func unzip(item compressedFile:URL, into directory:URL, progress:CompressionProgressHandler? = nil)throws->[URL] {
		//TODO: add progress handling
		let zipData:Data = try Data(contentsOf: compressedFile)
		let zipWrapper = try ZipDirectoryWrapping(zippedData: zipData)
		return try writeSubResources(in:zipWrapper, into:directory)
	}
	
	//to be used recursively, creates directories as needed and overwrites
	private func writeSubResources(in wrapper:SubResourceWrapping, into directory:URL)throws->[URL] {
		//create the directory if needed
		var isDirectory:ObjCBool = false
		if !fileExists(atPath: directory.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
			try createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
		}
		var writtenURLs:[URL] = []
		for (_,resource) in wrapper.subResources {
			//TODO: parallelize?
			let subURL = directory.appendingPathComponent(resource.lastPathComponent)
			if let dataWrapper = resource as? DataWrapping {
				let data = dataWrapper.contents
				try data.write(to: subURL, options:[])
				writtenURLs.append(subURL)
			} else if let dirWrapper = resource as? SubResourceWrapping {
				writtenURLs.append(contentsOf: try writeSubResources(in: dirWrapper, into: subURL))
			}
		}
		return writtenURLs
	}
	
	func gunzip(item compressedFile:URL, into directory:URL, progress:CompressionProgressHandler? = nil)throws->[URL] {
		let gzipData:Data = try Data(contentsOf: compressedFile)
		let gzipper:GZipDataWrapping = try GZipDataWrapping(compressedData:gzipData)
		var unzippedName:String = gzipper.lastPathComponent
		if unzippedName.isEmpty {
			if compressedFile.pathExtension == "gz" {
				unzippedName = compressedFile.deletingLastPathComponent().lastPathComponent
			}
		}
		let targetURL:URL = directory.appendingPathComponent(unzippedName)
		//TODO: assuming slow write, create a randomly named temp file, write to it, and atomic replace?  is atomic replace a thing?
		try gzipper.contents.write(to: targetURL, options: .atomic)
		return [targetURL]
	}
	
	
	func gzip(item files:[URL], to destination:URL, progress:CompressionProgressHandler? = nil)throws {
		//In a gzip file, there can only be one
		guard let oneFile:URL = files.first, files.count == 1 else { throw CompressionError.unsupportedFormat }
		let fileWrapper = FileWrapping(data: Data(), name: "")	//I should be able to init this from a URL
		try fileWrapper.read(from: oneFile)
		let gzipper:GZipDataWrapping = try GZipDataWrapping(fileWrapper)
		try gzipper.serializedRepresentation.write(to: destination, options: [.atomicWrite])
	}
	
}

func longestCommonPrefix(of items:[[String]])->[String] {
	guard var longestCommonPrefix:[String] = items.first else { return [] }
	//there must be more than
	byItem: for item in items {
		//compare the first x elements
		let firstCount:Int = longestCommonPrefix.count
		let secondCount:Int = item.count
		let possibleElementCount:Int = min(firstCount, secondCount)
		if possibleElementCount < longestCommonPrefix.count {
			longestCommonPrefix = [String](longestCommonPrefix.prefix(through:possibleElementCount))
		}
		for i in 0 ..< possibleElementCount {
			if item[i] != longestCommonPrefix[i] {
				longestCommonPrefix = [String](longestCommonPrefix.prefix(upTo: i))
				continue byItem
			}
		}
	}
	return longestCommonPrefix
}
