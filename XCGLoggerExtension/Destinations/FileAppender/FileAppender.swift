//
//  FileAppender.swift
//  XCGLogger
//

fileprivate let writesBetweenRotationCheck = 10

// MARK: - FileAppender
/// Class to encapsulate logging to single file URL. Multiple destinations share this class to correctly support multiple loggers writting to same file.
/// By sharing this instance, it also correctly supports automatic rotating of log files.
class FileAppender {
	
	private var logFileHandle: FileHandle? = nil
	private let syncQueue: DispatchQueue
	private let logFileURL: URL
	private var writes = 0
	
	init(withURL url: URL) throws {
	
		syncQueue = DispatchQueue(label: url.path)
		logFileURL = url
		
		logFileHandle = try self.openFile()
	}
	
	deinit {
		
		// let all data be written
		syncQueue.sync {
			self.logFileHandle?.closeFile()
		}
	}
	
	public func write(_ data: Data) {
		syncQueue.async {
			self.logFileHandle?.write(data)
		}
	}
	
	public func write(_ data: Data, checkSize maximumSize: UInt64, rotateWithFilesCount filesCount: UInt32) {
		syncQueue.async {
			self.logFileHandle?.write(data)
			self.checkFileSizeAndRotate(maximumSize: maximumSize, filesCount: filesCount)
		}
	}
	
	private func openFile() throws -> FileHandle {
		
		let fileManager = FileManager.default
		let fileExists = fileManager.fileExists(atPath: logFileURL.path)
		if !fileExists {
			fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
		}
		
		let fileHandle = try FileHandle(forWritingTo: logFileURL)
		if fileExists {
			fileHandle.seekToEndOfFile()
		}
		
		return fileHandle
	}
	
	private func checkFileSizeAndRotate(maximumSize: UInt64, filesCount: UInt32) {
		
		if writes < writesBetweenRotationCheck {
			writes += 1
			return
		}
		
		writes = 0
		
		let fileManager = FileManager.default
		var fileSize: UInt64 = 0
		
		if let attr = try? fileManager.attributesOfItem(atPath: logFileURL.path) {
			fileSize = attr[.size] as? UInt64 ?? 0
		}
		
		if fileSize > maximumSize {
			
			// close current handle
			self.logFileHandle?.closeFile()
			
			// rotate the files
			rotateFiles(filesCount: filesCount, usingManager: fileManager)
			
			// open new handle
			logFileHandle = try? openFile()
		}
	}
	
	private func rotateFiles(filesCount: UInt32, usingManager fileManager: FileManager) {
		
		let fileExtension = logFileURL.pathExtension
		let filePath = logFileURL.deletingPathExtension()
		
		// remove the top-most log file as move operation fails if destination exists
		var destinationURL = URL(fileURLWithPath: filePath.path + "\(filesCount-1)").appendingPathExtension(fileExtension)
		try? fileManager.removeItem(at: destinationURL)
		
		for fileNumber in (1...filesCount-2).reversed() {
			
			let sourceURL = URL(fileURLWithPath: filePath.path + "\(fileNumber)").appendingPathExtension(fileExtension)
			try? fileManager.moveItem(at: sourceURL, to: destinationURL)
			destinationURL = sourceURL
		}
		
		// now move the file we have just closed
		guard let _ = try? fileManager.moveItem(at: logFileURL, to: destinationURL) else {
			// in case the move fails, erase the current logFile
			// so it does not grow out of bounds
			try? fileManager.removeItem(at: logFileURL)
			return
		}
	}
}
