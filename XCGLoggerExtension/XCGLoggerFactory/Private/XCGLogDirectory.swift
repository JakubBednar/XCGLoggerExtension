//
//  LogDirectory.swift
//  LoggingXCGLogger
//

import Foundation

/// This class is responsible for providing URL for default loggig directory and creating it on demand
class XCGLogDirectory {
	
	private var checked = false
	public let url: URL = {
		// if the process is an admin process it needs to log to /Library/Logs/ instead of ~/Library/Logs
		let mask: FileManager.SearchPathDomainMask = (getuid()==0 ? .localDomainMask : .userDomainMask)
		// force unwrap here. I doubt that searching for ~/Library could fail in practise
		let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: mask).first!
		let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as! String
		return libraryURL.appendingPathComponent("Logs").appendingPathComponent(bundleName)
	}()

	public func create() throws {
		
		// avoid attempting to create the folder many times during application lifecycle
		guard !checked else { return }
		
		guard let _ = try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil) else {
			
			throw XCGLoggerFactoryErrors.systemError("Can't create log directory '\(url)'")
		}
		
		checked = true
	}
}
