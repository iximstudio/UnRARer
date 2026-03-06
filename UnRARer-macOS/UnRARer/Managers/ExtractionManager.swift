import Foundation

/// Result of an extraction operation.
enum ExtractionResult {
    case success
    case needsPassword
    case failure(String)
}

/// Manages the extraction of RAR archives using the `unrar` command-line tool.
///
/// The `unrar` tool can be:
/// - Bundled inside the app bundle at `Contents/Resources/unrar`
/// - Installed system-wide via Homebrew (`/usr/local/bin/unrar` or `/opt/homebrew/bin/unrar`)
class ExtractionManager {

    private var currentProcess: Process?

    /// Locates the `unrar` executable.
    /// Searches in the app bundle first, then common system paths.
    func findUnrar() -> String? {
        // Check app bundle
        if let bundlePath = Bundle.main.path(forResource: "unrar", ofType: nil) {
            return bundlePath
        }

        // Check common installation paths
        let searchPaths = [
            "/usr/local/bin/unrar",
            "/opt/homebrew/bin/unrar",
            "/usr/bin/unrar"
        ]

        for path in searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try to find via `which`
        let whichProcess = Process()
        let pipe = Pipe()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["unrar"]
        whichProcess.standardOutput = pipe
        whichProcess.standardError = FileHandle.nullDevice

        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let path = path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        } catch {
            // Ignore
        }

        return nil
    }

    /// Extracts a RAR archive to the specified destination.
    ///
    /// - Parameters:
    ///   - rarFilePath: Path to the .rar file.
    ///   - destination: Directory to extract files into.
    ///   - password: Optional password for encrypted archives.
    /// - Returns: The result of the extraction operation.
    func extract(rarFilePath: String, destination: String, password: String?) -> ExtractionResult {
        guard let unrarPath = findUnrar() else {
            return .failure(
                "The 'unrar' tool was not found.\n\n" +
                "Please install it using Homebrew:\n" +
                "  brew install unrar\n\n" +
                "Or download it from:\n" +
                "  https://www.rarlab.com/rar_add.htm"
            )
        }

        // Create destination directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: destination) {
            do {
                try fileManager.createDirectory(
                    atPath: destination,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                return .failure("Failed to create destination directory:\n\(error.localizedDescription)")
            }
        }

        // Build unrar command
        // Usage: unrar x [-p<password>] <archive> <destination>/
        let process = Process()
        process.executableURL = URL(fileURLWithPath: unrarPath)

        var arguments = ["x", "-o+", "-y"]

        if let password = password, !password.isEmpty {
            arguments.append("-p\(password)")
        } else {
            // -p- means do not query password
            arguments.append("-p-")
        }

        arguments.append(rarFilePath)
        // Ensure destination ends with /
        let dest = destination.hasSuffix("/") ? destination : destination + "/"
        arguments.append(dest)

        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        currentProcess = process

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure("Failed to run unrar:\n\(error.localizedDescription)")
        }

        currentProcess = nil

        let exitCode = process.terminationStatus
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let standardOutput = String(data: outputData, encoding: .utf8) ?? ""

        switch exitCode {
        case 0:
            return .success
        default:
            // Check if it's a password error
            let combinedOutput = (standardOutput + errorOutput).lowercased()
            if combinedOutput.contains("password") ||
               combinedOutput.contains("encrypted") ||
               combinedOutput.contains("wrong password") ||
               combinedOutput.contains("corrupt file or wrong password") {
                if password == nil || password?.isEmpty == true {
                    return .needsPassword
                }
                return .failure("Incorrect password. Please try again.")
            }
            return .failure("Extraction failed (exit code \(exitCode)):\n\(errorOutput)\(standardOutput)")
        }
    }

    /// Cancels the current extraction operation.
    func cancelExtraction() {
        currentProcess?.terminate()
        currentProcess = nil
    }
}
