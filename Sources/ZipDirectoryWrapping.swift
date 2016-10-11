//
//  ZipDirectoryWrapping.swift
//  FoundationZip
//
//  Created by Ben Spratling on 10/9/16.
//
//

import Foundation
import CZlib
import SwiftPatterns

/**
	To represent a .zip-format file on disk as folders/files in RAM, instantiate a ZipDirectoryWrapping with zipped data.
	Using the conformance to `SubResourceWrapping`, browse for files inside.
	The sub resources, which conform to `DataWrapping`, are only decompressed when you access their .contents properties, then cached in RAM.  (They are implemented with an internal type.)
	Creating a .zip file by assembling SerializedResourceWrapping is not yet supported, but that is the intention.
*/
public class ZipDirectoryWrapping : SubResourceWrapping {
	
	private var underlyingRepresentation:SubResourceWrapping
	
	private var owner:ZippedDataOwner?	//present only if the file was initialized with zipped data
	
	/// if you want to unzip some data, use this
	public init(zippedData:Data)throws {
		//create an owner
		let owner = try ZippedDataOwner(data: zippedData)
		underlyingRepresentation = owner.createWrappers()
		self.owner = owner
		lastPathComponent = ""	//Generally, this is a root, and we don't bother with it
	}
	/*
	//TODO: conform to NSFilePresenter
	public init?(zipFile:URL) {
		guard let owner = try? ZippedURLOwner(zipFile: zipFile) else { return nil }
		underlyingRepresentation = owner.createWrappers()
		self.owner = owner
	}
	*/
	///if you want to zip some data which is already in a file/folder structure, use this
	/// not yet supported
	public init(directory:SubResourceWrapping) {
		self.underlyingRepresentation = directory
		lastPathComponent = directory.lastPathComponent
	}
	
	public weak var parentResourceWrapper:SubResourceWrapping?
	
	public var serializedRepresentation:Data {
		get {
			return (try? createZipFileData()) ?? Data()
		}
	}
	
	/// remember to set the parent's new name
	public var lastPathComponent:String
	
	
	public var subResources:[String:SerializedResourceWrapping] {
		get {
			return underlyingRepresentation.subResources
		}
	}
	
	public subscript(key:String)->SerializedResourceWrapping? {
		get {
			return underlyingRepresentation[key]
		}
		set {
			underlyingRepresentation[key] = newValue
		}
	}
	
	/// to keep names in synch
	public func child(named:String, changedNameTo:String) {
		//TODO: write me
		
	}
	
	//TODO: write the read/write methods
	//when writing to a URL, write the zipped data
	
	private func createZipFileData()throws->Data {
		//TODO: write me
		//iterate through all files:
		//writing a local header
		//zipping their data (copying zipped data if encountering a ZipDataWrapping)
		//collecting a central header and writing it out
		//appending a end of central dir header
		
		fatalError()
	}
	
	
}

/// used internally to represent a file in a zip file which can be uncompressed
/// once unzipped, this caches the unzipped data
/// it does not make a copy of the data, but relies on the ZippedDataOwner
/// many of these can own a ZippedDataOwner, and when you've freed them all, it is freed
class ZipDataWrapping : DataWrapping {
	
	weak var parentResourceWrapper:SubResourceWrapping?
	
	private let owner:ZippedDataOwner
	
	private let centralHeader:CentralDirectoryEntry
	
	var lastPathComponent: String
	
	init(owner:ZippedDataOwner, centralHeader:CentralDirectoryEntry) {
		self.owner = owner
		self.centralHeader = centralHeader
		lastPathComponent = centralHeader.fileName
	}
	
	private var unzippedData:Data?
	
	var contents: Data {
		get {
			if let existingData:Data = unzippedData {
				return existingData
			}
			let newlyDecompressedData:Data = (try? owner.inflated(file: centralHeader)) ?? Data()
			unzippedData = newlyDecompressedData
			return newlyDecompressedData
		}
		set {
			fatalError()
		}
	}
	
	var serializedRepresentation: Data {
		get {
			fatalError()
			//return try? owner.compressedData(at: centralHeader) ?? Data()
		}
	}
	
	//override the "write" method to stream data unzipping
	
	
}

extension ZippedDataOwner {
	/// iterates files in the data, and creates real directories wrapping ZipDataWrapping
	func createWrappers()->SubResourceWrapping {
		//iterate through all files, for any non
		let rootDirectory = DirectoryWrapping(wrappers:[:])
		for dirEntry in centralDirectoryEntries {
			//determine if the last entry is a dir
			if dirEntry.fileName.hasSuffix("/") {
				//we'll cover it later
				continue
			}
			//split the paths up into components
			var pathComponents:[String] = dirEntry.fileName.components(separatedBy:"/")
			let lastPathComponent = pathComponents.removeLast()
			let standIn = ZipDataWrapping(owner: self, centralHeader: dirEntry)
			standIn.lastPathComponent = lastPathComponent
			//create the standin
			var dir:SubResourceWrapping = rootDirectory
			for component in pathComponents {
				if let existingDir = dir.subResources[component] as? SubResourceWrapping {
					dir = existingDir
					continue
				}
				let newDir = DirectoryWrapping(wrappers: [:])
				dir[component] = newDir
				dir = newDir
			}
			dir[lastPathComponent] = standIn
		}
		return rootDirectory
	}
}
