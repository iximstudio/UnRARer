using System.Windows;

namespace UnRARer;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : Application
{
    private void Application_Startup(object sender, StartupEventArgs e)
    {
        string? rarFilePath = null;

        // Check command-line arguments for a .rar file path
        if (e.Args.Length > 0)
        {
            var path = e.Args[0];
            if (path.EndsWith(".rar", StringComparison.OrdinalIgnoreCase) &&
                System.IO.File.Exists(path))
            {
                rarFilePath = path;
            }
        }

        var mainWindow = new MainWindow(rarFilePath);
        mainWindow.Show();
    }
}

