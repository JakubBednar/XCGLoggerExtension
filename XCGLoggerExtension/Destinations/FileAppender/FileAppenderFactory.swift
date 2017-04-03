//
//  FileAppenderFactory.swift
//  XCGLogger
//

import Foundation

//!< @brief Singleton class providing same instance of fileAppenders to multiple destinations if configured for same path
class FileAppenderFactory {
	
	static let sharedInstance = FileAppenderFactory()
	
	private var appenders = NSMapTable<NSString,FileAppender>.strongToWeakObjects()
	private let syncQueue = DispatchQueue(label: "XCGLogger.FileAppenderFactory")
	
	private init() {}
	
	public func appender(forURL url: URL) -> FileAppender? {
		
		var appender: FileAppender?
		
		syncQueue.sync {
			
			if let existingAppender = self.appenders.object(forKey: url.path as NSString) {
				appender = existingAppender
			} else {
				
				if let newAppender = try? FileAppender(withURL: url) {
					
					appenders.setObject(newAppender, forKey: url.path as NSString)
					appender = newAppender
				}
			}
		}
		
		return appender
	}
}
