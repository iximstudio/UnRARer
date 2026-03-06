using System.IO;
using SharpCompress.Archives;
using SharpCompress.Archives.Rar;
using SharpCompress.Common;

namespace UnRARer;

/// <summary>
/// Status of an extraction operation.
/// </summary>
public enum ExtractionStatus
{
    Success,
    NeedsPassword,
    WrongPassword,
    Failed
}

/// <summary>
/// Result of an extraction operation.
/// </summary>
public class ExtractionResult
{
    public ExtractionStatus Status { get; set; }
    public string? Message { get; set; }

    public static ExtractionResult Succeeded() =>
        new() { Status = ExtractionStatus.Success };

    public static ExtractionResult PasswordRequired() =>
        new() { Status = ExtractionStatus.NeedsPassword, Message = "This archive requires a password." };

    public static ExtractionResult InvalidPassword() =>
        new() { Status = ExtractionStatus.WrongPassword, Message = "Incorrect password." };

    public static ExtractionResult Error(string message) =>
        new() { Status = ExtractionStatus.Failed, Message = message };
}

/// <summary>
/// Manages extraction of RAR archives using SharpCompress library.
/// </summary>
public class ExtractionManager
{
    /// <summary>
    /// Extracts a RAR archive to the specified destination.
    /// </summary>
    /// <param name="rarFilePath">Path to the .rar file.</param>
    /// <param name="destination">Directory to extract files into.</param>
    /// <param name="password">Optional password for encrypted archives.</param>
    /// <returns>The result of the extraction operation.</returns>
    public ExtractionResult Extract(string rarFilePath, string destination, string? password)
    {
        try
        {
            if (!File.Exists(rarFilePath))
            {
                return ExtractionResult.Error($"File not found: {rarFilePath}");
            }

            // Create destination directory if it doesn't exist
            if (!Directory.Exists(destination))
            {
                Directory.CreateDirectory(destination);
            }

            var readerOptions = new SharpCompress.Readers.ReaderOptions();
            if (!string.IsNullOrEmpty(password))
            {
                readerOptions.Password = password;
            }

            using var archive = RarArchive.Open(rarFilePath, readerOptions);

            // Check if any entry in the archive is encrypted and no password provided
            if (string.IsNullOrEmpty(password))
            {
                foreach (var entry in archive.Entries)
                {
                    if (entry.IsEncrypted)
                    {
                        return ExtractionResult.PasswordRequired();
                    }
                }
            }

            foreach (var entry in archive.Entries)
            {
                if (!entry.IsDirectory)
                {
                    try
                    {
                        entry.WriteToDirectory(destination, new ExtractionOptions
                        {
                            ExtractFullPath = true,
                            Overwrite = true
                        });
                    }
                    catch (CryptographicException)
                    {
                        if (string.IsNullOrEmpty(password))
                        {
                            return ExtractionResult.PasswordRequired();
                        }
                        return ExtractionResult.InvalidPassword();
                    }
                    catch (InvalidFormatException ex) when (
                        ex.Message.Contains("password", StringComparison.OrdinalIgnoreCase) ||
                        ex.Message.Contains("crypt", StringComparison.OrdinalIgnoreCase))
                    {
                        if (string.IsNullOrEmpty(password))
                        {
                            return ExtractionResult.PasswordRequired();
                        }
                        return ExtractionResult.InvalidPassword();
                    }
                }
            }

            return ExtractionResult.Succeeded();
        }
        catch (CryptographicException)
        {
            if (string.IsNullOrEmpty(password))
            {
                return ExtractionResult.PasswordRequired();
            }
            return ExtractionResult.InvalidPassword();
        }
        catch (InvalidFormatException ex) when (
            ex.Message.Contains("password", StringComparison.OrdinalIgnoreCase) ||
            ex.Message.Contains("crypt", StringComparison.OrdinalIgnoreCase))
        {
            if (string.IsNullOrEmpty(password))
            {
                return ExtractionResult.PasswordRequired();
            }
            return ExtractionResult.InvalidPassword();
        }
        catch (Exception ex)
        {
            return ExtractionResult.Error($"Extraction failed: {ex.Message}");
        }
    }
}
