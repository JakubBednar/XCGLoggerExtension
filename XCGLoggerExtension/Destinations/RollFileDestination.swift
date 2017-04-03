//
//  RollFileDestination.swift
//  LoggingXCGLogger
//

import XCGLogger

// MARK: - RollFileDestination
/// A destination that outputs log details to a file and does so correctly when multiple destinations use the same file (works in-process only)
open class RollFileDestination: OrderedFileDestination {
	
	/// Maximal size of one log file. Default is 1MB
	open var maximumFileSize: UInt64 = 1_048_576
	
	/// Maximal number of existing log files
	open var maximumFilesCount: UInt32 = 10
	
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
				
				self.logAppender?.write(encodedData, checkSize: self.maximumFileSize, rotateWithFilesCount: self.maximumFilesCount)
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
