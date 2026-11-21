using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;

namespace SmartNotch;

internal sealed class Notch : Window
{
    internal const double LipHeight = 8;
    private Rect lastWorkArea = Rect.Empty;

    public Notch(Action toggle)
    {
        Title = "SmartNotch panel trigger";
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Topmost = true;
        ShowActivated = false;
        ShowInTaskbar = false;
        Width = 112;
        Height = LipHeight;

        var mark = new Border { Width = 26, Height = 2, CornerRadius = new CornerRadius(1),
            Background = new SolidColorBrush(Color.FromRgb(103, 131, 145)) };
        var lip = new Border { Background = new SolidColorBrush(Color.FromRgb(27, 30, 36)),
            CornerRadius = new CornerRadius(0, 0, 6, 6), Child = mark, Cursor = Cursors.Hand };
        lip.ToolTip = "SmartNotch · Hover to open, click to pin or hide";
        System.Windows.Automation.AutomationProperties.SetName(lip, "SmartNotch panel trigger");
        lip.MouseLeftButtonUp += (_, _) => toggle();
        Content = lip;
        SourceInitialized += (_, _) => ((HwndSource)PresentationSource.FromVisual(this)).AddHook(WindowMessage);
    }

    public bool Place(Rect workArea)
    {
        if (lastWorkArea == workArea) return false;
        lastWorkArea = workArea;
        Left = workArea.Left + (workArea.Width - Width) / 2;
        Top = workArea.Top;
        return true;
    }

    private static IntPtr WindowMessage(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message != 0x0021) return IntPtr.Zero; // WM_MOUSEACTIVATE
        handled = true;
        return new IntPtr(3); // MA_NOACTIVATE
    }
}
