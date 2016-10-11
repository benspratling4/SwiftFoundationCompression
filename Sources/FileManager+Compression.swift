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
	public func decompress(item zipFile:URL, with:CompressionTechnique, into directory:URL, progress:CompressionProgressHandler? = nil)throws {
		//TODO: add progress handling
		let zipData:Data = try Data(contentsOf: zipFile)
		let zipWrapper = try ZipDirectoryWrapping(zippedData: zipData)
		try writeSubResources(in:zipWrapper, into:directory)
	}
	
	//to be used recursively, creates directories as needed and overwrites
	private func writeSubResources(in wrapper:SubResourceWrapping, into directory:URL)throws {
		//create the directory if needed
		var isDirectory:ObjCBool = false
		if !fileExists(atPath: directory.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
			try createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
		}
		for (_,resource) in wrapper.subResources {
			//TODO: parallelize?
			let subURL = directory.appendingPathComponent(resource.lastPathComponent)
			if let dataWrapper = resource as? DataWrapping {
				let data = dataWrapper.contents
				try data.write(to: subURL, options:[])
			} else if let dirWrapper = resource as? SubResourceWrapping {
				try writeSubResources(in: dirWrapper, into: subURL)
			}
		}
	}
	
	/*
	/// Given an array of regular file URL's, write them all into a .zip file using the deepest common ancestor as the implied directory into the given `file:URL`.  If it exits, it is overritten.
	/// Throws errors when any original file does not exist, , if writing to the supplied URL fails, or if there is an internal zlib error
	public func compress(items:[URL], with:CompressionTechnique, to file:URL, progress:CompressionProgressHandler? = nil)throws {
		//TODO: write me
	}
	
	/// zips a regular file, or a directory and all its contents into a zip file at the given URL
	public func compress(item file:URL, with:CompressionTechnique, to zippedFile:URL, progress:CompressionProgressHandler? = nil)throws {
		//TODO: write me
	}
	
*/
}

