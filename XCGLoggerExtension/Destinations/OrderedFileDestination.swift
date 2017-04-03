//
//  OrderedFileDestination.swift
//  XCGLogger
//

import XCGLogger

// MARK: - OrderedFileDestination
/// A destination that outputs log details to a file and does so correctly when multiple destinations use the same file (works in-process only)
open class OrderedFileDestination: BaseDestination {
	// MARK: - Properties
	/// Logger that owns the destination object
	open override var owner: XCGLogger? {
		didSet {
			if owner != nil {
				createAppender()
			}
		}
	}
	
	/// The dispatch queue to process the log on
	open var logQueue: DispatchQueue? = nil
	
	/// FileURL of the file to log to
	open var writeToFileURL: URL? = nil {
		didSet {
			createAppender()
		}
	}
	
	/// File handle for the log file
	internal var logAppender: FileAppender? = nil
	
	// MARK: - Life Cycle
	public init(owner: XCGLogger? = nil, writeToFile: Any, identifier: String = "") {
		
		if let path = writeToFile as? String {
			writeToFileURL = URL(fileURLWithPath: path)
		} else {
			writeToFileURL = writeToFile as? URL
		}
		
		super.init(owner: owner, identifier: identifier)
		
		if owner != nil {
			createAppender()
		}
	}
	
	// MARK: - File Handling Methods
	/// Open the log file for writing.
	///
	/// - Parameters:   None
	///
	/// - Returns:  Nothing
	///
	private func createAppender() {
		
		if let writeToFileURL = writeToFileURL {
						
			logAppender = FileAppenderFactory.sharedInstance.appender(forURL: writeToFileURL)
		}
	}
	
	// MARK: - Overridden Methods
	/// Write the log to the log file.
	///
	/// - Parameters:
	///     - logDetails:   The log details.
	///     - message:         Formatted/processed message ready for output.
	///
	/// - Returns:  Nothing
	///
	open override func output(logDetails: LogDetails, message: String) {
		
		let outputClosure = {
			var logDetails = logDetails
			var message = message
			
			// Apply filters, if any indicate we should drop the message, we abort before doing the actual logging
			if self.shouldExclude(logDetails: &logDetails, message: &message) {
				return
			}
			
			self.applyFormatters(logDetails: &logDetails, message: &message)
			
			if let encodedData = "\(message)\n".data(using: String.Encoding.utf8) {
				
					self.logAppender?.write(encodedData)
			}
		}
		
		if let logQueue = logQueue {
			logQueue.async(execute: outputClosure)
		}
		else {
			outputClosure()
		}
	}
}
