using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Interop;

namespace SmartNotch;

internal sealed class NativeControls : IDisposable
{
    private const int HotkeyMessage = 0x0312;
    private const uint ControlAltNoRepeat = 0x4003;
    private readonly HwndSource source;
    private readonly Dictionary<int, Action> handlers = [];
    public bool AllRegistered => handlers.Count == 5;

    public NativeControls(MainWindow editor, Overlay panel)
    {
        source = HwndSource.FromHwnd(new WindowInteropHelper(editor).Handle);
        source.AddHook(WindowMessage);
        Add(1, 0x20, panel.TogglePlayback); // Space
        Add(2, 0x26, () => editor.Navigate(false)); // Up
        Add(3, 0x28, () => editor.Navigate(true)); // Down
        Add(4, 0x50, panel.Toggle); // P
        Add(5, 0x45, editor.ShowEditor); // E
    }

    private void Add(int id, uint key, Action action)
    {
        if (RegisterHotKey(source.Handle, id, ControlAltNoRepeat, key)) handlers[id] = action;
    }

    private IntPtr WindowMessage(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message != HotkeyMessage || !handlers.TryGetValue(wParam.ToInt32(), out var action)) return IntPtr.Zero;
        action();
        handled = true;
        return IntPtr.Zero;
    }

    public void Dispose()
    {
        foreach (int id in handlers.Keys) UnregisterHotKey(source.Handle, id);
        source.RemoveHook(WindowMessage);
        handlers.Clear();
    }

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool RegisterHotKey(IntPtr hwnd, int id, uint modifiers, uint key);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnregisterHotKey(IntPtr hwnd, int id);

    [DllImport("user32.dll")]
    internal static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetForegroundWindow(IntPtr hwnd);
}
