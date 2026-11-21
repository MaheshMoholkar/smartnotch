using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Microsoft.Win32;
using Forms = System.Windows.Forms;

namespace SmartNotch;

public partial class MainWindow : Window
{
    private readonly Session session;
    private readonly ListBox titleList = new();
    private readonly StackPanel editor = new() { Margin = new Thickness(20, 0, 0, 0) };
    private readonly TextBlock status = new() { Text = "Saved locally", TextWrapping = TextWrapping.Wrap };
    private readonly DispatcherTimer saveTimer = new() { Interval = TimeSpan.FromMilliseconds(350) };
    private readonly AppUpdates updates = new();
    private readonly TextBlock updateStatus = new() { TextWrapping = TextWrapping.Wrap };
    private readonly Overlay panel;
    private NativeControls? native;
    private Forms.NotifyIcon? tray;
    private System.Drawing.Icon? trayIcon;
    private bool panelStarted;
    private bool rebuilding;
    private bool exiting;
    private bool savingEnabled = true;
    private string shortcutStatus = "";
    private Section section;
    private Title title;
    internal Script Script { get; private set; }
    internal Session Settings => session;
    internal AppUpdates Updates => updates;
    internal Section CurrentSection => section;
    internal Title TitleEntry => title;
    internal Card? ActiveCard => title.Cards.FirstOrDefault(item => item.Id == title.SelectedCardID) ?? title.Cards.FirstOrDefault();
    internal Appearance Appearance => session.WorkspaceAppearances[section.ToString()];
    internal IEnumerable<Title> Titles => session.Chapters.Where(item => item.Workspace == section.ToString());

    public MainWindow()
    {
        InitializeComponent();
        try { session = Session.Load(); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException)
        {
            savingEnabled = false;
            session = new Session();
            foreach (string name in Enum.GetNames<Section>())
            {
                session.Chapters.Add(new Title { Workspace = name, Text = name == "Read" ? session.Text : "" });
                session.WorkspaceAppearances[name] = new Appearance { OpenOnHover = true };
            }
            status.Text = "The saved session could not be opened. Saving is paused for this run.";
        }
        section = Enum.Parse<Section>(session.WorkspaceTab ?? "Read");
        title = SelectedTitle();
        Script = new Script(title.Text);
        ClampPosition();
        Content = BuildEditor();
        panel = new Overlay(this);
        RebuildEditor();
        saveTimer.Tick += (_, _) => Save();
        SourceInitialized += (_, _) => StartNativeControls();
        ContentRendered += (_, _) =>
        {
            if (!panelStarted)
            {
                panel.Start();
                panelStarted = true;
                updates.Start(this);
            }
        };
        PreviewKeyDown += (_, e) =>
        {
            if (e.Key != Key.D1 || Keyboard.Modifiers != ModifierKeys.Control) return;
            ShowEditor();
            e.Handled = true;
        };
    }

    private Title SelectedTitle()
    {
        Guid? id = session.TitleSelections.TryGetValue(section.ToString(), out Guid selected) ? selected : session.ActiveChapterID;
        return Titles.FirstOrDefault(item => item.Id == id) ?? Titles.First();
    }

    private void ClampPosition()
    {
        var position = title.ReadingPosition;
        position.WordIndex = Math.Clamp(position.WordIndex, 0, Math.Max(0, Script.Words.Length - 1));
        position.WordProgress = Math.Clamp(position.WordProgress, 0, 0.9999);
        position.Finished &= Script.Words.Length > 0 && position.WordIndex == Script.Words.Length - 1;
    }

    private UIElement BuildEditor()
    {
        var root = new DockPanel { Margin = new Thickness(22) };
        var header = new DockPanel { Margin = new Thickness(0, 0, 0, 18) };
        var logo = new Image { Source = new BitmapImage(new Uri("pack://application:,,,/SmartNotchLogo.png")),
            Width = 36, Height = 36, Margin = new Thickness(0, 0, 10, 0) };
        DockPanel.SetDock(logo, Dock.Left);
        header.Children.Add(logo);
        var actions = Row(Button("Show panel", () => { panel.ShowPinned(); Hide(); }),
            Button("Import", Import), Button("Export", Export),
            Button("Check for Updates…", async () => await updates.CheckAsync(this)));
        DockPanel.SetDock(actions, Dock.Right);
        header.Children.Add(actions);
        header.Children.Add(new TextBlock { Text = "SmartNotch", FontSize = 24, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center });
        DockPanel.SetDock(header, Dock.Top);
        root.Children.Add(header);
        DockPanel.SetDock(status, Dock.Bottom);
        root.Children.Add(status);
        DockPanel.SetDock(updateStatus, Dock.Bottom);
        root.Children.Add(updateStatus);
        updates.StatusChanged += text => updateStatus.Text = text ?? "";
        var sidebar = new DockPanel { Width = 250 };
        var headerButtons = Row();
        foreach (var tab in Enum.GetValues<Section>()) headerButtons.Children.Add(Button(tab.ToString(), () => SwitchSection(tab)));
        DockPanel.SetDock(headerButtons, Dock.Top);
        sidebar.Children.Add(headerButtons);
        var titleActions = Row(Button("+ Title", AddTitle), Button("Delete title", DeleteTitle));
        DockPanel.SetDock(titleActions, Dock.Bottom);
        sidebar.Children.Add(titleActions);
        titleList.SelectionChanged += (_, _) =>
        {
            if (!rebuilding && titleList.SelectedItem is Title item) SelectTitle(item);
        };
        sidebar.Children.Add(titleList);
        DockPanel.SetDock(sidebar, Dock.Left);
        root.Children.Add(sidebar);
        root.Children.Add(new ScrollViewer { Content = editor, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });
        return root;
    }

    private void RebuildEditor()
    {
        rebuilding = true;
        RefreshTitleList();
        editor.Children.Clear();
        editor.Children.Add(new TextBlock { Text = section.ToString(), FontSize = 23, FontWeight = FontWeights.SemiBold });
        editor.Children.Add(Field("Title", title.Name, name => { title.Name = name; RefreshTitleList(); panel.UpdateTitle(); SaveSoon(); }));
        switch (section)
        {
            case Section.Read:
                editor.Children.Add(Field("Script", title.Text, ReplaceScript, 255));
                break;
            case Section.Notes:
                editor.Children.Add(Field("Notes", title.Notes, text => { title.Notes = text; panel.UpdateContent(); SaveSoon(); }, 255));
                break;
            case Section.Cards:
                BuildCardEditor();
                break;
        }
        editor.Children.Add(new Expander { Header = "Panel settings", Content = BuildSettings(), Margin = new Thickness(0, 10, 0, 12) });
        rebuilding = false;
    }

    private void RefreshTitleList()
    {
        bool previous = rebuilding;
        rebuilding = true;
        titleList.ItemsSource = Titles.ToArray();
        titleList.SelectedItem = title;
        rebuilding = previous;
    }

    private void BuildCardEditor()
    {
        var cards = new ComboBox { ItemsSource = title.Cards.ToArray(), SelectedItem = ActiveCard, MinWidth = 160 };
        cards.SelectionChanged += (_, _) =>
        {
            if (cards.SelectedItem is Card selected && selected != ActiveCard) SelectCard(selected);
        };
        editor.Children.Add(Row(cards, Button("+ Card", () =>
        {
            var newCard = new Card();
            title.Cards.Add(newCard);
            SelectCard(newCard);
        }), Button("Delete card", DeleteCard)));
        if (ActiveCard is not Card card) return;
        editor.Children.Add(Field("Card title", card.Title, value =>
        {
            card.Title = value;
            cards.Items.Refresh();
            panel.UpdateContent();
            SaveSoon();
        }));
        editor.Children.Add(Field("Details", card.Details, value => { card.Details = value; panel.UpdateContent(); SaveSoon(); }, 100));
        editor.Children.Add(Field("Card notes", card.Notes, value => { card.Notes = value; panel.UpdateContent(); SaveSoon(); }, 80));
        var completed = new CheckBox { Content = "Completed", IsChecked = card.Completed };
        completed.Click += (_, _) => ToggleCard();
        editor.Children.Add(completed);
    }

    internal UIElement BuildSettings()
    {
        var layout = Row();
        var appearance = Appearance;
        layout.Children.Add(Choice("Text color", ["Soft white", "Slate gray", "Soft cyan", "Warm yellow"], appearance.Ink,
            value => { appearance.Ink = value; panel.RefreshAppearance(); SaveSoon(); }));
        layout.Children.Add(Choice("Width", ["420", "580", "680"], appearance.Width.ToString("0"),
            value => { appearance.Width = double.Parse(value); panel.RefreshAppearance(); SaveSoon(); }));
        layout.Children.Add(SliderField("Text size", 18, 36, appearance.TextSize,
            value => { appearance.TextSize = value; panel.RefreshAppearance(); SaveSoon(); }));
        layout.Children.Add(SliderField("Transparency", 0, 100, appearance.Transparency,
            value => { appearance.Transparency = value; panel.RefreshAppearance(); SaveSoon(); }));
        var hover = new CheckBox { Content = "Open on hover", IsChecked = appearance.OpenOnHover != false, Margin = new Thickness(0, 8, 8, 8) };
        hover.Click += (_, _) => { appearance.OpenOnHover = hover.IsChecked; SaveSoon(); };
        layout.Children.Add(hover);
        if (section == Section.Read)
        {
            layout.Children.Add(Choice("Reading mode", ["Auto-scroll", "Manual"], session.Mode,
                value => { session.Mode = value; panel.Pause(); SaveSoon(); }));
            layout.Children.Add(SliderField("Words per minute", 60, 240, session.Speed,
                value => { session.Speed = value; SaveSoon(); }));
            layout.Children.Add(Choice("Playback speed", ["0.5×", "0.75×", "1×", "1.25×", "1.5×", "2×"],
                session.PlaybackRate.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture) + "×",
                value => { session.PlaybackRate = double.Parse(value.TrimEnd('×'), System.Globalization.CultureInfo.InvariantCulture); SaveSoon(); }));
        }
        return layout;
    }

    internal void SwitchSection(Section next)
    {
        if (section == next) return;
        panel.Pause();
        section = next;
        session.WorkspaceTab = next.ToString();
        SelectTitle(SelectedTitle());
    }

    internal void SelectTitle(Title selected)
    {
        panel.Pause();
        title = selected;
        session.ActiveChapterID = selected.Id;
        session.TitleSelections[section.ToString()] = selected.Id;
        Script = new Script(selected.Text);
        ClampPosition();
        RebuildEditor();
        panel.Rebuild();
        SaveSoon();
    }

    private void AddTitle()
    {
        var item = new Title { Workspace = section.ToString(), Name = $"Title {Titles.Count() + 1}" };
        session.Chapters.Add(item);
        SelectTitle(item);
    }

    private void DeleteTitle()
    {
        var replacement = Titles.FirstOrDefault(item => item != title);
        if (replacement is null || !Confirm($"Delete “{title}”?")) return;
        session.Chapters.Remove(title);
        SelectTitle(replacement);
    }

    private void DeleteCard()
    {
        if (ActiveCard is not Card card || !Confirm($"Delete “{card.Title}”?")) return;
        int index = title.Cards.IndexOf(card);
        title.Cards.Remove(card);
        SelectCard(title.Cards.ElementAtOrDefault(Math.Min(index, title.Cards.Count - 1)));
    }

    private bool Confirm(string message) => MessageBox.Show(this, message, "SmartNotch", MessageBoxButton.YesNo,
        MessageBoxImage.Question, MessageBoxResult.No) == MessageBoxResult.Yes;

    internal void SelectCard(Card? card)
    {
        title.SelectedCardID = card?.Id;
        RebuildEditor();
        panel.UpdateContent();
        SaveSoon();
    }

    internal void Navigate(bool forward)
    {
        if (section == Section.Cards && ActiveCard is Card card)
        {
            int index = Math.Clamp(title.Cards.IndexOf(card) + (forward ? 1 : -1), 0, title.Cards.Count - 1);
            SelectCard(title.Cards[index]);
        }
        if (section == Section.Read) ActivateWord(Script.Paragraph(title.ReadingPosition.WordIndex, forward));
    }

    internal void ToggleCard()
    {
        if (ActiveCard is not Card card) return;
        card.Completed = !card.Completed;
        RebuildEditor();
        panel.UpdateContent();
        SaveSoon();
    }

    internal void ActivateWord(int index)
    {
        if (index < 0 || index >= Script.Words.Length) return;
        title.ReadingPosition.WordIndex = index;
        title.ReadingPosition.WordProgress = 0;
        title.ReadingPosition.Finished = false;
        panel.UpdateProgress();
        SaveSoon();
    }

    private void ReplaceScript(string text)
    {
        if (title.Text == text) return;
        title.Text = text;
        panel.Pause();
        Script = new Script(text);
        title.ReadingPosition = new ReadingPosition();
        panel.UpdateContent();
        SaveSoon();
    }

    internal void SavePopupNotes(string text)
    {
        if (section == Section.Notes) title.Notes = text;
        if (section == Section.Cards && ActiveCard is Card card) card.Notes = text;
        SaveSoon();
    }

    internal void PopupEditingFinished() => RebuildEditor();

    private void Import()
    {
        var dialog = new OpenFileDialog { Filter = "Text or Markdown|*.txt;*.md" };
        if (dialog.ShowDialog(this) != true) return;
        try
        {
            string text = File.ReadAllText(dialog.FileName, new System.Text.UTF8Encoding(false, true));
            switch (section)
            {
                case Section.Read: ReplaceScript(text); break;
                case Section.Notes: title.Notes = text; break;
                case Section.Cards:
                    var cards = text.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                        .Select(line => new Card { Title = line }).ToArray();
                    title.Cards.AddRange(cards);
                    if (cards.Length > 0) title.SelectedCardID = cards[0].Id;
                    break;
            }
            RebuildEditor();
            panel.UpdateContent();
            SaveSoon();
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or System.Text.DecoderFallbackException)
        { MessageBox.Show(this, error.Message, "Import failed"); }
    }

    private void Export()
    {
        var dialog = new SaveFileDialog { Filter = "Text file|*.txt", FileName = "SmartNotch-" + section, DefaultExt = ".txt" };
        if (dialog.ShowDialog(this) != true) return;
        string content = section switch
        {
            Section.Read => title.Text,
            Section.Notes => title.Notes,
            _ => string.Join("\n\n---\n\n", title.Cards.Select(card =>
                string.Join("\n\n", new[] { (card.Completed ? "[x] " : "[ ] ") + card.Title, card.Details,
                    card.Notes == "" ? "" : "Notes:\n" + card.Notes }.Where(part => part != ""))))
        };
        try { File.WriteAllText(dialog.FileName, content); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        { MessageBox.Show(this, error.Message, "Export failed"); }
    }

    internal void SaveSoon()
    {
        if (!savingEnabled || exiting) return;
        saveTimer.Stop();
        saveTimer.Start();
    }

    private void Save()
    {
        saveTimer.Stop();
        if (!savingEnabled) return;
        try { session.Save(); status.Text = "Saved locally" + shortcutStatus; }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        { status.Text = "Could not save the session. " + error.Message; }
    }

    private void StartNativeControls()
    {
        native = new NativeControls(this, panel);
        if (!native.AllRegistered)
        {
            shortcutStatus = " · Some global shortcuts are unavailable";
            status.Text += shortcutStatus;
        }
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Open editor", null, (_, _) => ShowEditor());
        menu.Items.Add("Show or hide panel", null, (_, _) => panel.Toggle());
        menu.Items.Add("Check for Updates…", null, async (_, _) => await updates.CheckAsync(this));
        var automaticUpdates = new Forms.ToolStripMenuItem("Automatically check for updates") { Checked = updates.AutomaticallyChecks };
        automaticUpdates.Click += (_, _) => { updates.ToggleAutomaticChecks(); automaticUpdates.Checked = updates.AutomaticallyChecks; };
        menu.Items.Add(automaticUpdates);
        menu.Items.Add("Quit SmartNotch", null, (_, _) => Quit());
        using var iconStream = Application.GetResourceStream(new Uri("pack://application:,,,/SmartNotch.ico")).Stream;
        using var loadedIcon = new System.Drawing.Icon(iconStream);
        trayIcon = (System.Drawing.Icon)loadedIcon.Clone();
        tray = new Forms.NotifyIcon { Icon = trayIcon, ContextMenuStrip = menu,
            Text = "SmartNotch", Visible = true };
        tray.DoubleClick += (_, _) => ShowEditor();
    }

    internal void ShowEditor()
    {
        panel.Dismiss();
        Show();
        if (WindowState == WindowState.Minimized) WindowState = WindowState.Normal;
        Activate();
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        if (!exiting) { e.Cancel = true; Hide(); Save(); }
        base.OnClosing(e);
    }

    internal bool SaveBeforeUpdate()
    {
        saveTimer.Stop();
        try
        {
            if (!savingEnabled) throw new IOException("Saving is paused because the saved session could not be opened.");
            session.Save();
            return true;
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            MessageBox.Show("Save your content before restarting. " + error.Message, "Update postponed");
            return false;
        }
    }

    internal void Quit()
    {
        exiting = true;
        updates.Dispose();
        panel.Stop();
        Save();
        native?.Dispose();
        tray?.ContextMenuStrip?.Dispose();
        tray?.Dispose();
        trayIcon?.Dispose();
        Application.Current.Shutdown();
    }

    internal static Button Button(string label, Action click)
    {
        var button = new Button { Content = label, Padding = new Thickness(8, 4, 8, 4),
            Margin = new Thickness(0, 0, 5, 5), Cursor = Cursors.Hand };
        button.Click += (_, _) => click();
        return button;
    }

    internal static WrapPanel Row(params UIElement[] children)
    {
        var row = new WrapPanel();
        foreach (UIElement child in children) row.Children.Add(child);
        return row;
    }

    private static StackPanel Field(string label, string value, Action<string> changed, int height = 0)
    {
        var field = new TextBox { Text = value, Padding = new Thickness(8), AcceptsReturn = height > 0,
            TextWrapping = height > 0 ? TextWrapping.Wrap : TextWrapping.NoWrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        if (height > 0) field.Height = height;
        field.TextChanged += (_, _) => changed(field.Text);
        return Labeled(label, field);
    }

    private static StackPanel Choice(string label, string[] options, string selected, Action<string> changed)
    {
        var picker = new ComboBox { ItemsSource = options, SelectedItem = selected, MinWidth = 85 };
        picker.SelectionChanged += (_, _) => { if (picker.SelectedItem is string value) changed(value); };
        return Labeled(label, picker);
    }

    private static StackPanel SliderField(string label, double min, double max, double value, Action<double> changed)
    {
        var slider = new Slider { Minimum = min, Maximum = max, Value = value, Width = 110, IsSnapToTickEnabled = true, TickFrequency = 1 };
        var field = Labeled($"{label} · {value:0}", slider);
        var caption = (TextBlock)field.Children[0];
        slider.ValueChanged += (_, _) => { caption.Text = $"{label} · {slider.Value:0}"; changed(slider.Value); };
        return field;
    }

    private static StackPanel Labeled(string label, UIElement field)
    {
        var layout = new StackPanel { Margin = new Thickness(0, 8, 8, 8) };
        layout.Children.Add(new TextBlock { Text = label, Margin = new Thickness(0, 0, 0, 4) });
        layout.Children.Add(field);
        return layout;
    }
}
