import Foundation
import os.log

/// Simple logging utility for GabGab
public struct GabGabLogger {
    private static let subsystem = "com.gabgab"
    private static let category = "MLXVoice"
    
    private static let logger = Logger(
        subsystem: subsystem,
        category: category
    )
    
    public static func info(_ message: String) {
        logger.info("\(message)")
    }
    
    public static func error(_ message: String) {
        logger.error("\(message)")
    }
    
    public static func debug(_ message: String) {
        logger.debug("\(message)")
    }
}
