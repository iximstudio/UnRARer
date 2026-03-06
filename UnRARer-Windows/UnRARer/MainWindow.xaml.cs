using System.IO;
using System.Windows;
using Microsoft.Win32;

namespace UnRARer;

/// <summary>
/// Main window for the UnRARer extraction tool.
/// Shows destination folder selection, optional password input, and extraction controls.
/// </summary>
public partial class MainWindow : Window
{
    private string? _rarFilePath;
    private CancellationTokenSource? _cancellationTokenSource;

    public MainWindow(string? rarFilePath)
    {
        InitializeComponent();

        if (!string.IsNullOrEmpty(rarFilePath))
        {
            SetRarFile(rarFilePath);
        }
        else
        {
            // Prompt user to select a file
            PromptForFile();
        }
    }

    private void SetRarFile(string filePath)
    {
        _rarFilePath = filePath;
        var fileName = Path.GetFileNameWithoutExtension(filePath);
        var parentDir = Path.GetDirectoryName(filePath) ?? "";
        var defaultDestination = Path.Combine(parentDir, fileName);

        FileInfoLabel.Text = $"Archive: {Path.GetFileName(filePath)}";
        DestinationTextBox.Text = defaultDestination;
    }

    private void PromptForFile()
    {
        var dialog = new OpenFileDialog
        {
            Title = "Select a RAR file to extract",
            Filter = "RAR Archives (*.rar)|*.rar|All Files (*.*)|*.*",
            FilterIndex = 1
        };

        if (dialog.ShowDialog() == true)
        {
            SetRarFile(dialog.FileName);
        }
        else
        {
            Application.Current.Shutdown();
        }
    }

    private void BrowseButton_Click(object sender, RoutedEventArgs e)
    {
        // Use OpenFolderDialog via FolderBrowserDialog workaround
        var dialog = new OpenFolderDialog
        {
            Title = "Choose Extraction Destination"
        };

        if (!string.IsNullOrEmpty(DestinationTextBox.Text))
        {
            var parent = Path.GetDirectoryName(DestinationTextBox.Text);
            if (!string.IsNullOrEmpty(parent) && Directory.Exists(parent))
            {
                dialog.InitialDirectory = parent;
            }
        }

        if (dialog.ShowDialog() == true)
        {
            DestinationTextBox.Text = dialog.FolderName;
        }
    }

    private async void ExtractButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrEmpty(_rarFilePath))
        {
            MessageBox.Show("No RAR file selected.", "Error",
                MessageBoxButton.OK, MessageBoxImage.Error);
            return;
        }

        var destination = DestinationTextBox.Text.Trim();
        if (string.IsNullOrEmpty(destination))
        {
            MessageBox.Show("Please specify a valid extraction destination.",
                "Invalid Destination", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var password = PasswordBox.Password;

        // Update UI for extraction
        ExtractButton.IsEnabled = false;
        ProgressBar.Visibility = Visibility.Visible;
        StatusLabel.Text = "Extracting...";

        _cancellationTokenSource = new CancellationTokenSource();

        try
        {
            var manager = new ExtractionManager();
            var result = await Task.Run(() =>
                manager.Extract(_rarFilePath, destination,
                    string.IsNullOrEmpty(password) ? null : password),
                _cancellationTokenSource.Token);

            switch (result.Status)
            {
                case ExtractionStatus.Success:
                    // Open the destination folder in Explorer
                    System.Diagnostics.Process.Start("explorer.exe", destination);
                    Application.Current.Shutdown();
                    break;

                case ExtractionStatus.NeedsPassword:
                    StatusLabel.Text = "This archive requires a password.";
                    PasswordBox.Focus();
                    break;

                case ExtractionStatus.WrongPassword:
                    StatusLabel.Text = "Incorrect password. Please try again.";
                    StatusLabel.Foreground = System.Windows.Media.Brushes.Red;
                    PasswordBox.Focus();
                    break;

                case ExtractionStatus.Failed:
                    MessageBox.Show(result.Message ?? "Unknown error occurred.",
                        "Extraction Failed", MessageBoxButton.OK, MessageBoxImage.Error);
                    break;
            }
        }
        catch (OperationCanceledException)
        {
            StatusLabel.Text = "Extraction cancelled.";
        }
        catch (Exception ex)
        {
            MessageBox.Show($"An error occurred: {ex.Message}",
                "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            ExtractButton.IsEnabled = true;
            ProgressBar.Visibility = Visibility.Collapsed;
            _cancellationTokenSource?.Dispose();
            _cancellationTokenSource = null;
        }
    }

    private void CancelButton_Click(object sender, RoutedEventArgs e)
    {
        _cancellationTokenSource?.Cancel();
        Application.Current.Shutdown();
    }
}