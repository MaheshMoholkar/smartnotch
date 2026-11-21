using System;
using System.Threading;
using System.Windows;
using Velopack;

namespace SmartNotch;

public partial class App : Application
{
    private Mutex? instance;
    private bool ownsInstance;

    [STAThread]
    public static void Main(string[] args)
    {
        // Must run before WPF and the single-instance mutex, including on update hooks.
        VelopackApp.Build().SetAutoApplyOnStartup(false).Run();
        var app = new App();
        app.InitializeComponent();
        app.Run();
    }

    protected override void OnStartup(StartupEventArgs e)
    {
        instance = new Mutex(true, @"Local\MaheshLabs.SmartNotch", out ownsInstance);
        if (!ownsInstance)
        {
            MessageBox.Show("SmartNotch is already open. Use its icon in the notification area to show the editor.", "SmartNotch");
            Shutdown();
            return;
        }
        base.OnStartup(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (ownsInstance) instance!.ReleaseMutex();
        instance?.Dispose();
        base.OnExit(e);
    }
}
