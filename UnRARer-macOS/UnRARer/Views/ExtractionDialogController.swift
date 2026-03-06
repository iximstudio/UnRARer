import Cocoa

/// Dialog controller for configuring RAR extraction settings.
/// Shows the destination folder and optional password input.
class ExtractionDialogController: NSWindowController {

    var onExtract: ((String, String?) -> Void)?
    var onCancel: (() -> Void)?

    private let rarFilePath: String
    private var destinationPath: String
    private var destinationTextField: NSTextField!
    private var passwordTextField: NSSecureTextField!
    private var showPasswordCheckbox: NSButton!

    init(rarFilePath: String, defaultDestination: String) {
        self.rarFilePath = rarFilePath
        self.destinationPath = defaultDestination

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Extract RAR Archive"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let margin: CGFloat = 20
        let fieldHeight: CGFloat = 24
        var currentY: CGFloat = 180

        // File info label
        let fileLabel = NSTextField(labelWithString: "Archive: \(URL(fileURLWithPath: rarFilePath).lastPathComponent)")
        fileLabel.frame = NSRect(x: margin, y: currentY, width: 460, height: fieldHeight)
        fileLabel.font = NSFont.boldSystemFont(ofSize: 13)
        contentView.addSubview(fileLabel)
        currentY -= 36

        // Destination label
        let destLabel = NSTextField(labelWithString: "Extract to:")
        destLabel.frame = NSRect(x: margin, y: currentY, width: 460, height: fieldHeight)
        contentView.addSubview(destLabel)
        currentY -= 28

        // Destination text field + Browse button
        destinationTextField = NSTextField(string: destinationPath)
        destinationTextField.frame = NSRect(x: margin, y: currentY, width: 360, height: fieldHeight)
        destinationTextField.isEditable = true
        destinationTextField.isSelectable = true
        contentView.addSubview(destinationTextField)

        let browseButton = NSButton(title: "Browse...", target: self, action: #selector(browseTapped))
        browseButton.frame = NSRect(x: 390, y: currentY - 2, width: 90, height: 28)
        browseButton.bezelStyle = .rounded
        contentView.addSubview(browseButton)
        currentY -= 36

        // Password label
        let passLabel = NSTextField(labelWithString: "Password (if required):")
        passLabel.frame = NSRect(x: margin, y: currentY, width: 460, height: fieldHeight)
        contentView.addSubview(passLabel)
        currentY -= 28

        // Password field
        passwordTextField = NSSecureTextField(frame: NSRect(x: margin, y: currentY, width: 360, height: fieldHeight))
        passwordTextField.placeholderString = "Enter password (leave blank if none)"
        contentView.addSubview(passwordTextField)
        currentY -= 40

        // Buttons
        let extractButton = NSButton(title: "Extract", target: self, action: #selector(extractTapped))
        extractButton.frame = NSRect(x: 380, y: currentY, width: 100, height: 32)
        extractButton.bezelStyle = .rounded
        extractButton.keyEquivalent = "\r"
        contentView.addSubview(extractButton)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.frame = NSRect(x: 270, y: currentY, width: 100, height: 32)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)
    }

    @objc private func browseTapped() {
        let panel = NSOpenPanel()
        panel.title = "Choose Extraction Destination"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        // Set initial directory to current destination's parent
        let currentDest = URL(fileURLWithPath: destinationTextField.stringValue)
        panel.directoryURL = currentDest.deletingLastPathComponent()

        if panel.runModal() == .OK, let url = panel.url {
            destinationTextField.stringValue = url.path
        }
    }

    @objc private func extractTapped() {
        let destination = destinationTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Invalid Destination"
            alert.informativeText = "Please specify a valid extraction destination."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let password = passwordTextField.stringValue
        window?.close()
        onExtract?(destination, password.isEmpty ? nil : password)
    }

    @objc private func cancelTapped() {
        window?.close()
        onCancel?()
    }
}
