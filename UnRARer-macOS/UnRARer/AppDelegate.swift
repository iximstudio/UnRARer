import Cocoa

/// Custom document controller that intercepts RAR file opening.
/// Without this, NSDocumentController tries to open RAR files as NSDocument
/// instances, which fails because no NSDocument subclass exists for RAR files,
/// resulting in "UnRARer cannot open files in the 'RAR Archive' format."
class RARDocumentController: NSDocumentController {
    override func openDocument(withContentsOf url: URL, display displayDocument: Bool, completionHandler: @escaping (NSDocument?, Bool, (any Error)?) -> Void) {
        if url.pathExtension.lowercased() == "rar" {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.handleOpenRAR(url.path)
            }
            completionHandler(nil, false, nil)
        } else {
            super.openDocument(withContentsOf: url, display: displayDocument, completionHandler: completionHandler)
        }
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var filesToExtract: [String] = []
    private var hasFinishedLaunching = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register custom document controller before any documents are opened.
        // The first NSDocumentController instance created becomes the shared one.
        _ = RARDocumentController()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hasFinishedLaunching = true

        // If no files were passed via open events, check command-line arguments
        if filesToExtract.isEmpty {
            let args = CommandLine.arguments
            // Skip the first argument (executable path)
            for i in 1..<args.count {
                let path = args[i]
                if path.lowercased().hasSuffix(".rar") {
                    filesToExtract.append(path)
                }
            }
        }

        if filesToExtract.isEmpty {
            // No file to extract — show an open panel
            let panel = NSOpenPanel()
            panel.title = "Select a RAR file to extract"
            panel.allowedContentTypes = [.init(filenameExtension: "rar")!]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true

            if panel.runModal() == .OK, let url = panel.url {
                filesToExtract.append(url.path)
            } else {
                NSApplication.shared.terminate(nil)
                return
            }
        }

        // Process the first file
        if let filePath = filesToExtract.first {
            showExtractionDialog(for: filePath)
        }
    }

    /// Called by RARDocumentController when a RAR file is opened via double-click
    /// or other system file-opening mechanisms.
    func handleOpenRAR(_ path: String) {
        filesToExtract.append(path)
        if hasFinishedLaunching {
            showExtractionDialog(for: path)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if filename.lowercased().hasSuffix(".rar") {
            filesToExtract.append(filename)
            // If app is already running, show dialog immediately
            if sender.isRunning {
                showExtractionDialog(for: filename)
            }
            return true
        }
        return false
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let rarFiles = filenames.filter { $0.lowercased().hasSuffix(".rar") }
        filesToExtract.append(contentsOf: rarFiles)

        if sender.isRunning, let first = rarFiles.first {
            showExtractionDialog(for: first)
        }
    }

    // MARK: - Extraction Dialog

    private func showExtractionDialog(for filePath: String) {
        let fileURL = URL(fileURLWithPath: filePath)
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let parentDir = fileURL.deletingLastPathComponent().path
        let defaultDestination = (parentDir as NSString).appendingPathComponent(fileName)

        let dialog = ExtractionDialogController(
            rarFilePath: filePath,
            defaultDestination: defaultDestination
        )
        dialog.onExtract = { [weak self] destination, password in
            self?.performExtraction(
                filePath: filePath,
                destination: destination,
                password: password
            )
        }
        dialog.onCancel = {
            NSApplication.shared.terminate(nil)
        }
        dialog.showWindow(nil)
        dialog.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Extraction

    private func performExtraction(filePath: String, destination: String, password: String?) {
        let manager = ExtractionManager()

        // Show a progress indicator
        let alert = NSAlert()
        alert.messageText = "Extracting..."
        alert.informativeText = "Please wait while the archive is being extracted."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Cancel")

        let progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 300, height: 20))
        progressIndicator.isIndeterminate = true
        progressIndicator.style = .bar
        progressIndicator.startAnimation(nil)
        alert.accessoryView = progressIndicator

        // Run extraction in background
        DispatchQueue.global(qos: .userInitiated).async {
            let result = manager.extract(
                rarFilePath: filePath,
                destination: destination,
                password: password
            )

            DispatchQueue.main.async {
                // Close progress alert if shown
                NSApp.abortModal()

                switch result {
                case .success:
                    // Open the destination folder in Finder
                    NSWorkspace.shared.open(URL(fileURLWithPath: destination))
                    NSApplication.shared.terminate(nil)

                case .needsPassword:
                    self.showPasswordPrompt(filePath: filePath, destination: destination)

                case .failure(let message):
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Extraction Failed"
                    errorAlert.informativeText = message
                    errorAlert.alertStyle = .critical
                    errorAlert.addButton(withTitle: "OK")
                    errorAlert.runModal()
                    NSApplication.shared.terminate(nil)
                }
            }
        }

        // Show modal (will be aborted when extraction completes)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User clicked Cancel
            manager.cancelExtraction()
        }
    }

    private func showPasswordPrompt(filePath: String, destination: String) {
        let alert = NSAlert()
        alert.messageText = "Password Required"
        alert.informativeText = "This archive is password protected. Please enter the password:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Extract")
        alert.addButton(withTitle: "Cancel")

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        passwordField.placeholderString = "Enter password"
        alert.accessoryView = passwordField
        alert.window.initialFirstResponder = passwordField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let password = passwordField.stringValue
            if !password.isEmpty {
                performExtraction(filePath: filePath, destination: destination, password: password)
            } else {
                showPasswordPrompt(filePath: filePath, destination: destination)
            }
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
}
