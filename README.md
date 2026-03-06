# UnRARer

RAR file decompression tool for macOS and Windows.

When you double-click a `.rar` file, UnRARer presents a dialog to confirm the extraction destination (defaulting to a new folder with the same name as the archive in the current directory). If the archive is password-protected, a password input field is provided. After confirmation the archive is extracted to the chosen location, and the app exits automatically on success.

## macOS Version

### Requirements

- macOS 12.0 or later
- Xcode 15+ (to build)
- `unrar` command-line tool (install via [Homebrew](https://brew.sh/)): `brew install unrar`
  - Alternatively, download from [rarlab.com](https://www.rarlab.com/rar_add.htm) and place the `unrar` binary in the app bundle's `Contents/Resources/` directory.

### Build

1. Open `UnRARer-macOS/UnRARer.xcodeproj` in Xcode.
2. Select the **UnRARer** scheme and your Mac as the destination.
3. Build and run with **⌘R**, or archive for distribution with **Product → Archive**.

### Usage

- **Double-click** a `.rar` file to launch UnRARer (after setting it as the default app for `.rar` files).
- Or launch UnRARer directly and use the file picker to select a `.rar` file.
- Choose the extraction destination (defaults to a new folder named after the archive).
- Enter a password if the archive is encrypted.
- Click **Extract** — the files will be extracted and Finder will open the destination folder.

### Setting as Default App

1. Right-click any `.rar` file in Finder.
2. Select **Get Info**.
3. Under **Open with**, choose **UnRARer**.
4. Click **Change All...** to set it as the default for all `.rar` files.

### Project Structure

```
UnRARer-macOS/
├── UnRARer.xcodeproj/          # Xcode project
└── UnRARer/
    ├── AppDelegate.swift        # App entry point, file open handling
    ├── Info.plist               # App configuration, UTI declarations for .rar
    ├── UnRARer.entitlements     # App permissions
    ├── Views/
    │   └── ExtractionDialogController.swift  # Extraction settings dialog
    ├── Managers/
    │   └── ExtractionManager.swift           # RAR extraction logic (calls unrar)
    └── Assets.xcassets/         # App icons
```

---

## Windows Version

### Requirements

- Windows 10 or later
- [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) (to build)

### Build

```bash
cd UnRARer-Windows/UnRARer
dotnet restore
dotnet build -c Release
```

The output will be in `UnRARer-Windows/UnRARer/bin/Release/net8.0-windows/`.

To publish as a self-contained single-file executable:

```bash
dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true
```

### Usage

- **Double-click** a `.rar` file to launch UnRARer (after setting up file association).
- Or launch `UnRARer.exe` directly and use the file picker to select a `.rar` file.
- Choose the extraction destination (defaults to a new folder named after the archive).
- Enter a password if the archive is encrypted.
- Click **Extract** — the files will be extracted and Explorer will open the destination folder.

### File Association Setup

Run the included `setup-file-association.bat` script (as Administrator) from the directory containing `UnRARer.exe`:

```bash
cd UnRARer-Windows
setup-file-association.bat
```

This registers `.rar` files to open with UnRARer when double-clicked.

### Project Structure

```
UnRARer-Windows/
├── setup-file-association.bat   # Sets .rar file association in Windows
└── UnRARer/
    ├── UnRARer.csproj           # .NET project file (references SharpCompress)
    ├── App.xaml / App.xaml.cs   # Application entry point
    ├── MainWindow.xaml / .cs    # Main extraction dialog UI
    ├── ExtractionManager.cs     # RAR extraction logic (uses SharpCompress)
    └── AssemblyInfo.cs          # Assembly metadata
```

---

## How It Works

1. The app is launched when the user double-clicks a `.rar` file (or selects one via the file picker).
2. A dialog is shown with:
   - The archive file name
   - A destination folder path (defaulting to a new folder with the same name as the `.rar` file)
   - A browse button to change the destination
   - A password field (for encrypted archives)
3. On clicking **Extract**:
   - The destination folder is created if it doesn't exist.
   - The archive is extracted to the destination.
   - If a password is required but not provided, the user is prompted.
   - On success, the destination folder is opened in Finder (macOS) or Explorer (Windows), and the app exits.
   - On failure, an error message is displayed.

## License

This project uses the following third-party components:
- **unrar** (macOS): Free for use, see [rarlab.com](https://www.rarlab.com/rar_add.htm)
- **SharpCompress** (Windows): MIT License

