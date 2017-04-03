//
//  LoggerFactory.swift
//  CleaningEngine
//

import Foundation
import XCGLogger

public enum XCGLoggerFactoryErrors: Error {
	case invalidConfig(String)
	case systemError(String)
}

/// Factory object providing XCGLogger objects based on configuration
/// 
/// 1. You provide configuration files using appendConfiguration() method. The format is described in XCGLoggersConfig.swift file
///    The configuration is added to previously passed configuration. If any configuration item in the file is invalid or conflicting, 
///    exception is thrown and the config file is discarded
/// 2. When asking for a logger, inheritance is used. e.g. if Logger.Framework is specified in config and you request Logger.Framework.ClassA, than you
///    will get a logger with identifier Logger.Framework.ClassA, but configuration of Logger.Framework.
///    In case all destinations of the logger fail to be created, you get a logger with no destinations. Reason for this is that failure in creating a logger
///    should not block any application from running and I do not want to return XCGLogger?

public class XCGLoggerFactory {
	
	private let logDirectory = XCGLogDirectory()
	private let config: XCGLoggersConfig	
	private let syncQueue = DispatchQueue(label: "XCGLoggerFactory", attributes: [.concurrent])
	
	static public let sharedInstance = XCGLoggerFactory()
	
	private init() {
	
		config = XCGLoggersConfig(withDirectory: logDirectory)
	}

	/// access to where the logs are stored. 
	/// Usefull e.g. for crash reporter that can pack the directory and send it with the crash
	public var logDirectoryURL: URL {
		get {
			return logDirectory.url
		}
	}
	
	public func appendConfiguration(fromURL url:URL) throws {
		
		guard let data = try? Data(contentsOf: url) else {
			throw XCGLoggerFactoryErrors.systemError("Failed to load data from '\(url)'")
		}
		
		guard let parsedData = try? JSONSerialization.jsonObject(with: data) else {
			
			throw XCGLoggerFactoryErrors.invalidConfig("Failed to parse JSON from '\(url)'")
		}
		
		guard let jsonData = parsedData as? [String : Any] else {
			
			throw XCGLoggerFactoryErrors.invalidConfig("JSON from '\(url)' is not an object")
		}
		
		try appendConfiguration(jsonData)
	}
	
	public func appendConfiguration(_ data: [String : Any]) throws {

		// set-up a barrier in the parallel queue to allow multiple readers but only one writer
		let block = {
			try self.config.appendConfiguration(data)
		}

		try syncQueue.sync(flags: .barrier, execute: block)
	}
	
	public func createLogger(withIdentifier identifier: String) -> XCGLogger {
	
		let logger = XCGLogger(identifier: identifier, includeDefaultDestinations: false)
		
		syncQueue.sync{
			var loggerName = identifier
			var loggerConfig: LoggerConfig?
		
			repeat {
				loggerConfig = config.loggers[loggerName]
				if loggerConfig != nil {
					break
				}
			
				// not found remove last '.' and suffix
				guard let lastDot = loggerName.range(of: ".", options: .backwards, range: nil, locale: nil) else {
					
					// no '.' remains
					break
				}
				
				loggerName = loggerName.substring(to: lastDot.lowerBound)
			} while true
		
			if loggerConfig == nil {
				loggerConfig = config.loggers["Root"]
			}
		
			// no configuration found, return logger with no destinations
			guard let cfg = loggerConfig else {
			
				return
			}
		
			for appenderName in cfg.appenders {
				guard let appenderConfig = config.appenders[appenderName] else {
					continue
				}
			
				guard let destination = try? appenderConfig.createDestination(forLogger: cfg) else {
					continue
				}
			
				logger.add(destination: destination)
			}
		}
		
		return logger
	}
}
