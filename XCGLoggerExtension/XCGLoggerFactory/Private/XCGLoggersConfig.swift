//
//  LoggerConfig.swift
//  CleaningEngine
//

import Foundation
import XCGLogger


/// The log files config is structured as a case-sensitive JSON object.
/// Both the appenders section and loggers section might be missing in the configuration file.
/// In case of any error in the configuration file, no configuration will be stored
/// { 
///		appenders: {
///					"ConsoleAppender": {
///						"type": "console",
///					},
///					"FileAppender" : {
///						"type": "file",
///						"file":	"output.log"
///					},
///					"RollAppender" {
///						"type": "rollFile",
///						"maxSize" : 1024,
///						"maxCount": 10
///					}
///		},
///		loggers:   {
///					"Root" : {
///						"severity": "info"
///						"appenders": [ "ConsoleAppender" ]
///					}
///		}
/// }
///

fileprivate let TypeKey = "type"
fileprivate let FileNameKey = "file"
fileprivate let SizeKey = "maxSize"
fileprivate let CountKey = "maxCount"
fileprivate let SeverityKey = "severity"
fileprivate let AppendersKey = "appenders"
fileprivate let LoggersKey = "loggers"

// class representing single Logger configuration
struct LoggerConfig {
	
	public let name: String
	public let severity: XCGLogger.Level
	public let appenders: [String]
	
	init(withName name: String, data: [String : Any]) throws {
	
		self.name = name
		
		guard let lvl = data[SeverityKey] as? String else {
			
			throw XCGLoggerFactoryErrors.invalidConfig("Invalid '\(SeverityKey)' data type for logger '\(name)'")
		}
		
		switch lvl {
			case "none": severity = .none
			case "fatal": severity = .severe
			case "error": severity = .error
			case "warning": severity = .warning
			case "info": severity = .info
			case "debug": severity = .debug
			case "detail": severity = .verbose
			default: severity = .info
		}
		
		guard let destinations = data[AppendersKey] as? [String] else {
			throw XCGLoggerFactoryErrors.invalidConfig("Invalid '\(AppendersKey)' data type for logger '\(name)'")
		}
		
		appenders = destinations
	}
}

// class representing single Appender configuration
struct AppenderConfig {
	
	//!< declarations
	private enum AppenderTypes: String {
		case console = "console"
		case file = "file"
		case rollFile = "rollFile"
	}
	
	//<! members
	private let name: String
	private let directory: XCGLogDirectory
	
	private let type: AppenderTypes
	private var file: String = ""
	private var maxSize: UInt64 = 0
	private var maxCount: UInt32 = 0
	
	init(withName name: String, data: [String : Any], logDirectory: XCGLogDirectory) throws {

		self.name = name
		self.directory = logDirectory
		
		guard let typeName = data[TypeKey] as? String else {
			throw XCGLoggerFactoryErrors.invalidConfig("Invalid '\(TypeKey)' data type for appender '\(name)'")
		}
		
		guard let type = AppenderTypes(rawValue: typeName) else {
			throw XCGLoggerFactoryErrors.invalidConfig("Invalid '\(TypeKey)' value for appender '\(name)'")
		}
		self.type = type
		
		if type != .console {
		
			guard let file = data[FileNameKey] as? String else {
				throw XCGLoggerFactoryErrors.invalidConfig("Invalid '\(FileNameKey)' data type for appender '\(name)'")
			}
			self.file = file
		}
		
		if type == .rollFile {
			
			guard let maxSize = data[SizeKey] as? NSNumber else {
				throw XCGLoggerFactoryErrors.invalidConfig("Invalid '\(SizeKey)' data type for appender '\(name)'")
			}
			self.maxSize = UInt64(maxSize)
			
			guard let maxCount = data[CountKey] as? NSNumber else {
				throw XCGLoggerFactoryErrors.invalidConfig("Invalid '\(CountKey)' data type for appender '\(name)'")
			}
			self.maxCount = UInt32(maxCount)
		}
	}
	
	public func createDestination(forLogger logger: LoggerConfig) throws -> DestinationProtocol {
		
		let identifier = logger.name + "." + name
		var destination: BaseDestination
		
		switch type {
		case .console:
			destination = AppleSystemLogDestination(identifier: identifier)
		case .file:
			// try to create the directory as we need to add files to it
			try directory.create()
			destination = OrderedFileDestination(writeToFile: directory.url.appendingPathComponent(file), identifier: identifier)
		case .rollFile:
			// try to create the directory as we need to add files to it
			try directory.create()
			destination = RollFileDestination(writeToFile: directory.url.appendingPathComponent(file), identifier: identifier)
		}
		
		setupDestination(destination, withLevel: logger.severity)
		return destination
	}
	
	private func setupDestination(_ destination: BaseDestination, withLevel level: XCGLogger.Level) {
		
		destination.outputLevel = level
		destination.showLogIdentifier = true
		destination.showFunctionName = false
		destination.showFileName = true
		destination.showLineNumber = true
		destination.showLevel = true
	}
}

/// class holding all loaded configurations for XCGLoggers
class XCGLoggersConfig {
	
	public var appenders = [String : AppenderConfig]()
	public var loggers = [String : LoggerConfig]()
	private let logDirectory: XCGLogDirectory
	
	public init(withDirectory directory: XCGLogDirectory) {
		logDirectory = directory
	}
	
	public func appendConfiguration(_ jsonData: [String : Any]) throws {
		
		var tmpAppenders = [String : AppenderConfig]()
		var tmpLoggers = [String : LoggerConfig]()
		
		if let destinationData = jsonData[AppendersKey] {
			
			guard let checkedDestinations = destinationData as? [String : Any] else {
				throw XCGLoggerFactoryErrors.invalidConfig("Invalid '\(AppendersKey)' data type")
			}
			
			for (name, config) in checkedDestinations {

				// don't re-configure existing appender
				if let _ = appenders[name] {
					throw XCGLoggerFactoryErrors.invalidConfig("Appender '\(name)' already exists.")
				}
				
				guard let checkedConfig = config as? [String : Any] else {
					throw XCGLoggerFactoryErrors.invalidConfig("Invalid data type for appender '\(name)'")
				}
				
				let destination = try AppenderConfig(withName: name, data: checkedConfig, logDirectory: logDirectory)
				tmpAppenders[name] = destination
			}
		}
		
		if let loggersData = jsonData[LoggersKey] {
			
			guard let loggersConfig = loggersData as? [String : Any] else {
				throw XCGLoggerFactoryErrors.invalidConfig("Invalid '\(LoggersKey)' data type")
			}
		
			for (name, config) in loggersConfig {
			
				// don't re-configure existing logger
				if let _ = loggers[name] {
					throw XCGLoggerFactoryErrors.invalidConfig("Logger '\(name)' already exists.")
				}
			
				guard let checkedConfig = config as? [String : Any] else {
					throw XCGLoggerFactoryErrors.invalidConfig("Invalid data type for logger '\(name)'")
				}
			
				let loggerConfig = try LoggerConfig(withName: name, data: checkedConfig)
				tmpLoggers[name] = loggerConfig
			}
		}
		
		// all ok, put loaded data into the configuration
		tmpAppenders.forEach { appenders[$0] = $1 }
		tmpLoggers.forEach { loggers[$0] = $1 }
	}
}
