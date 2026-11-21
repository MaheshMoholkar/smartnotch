using System;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using Velopack;

namespace SmartNotch;

internal sealed class AppUpdates : IDisposable
{
    private static readonly string preferencesPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MaheshLabs", "SmartNotch", "updates.json");
    private readonly DispatcherTimer timer = new() { Interval = TimeSpan.FromHours(1) };
    private UpdatePreferences preferences = LoadPreferences();
    private bool busy;
    private bool disposed;
    private CancellationTokenSource? downloadCancellation;
    internal event Action<string?>? StatusChanged;
    internal event Action? AvailabilityChanged;
    internal string? AvailableVersion { get; private set; }
    internal bool AutomaticallyChecks => preferences.AutomaticallyChecks;

    internal void Start(MainWindow owner)
    {
        var currentVersion = Assembly.GetExecutingAssembly().GetName().Version;
        if (Version.TryParse(preferences.AvailableVersion, out var available) && currentVersion != null && available > currentVersion)
            SetAvailableVersion(preferences.AvailableVersion);
        else
            SetAvailableVersion(null);
        timer.Tick += async (_, _) => await CheckAsync(owner, manual: false);
        timer.Start();
        // Let the editor finish loading before any network access or update prompt.
        owner.Dispatcher.BeginInvoke(new Action(async () => await CheckAsync(owner, manual: false)), DispatcherPriority.ApplicationIdle);
    }

    internal void ToggleAutomaticChecks()
    {
        preferences.AutomaticallyChecks = !preferences.AutomaticallyChecks;
        SavePreferences();
    }

    internal async Task CheckAsync(MainWindow owner, bool manual = true)
    {
        if (busy || disposed || (!manual && (!AutomaticallyChecks || DateTimeOffset.UtcNow - preferences.LastCheck < TimeSpan.FromDays(1)))) return;
        busy = true;
        bool updateAvailable = false;
        try
        {
            var feed = ReadFeedURL();
            if (feed == null)
            {
                if (manual) MessageBox.Show("Updates aren’t available in this build. Install a release of SmartNotch with updates enabled to receive future updates in the app.", "SmartNotch Updates");
                return;
            }
            var manager = new UpdateManager(feed);
            if (!manager.IsInstalled)
            {
                if (manual) MessageBox.Show("Install SmartNotch using Setup.exe to enable in-app updates. Your saved content stays on this computer.", "SmartNotch Updates");
                return;
            }
            preferences.LastCheck = DateTimeOffset.UtcNow;
            SavePreferences();
            StatusChanged?.Invoke("Checking for updates…");
            var update = await manager.CheckForUpdatesAsync();
            if (disposed) return;
            if (update == null)
            {
                SetAvailableVersion(null);
                if (manual) MessageBox.Show($"SmartNotch {manager.CurrentVersion} is up to date.", "SmartNotch Updates");
                return;
            }
            SetAvailableVersion(update.TargetFullRelease.Version.ToString());
            // Background checks announce an update without interrupting a recording.
            if (!manual)
            {
                updateAvailable = true;
                StatusChanged?.Invoke($"SmartNotch {update.TargetFullRelease.Version} is available · Choose Check for Updates to install");
                return;
            }
            if (!ConfirmDownload(update)) return;

            using var cancellation = new CancellationTokenSource();
            downloadCancellation = cancellation;
            var progress = new ProgressBar { Minimum = 0, Maximum = 100, Height = 8, Margin = new Thickness(0, 16, 0, 16) };
            var cancel = MainWindow.Button("Cancel", () => cancellation.Cancel());
            var content = new StackPanel { Margin = new Thickness(24) };
            content.Children.Add(new TextBlock { Text = "Downloading SmartNotch…", FontSize = 18 });
            content.Children.Add(progress);
            content.Children.Add(cancel);
            var downloadWindow = new Window { Title = "SmartNotch Updates", Content = content,
                Width = 380, SizeToContent = SizeToContent.Height, ResizeMode = ResizeMode.NoResize,
                WindowStartupLocation = WindowStartupLocation.CenterScreen };
            downloadWindow.Closing += (_, _) => cancellation.Cancel();
            downloadWindow.Show();
            try
            {
                await manager.DownloadUpdatesAsync(update, value => owner.Dispatcher.BeginInvoke(new Action(() =>
                {
                    progress.Value = value;
                    StatusChanged?.Invoke($"Downloading update… {value}%");
                })), cancellation.Token);
            }
            finally
            {
                downloadWindow.Close();
                downloadCancellation = null;
            }
            if (disposed) return;
            if (MessageBox.Show("The update is ready. Install and restart SmartNotch now?", "SmartNotch Updates",
                MessageBoxButton.YesNo, MessageBoxImage.Information) != MessageBoxResult.Yes) return;
            // Velopack exits immediately. Flush edits first, and abort if saving fails.
            if (!owner.SaveBeforeUpdate()) return;
            manager.WaitExitThenApplyUpdates(update.TargetFullRelease, restart: true);
            owner.Quit();
        }
        catch (OperationCanceledException) { }
        catch (Exception error)
        {
            // Network, disk, hash and updater failures leave the current app running.
            System.Diagnostics.Trace.WriteLine(error);
            if (manual && !disposed) MessageBox.Show("The update could not be completed. Check your connection and available disk space, then try again. Your current version is still available.",
                "SmartNotch Updates", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
        finally
        {
            busy = false;
            // Keep the background update-available message visible.
            if (!updateAvailable && !disposed) StatusChanged?.Invoke(null);
        }
    }

    private void SetAvailableVersion(string? version)
    {
        AvailableVersion = version;
        preferences.AvailableVersion = version;
        SavePreferences();
        AvailabilityChanged?.Invoke();
    }

    private static bool ConfirmDownload(UpdateInfo update)
    {
        var content = new StackPanel { Margin = new Thickness(24) };
        content.Children.Add(new TextBlock { Text = $"SmartNotch {update.TargetFullRelease.Version} is available", FontSize = 19,
            TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 16) });
        // Plain text avoids running HTML or remote content from release notes.
        content.Children.Add(new TextBox { Text = update.TargetFullRelease.NotesMarkdown ?? "A new version of SmartNotch is available.",
            IsReadOnly = true, TextWrapping = TextWrapping.Wrap, MaxHeight = 260, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });
        var dialog = new Window { Title = "SmartNotch Updates", Content = content, Width = 480,
            SizeToContent = SizeToContent.Height, ResizeMode = ResizeMode.NoResize, WindowStartupLocation = WindowStartupLocation.CenterScreen };
        content.Children.Add(MainWindow.Row(
            MainWindow.Button("Download update", () => dialog.DialogResult = true),
            MainWindow.Button("Later", () => dialog.DialogResult = false)));
        return dialog.ShowDialog() == true;
    }

    private static string? ReadFeedURL()
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("SmartNotch.release.json");
        if (stream == null) return null;
        using var config = JsonDocument.Parse(stream);
        var root = config.RootElement.GetProperty("updateBaseURL").GetString();
        if (!Uri.TryCreate(root, UriKind.Absolute, out var url) || url.Scheme != "https" ||
            string.IsNullOrEmpty(url.Host) || !string.IsNullOrEmpty(url.UserInfo) ||
            !string.IsNullOrEmpty(url.Query) || !string.IsNullOrEmpty(url.Fragment)) return null;
        string architecture = RuntimeInformation.ProcessArchitecture switch
        {
            Architecture.X64 => "win-x64",
            Architecture.Arm64 => "win-arm64",
            _ => throw new PlatformNotSupportedException("Unsupported update architecture.")
        };
        return root!.TrimEnd('/') + "/windows/" + architecture;
    }

    private static UpdatePreferences LoadPreferences()
    {
        try { return JsonSerializer.Deserialize<UpdatePreferences>(File.ReadAllText(preferencesPath)) ?? new(); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException) { return new(); }
    }

    private void SavePreferences()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(preferencesPath)!);
            File.WriteAllText(preferencesPath + ".tmp", JsonSerializer.Serialize(preferences));
            File.Move(preferencesPath + ".tmp", preferencesPath, overwrite: true);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        { System.Diagnostics.Trace.WriteLine(error); }
    }

    public void Dispose()
    {
        disposed = true;
        timer.Stop();
        downloadCancellation?.Cancel();
    }

    private sealed class UpdatePreferences
    {
        public bool AutomaticallyChecks { get; set; } = true;
        public DateTimeOffset LastCheck { get; set; } = DateTimeOffset.MinValue;
        public string? AvailableVersion { get; set; }
    }
}
