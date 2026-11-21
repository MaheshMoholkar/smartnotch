using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using Forms = System.Windows.Forms;
using static SmartNotch.MainWindow;

namespace SmartNotch;

internal sealed class Overlay : Window
{
    private readonly MainWindow workspace;
    private readonly Notch notch;
    private readonly Border frame = new() { CornerRadius = new CornerRadius(16), BorderThickness = new Thickness(1), Padding = new Thickness(12) };
    private readonly ScrollViewer scroll = new() { VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    private readonly DispatcherTimer timer = new() { Interval = TimeSpan.FromMilliseconds(40) };
    private readonly Stopwatch clock = new();
    private readonly List<Run> words = [];
    private readonly TextBlock readingStatus = new() { Margin = new Thickness(6, 4, 0, 4) };
    private TextBlock? reader;
    private ComboBox? titles;
    private Button? pinButton;
    private Button? updateButton;
    private Button? playButton;
    private Run? highlight;
    private bool pinned;
    private bool editing;
    private bool playing;
    private bool resizing;
    private bool waitForPointerExit;
    private IntPtr priorWindow;
    private double resizeHeight;

    public Overlay(MainWindow workspace)
    {
        this.workspace = workspace;
        notch = new Notch(ClickNotch);
        Title = "SmartNotch panel";
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Content = frame;
        Topmost = true;
        ShowActivated = false;
        ShowInTaskbar = false;
        SourceInitialized += (_, _) => ((HwndSource)PresentationSource.FromVisual(this)).AddHook(WindowMessage);
        PreviewKeyDown += HandleKey;
        timer.Tick += (_, _) => Tick();
        workspace.Updates.AvailabilityChanged += RefreshUpdateBadge;
        Rebuild();
    }

    private IntPtr WindowMessage(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message == 0x0021 && !editing) // WM_MOUSEACTIVATE
        {
            handled = true;
            return new IntPtr(3); // MA_NOACTIVATE
        }
        return IntPtr.Zero;
    }

    internal void Rebuild()
    {
        FinishEditing(refresh: false);
        var root = new DockPanel();
        frame.Child = root;
        var rows = new StackPanel();
        var tabs = Row();
        foreach (var tab in Enum.GetValues<Section>())
        {
            var button = Button(tab.ToString(), () => workspace.SwitchSection(tab));
            button.IsEnabled = tab != workspace.CurrentSection;
            tabs.Children.Add(button);
        }
        pinButton = Button(pinned ? "Unpin" : "Pin", () => SetPinned(!pinned));
        tabs.Children.Add(pinButton);
        tabs.Children.Add(Button("Editor", workspace.ShowEditor));
        tabs.Children.Add(Button("Hide", Dismiss));
        updateButton = Button("Update available", async () => await workspace.Updates.CheckAsync(workspace));
        updateButton.Foreground = Ink(0xFF66E8C2);
        updateButton.Background = Ink(0xFF21483E);
        tabs.Children.Add(updateButton);
        RefreshUpdateBadge();
        rows.Children.Add(tabs);

        titles = new ComboBox { ItemsSource = workspace.Titles.ToArray(), SelectedItem = workspace.TitleEntry,
            Width = 126, Margin = new Thickness(0, 0, 5, 5), ToolTip = "Select a title" };
        titles.SelectionChanged += (_, _) =>
        {
            if (titles.SelectedItem is Title item && item != workspace.TitleEntry) workspace.SelectTitle(item);
        };
        var controls = Row(titles);
        playButton = null;
        if (workspace.CurrentSection == Section.Read)
        {
            controls.Children.Add(Button("Previous", () => workspace.Navigate(false)));
            playButton = Button("Play", TogglePlayback);
            controls.Children.Add(playButton);
            controls.Children.Add(Button("Next", () => workspace.Navigate(true)));
            controls.Children.Add(Button("Restart", Restart));
            controls.Children.Add(readingStatus);
        }
        if (workspace.CurrentSection == Section.Cards)
        {
            controls.Children.Add(Button("Previous", () => workspace.Navigate(false)));
            controls.Children.Add(Button("Next", () => workspace.Navigate(true)));
            controls.Children.Add(Button("Toggle done", workspace.ToggleCard));
            controls.Children.Add(Button("Edit notes", BeginEditing));
        }
        if (workspace.CurrentSection == Section.Notes) controls.Children.Add(Button("Edit notes", BeginEditing));
        rows.Children.Add(controls);
        var options = new Expander { Header = "Configure", Content = new ScrollViewer
            {
                Content = workspace.BuildSettings(), MaxHeight = 115,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto
            } };
        options.Expanded += (_, _) => SetPinned(true);
        rows.Children.Add(options);
        DockPanel.SetDock(rows, Dock.Top);
        root.Children.Add(rows);

        var grip = new Thumb { Height = 12, Width = 52, Background = Ink(0xFF667078),
            Cursor = Cursors.SizeNS, ToolTip = "Drag to resize. Double-click to reset." };
        grip.DragStarted += (_, _) => { resizing = true; resizeHeight = workspace.Appearance.Height; };
        grip.DragDelta += (_, e) =>
        {
            resizeHeight += e.VerticalChange;
            workspace.Appearance.Height = Math.Clamp(resizeHeight, 220, 700);
            RefreshAppearance();
        };
        grip.DragCompleted += (_, _) => { resizing = false; workspace.SaveSoon(); };
        grip.MouseDoubleClick += (_, _) =>
        {
            workspace.Appearance.Height = 300;
            RefreshAppearance();
            workspace.SaveSoon();
        };
        DockPanel.SetDock(grip, Dock.Bottom);
        root.Children.Add(grip);
        if (scroll.Parent is Panel previous) previous.Children.Remove(scroll);
        root.Children.Add(scroll);
        UpdateContent();
        RefreshAppearance();
    }

    internal void UpdateTitle() => titles?.Items.Refresh();

    private void RefreshUpdateBadge()
    {
        if (updateButton == null) return;
        updateButton.Visibility = workspace.Updates.AvailableVersion == null ? Visibility.Collapsed : Visibility.Visible;
        updateButton.ToolTip = $"SmartNotch {workspace.Updates.AvailableVersion} is available. View release notes and update.";
    }

    internal void UpdateContent()
    {
        FinishEditing(refresh: false);
        reader = null;
        highlight = null;
        words.Clear();
        if (workspace.CurrentSection == Section.Read)
        {
            var text = new TextBlock { TextWrapping = TextWrapping.Wrap, Margin = new Thickness(3, 8, 7, 10) };
            string script = workspace.TitleEntry.Text;
            int offset = 0;
            foreach (var word in workspace.Script.Words)
            {
                if (word.Index > offset) text.Inlines.Add(new Run(script[offset..word.Index]));
                int index = words.Count;
                var run = new Run(word.Value);
                run.MouseLeftButtonUp += (_, _) => workspace.ActivateWord(index);
                words.Add(run);
                text.Inlines.Add(run);
                offset = word.Index + word.Length;
            }
            if (offset < script.Length) text.Inlines.Add(new Run(script[offset..]));
            if (words.Count == 0) text.Inlines.Add(new Run("Add a script in the editor."));
            reader = text;
        }
        scroll.Content = workspace.CurrentSection switch
        {
            Section.Read => reader!,
            Section.Cards => CardContent(),
            _ => Body(string.IsNullOrWhiteSpace(workspace.TitleEntry.Notes) ? "No notes yet." : workspace.TitleEntry.Notes)
        };
        scroll.ScrollToTop();
        UpdateProgress();
    }

    private UIElement CardContent()
    {
        if (workspace.ActiveCard is not Card card) return Body("Add cards in the editor.");
        var deck = workspace.TitleEntry.Cards;
        var picker = new ComboBox { ItemsSource = deck.ToArray(), SelectedItem = card,
            ToolTip = "Select a card", Margin = new Thickness(0, 3, 7, 3) };
        picker.SelectionChanged += (_, _) =>
        {
            if (picker.SelectedItem is Card selected && selected != workspace.ActiveCard) workspace.SelectCard(selected);
        };
        var layout = new StackPanel();
        layout.Children.Add(Row(picker, new TextBlock { Text = $"{deck.IndexOf(card) + 1} / {deck.Count}",
            VerticalAlignment = VerticalAlignment.Center }));
        if (!string.IsNullOrEmpty(card.Details)) layout.Children.Add(Body(card.Details));
        if (!string.IsNullOrEmpty(card.Notes)) layout.Children.Add(Body(card.Notes));
        return layout;
    }

    private static TextBlock Body(string text) => new() { Text = text, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(3, 8, 7, 10) };

    internal void RefreshAppearance()
    {
        var appearance = workspace.Appearance;
        frame.Background = Ink((uint)Math.Round(255 * (1 - appearance.Transparency / 100)) << 24 | 0x181A1F);
        frame.BorderBrush = Ink((uint)Math.Round(255 * (1 - appearance.Transparency / 100)) << 24 | 0x393D45);
        scroll.FontSize = appearance.TextSize;
        scroll.Foreground = appearance.Ink switch
        {
            "Soft white" => Ink(0xFFF5F7FC),
            "Slate gray" => Ink(0xFFA1ADBD),
            "Warm yellow" => Ink(0xFFFFD96E),
            _ => Ink(0xFF7CE3F2)
        };
        PositionPanel();
        UpdateProgress();
    }

    private static SolidColorBrush Ink(uint rgba) =>
        new(Color.FromArgb((byte)(rgba >> 24), (byte)(rgba >> 16), (byte)(rgba >> 8), (byte)rgba));

    internal void Start()
    {
        notch.Place(SystemParameters.WorkArea);
        notch.Show();
        timer.Start();
    }

    private void PositionPanel()
    {
        Rect workArea = SystemParameters.WorkArea;
        Width = Math.Min(workArea.Width - 16, workspace.Appearance.Width);
        Height = Math.Min(workArea.Height - 16, workspace.Appearance.Height);
        Left = workArea.Left + (workArea.Width - Width) / 2;
        Top = workArea.Top + Notch.LipHeight;
    }

    internal void UpdateProgress()
    {
        if (reader is null) return;
        var position = workspace.TitleEntry.ReadingPosition;
        var next = words.ElementAtOrDefault(position.WordIndex);
        if (playButton is not null)
        {
            playButton.Content = playing ? "Pause" : "Play";
            playButton.IsEnabled = workspace.Settings.Mode != "Manual" && words.Count > 0;
        }
        readingStatus.Text = position.Finished ? "Complete" : words.Count == 0 ? "" : $"{position.WordIndex + 1} / {words.Count}";
        if (next == highlight) return;
        if (highlight is not null) highlight.ClearValue(Inline.TextDecorationsProperty);
        highlight = next;
        if (next is null) return;
        next.TextDecorations = TextDecorations.Underline;
        Dispatcher.BeginInvoke(DispatcherPriority.Loaded, new Action(() =>
        {
            if (highlight != next || reader is null || !IsVisible) return;
            Rect bounds = next.ContentStart.GetCharacterRect(LogicalDirection.Forward);
            if (!bounds.IsEmpty) scroll.ScrollToVerticalOffset(Math.Max(0, bounds.Top - scroll.ViewportHeight / 3));
        }));
    }

    internal void TogglePlayback()
    {
        if (workspace.CurrentSection != Section.Read || workspace.Settings.Mode == "Manual") { ShowPinned(); return; }
        if (playing) { Pause(); return; }
        if (workspace.Script.Words.Length == 0) { ShowPinned(); return; }
        if (workspace.TitleEntry.ReadingPosition.Finished) Restart();
        ShowPinned();
        playing = true;
        clock.Restart();
        UpdateProgress();
    }

    private void Restart()
    {
        Pause();
        workspace.ActivateWord(0);
    }

    internal void Pause()
    {
        if (!playing) return;
        playing = false;
        clock.Reset();
        UpdateProgress();
        workspace.SaveSoon();
    }

    internal void ShowPinned()
    {
        SetPinned(true);
        Reveal();
    }

    private void Reveal()
    {
        if (IsVisible) return;
        PositionPanel();
        Show();
        if (highlight is not null) highlight.ClearValue(Inline.TextDecorationsProperty);
        highlight = null;
        UpdateProgress();
    }

    private void SetPinned(bool value)
    {
        pinned = value || editing;
        if (pinButton is not null) pinButton.Content = pinned ? "Unpin" : "Pin";
    }

    internal void Toggle()
    {
        if (IsVisible) Dismiss();
        else ShowPinned();
    }

    internal void Dismiss()
    {
        Pause();
        FinishEditing();
        SetPinned(false);
        if (IsVisible) Hide();
        waitForPointerExit = true;
    }

    private void ClickNotch()
    {
        if (IsVisible && pinned) Dismiss();
        else ShowPinned();
    }

    internal void Stop()
    {
        timer.Stop();
        Dismiss();
        notch.Close();
    }

    private void BeginEditing()
    {
        if (editing || (workspace.CurrentSection == Section.Cards && workspace.ActiveCard is null)) return;
        priorWindow = NativeControls.GetForegroundWindow();
        editing = true;
        SetPinned(true);
        var notes = new TextBox { Text = workspace.CurrentSection == Section.Notes ? workspace.TitleEntry.Notes : workspace.ActiveCard!.Notes,
            AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, MinHeight = 75, Margin = new Thickness(0, 4, 0, 4) };
        notes.TextChanged += (_, _) => workspace.SavePopupNotes(notes.Text);
        var layout = new StackPanel();
        layout.Children.Add(notes);
        layout.Children.Add(Button("Done", () => { FinishEditing(); UpdateContent(); }));
        scroll.Content = layout;
        Activate();
        notes.Focus();
    }

    private void FinishEditing(bool refresh = true)
    {
        if (!editing) return;
        editing = false;
        if (IsActive && priorWindow != IntPtr.Zero) NativeControls.SetForegroundWindow(priorWindow);
        priorWindow = IntPtr.Zero;
        if (refresh) workspace.PopupEditingFinished();
    }

    private void HandleKey(object sender, KeyEventArgs e)
    {
        if (editing && e.Key == Key.Escape)
        {
            FinishEditing();
            UpdateContent();
            e.Handled = true;
        }
        else if (!editing && workspace.CurrentSection == Section.Cards && e.Key is Key.Up or Key.Down or Key.Space)
        {
            if (e.Key == Key.Space) workspace.ToggleCard();
            else workspace.Navigate(e.Key == Key.Down);
            e.Handled = true;
        }
    }

    private void Tick()
    {
        if (playing)
        {
            var position = workspace.TitleEntry.ReadingPosition;
            int previous = position.WordIndex;
            workspace.Script.Advance(position, Math.Min(0.2, clock.Elapsed.TotalSeconds),
                workspace.Settings.Speed * workspace.Settings.PlaybackRate);
            clock.Restart();
            if (position.WordIndex != previous) { UpdateProgress(); workspace.SaveSoon(); }
            if (position.Finished) Pause();
        }

        if (notch.Place(SystemParameters.WorkArea)) PositionPanel();
        var cursor = Forms.Cursor.Position;
        bool overHotspot = ContainsPointer(notch, cursor);
        if (!overHotspot) waitForPointerExit = false;
        if (!IsVisible && !waitForPointerExit && overHotspot && workspace.Appearance.OpenOnHover != false)
        {
            Reveal();
        }
        else if (IsVisible && !pinned && !resizing && !overHotspot && !ContainsPointer(this, cursor))
        {
            Dismiss();
        }
    }

    private static bool ContainsPointer(Window window, System.Drawing.Point cursor)
    {
        var top = window.PointToScreen(new Point(0, 0));
        var bottom = window.PointToScreen(new Point(window.ActualWidth, window.ActualHeight));
        return cursor.X >= top.X && cursor.X < bottom.X && cursor.Y >= top.Y && cursor.Y < bottom.Y;
    }
}
