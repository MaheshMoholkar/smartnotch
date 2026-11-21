using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace SmartNotch;

internal enum Section { Read, Cards, Notes }

internal sealed class Session
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, WriteIndented = true };
    public static readonly string Path = Environment.GetEnvironmentVariable("SMARTNOTCH_SESSION_PATH") ??
        System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "MaheshLabs", "SmartNotch", "session.json");

    public string Text { get; set; } = "Welcome to SmartNotch.\n\nHover at the top center of your screen to open the floating panel. Pin it to keep it open while you work.\n\nUse Read for a script, Cards for talking points, and Notes for anything you want to keep in view.";
    public string? WorkspaceTab { get; set; }
    public string Mode { get; set; } = "Auto-scroll";
    public double Speed { get; set; } = 150;
    public double PlaybackRate { get; set; } = 1;
    public bool OpenOnHover { get; set; } = true;
    public List<Title> Chapters { get; set; } = [];
    public Dictionary<string, Guid> TitleSelections { get; set; } = [];
    public Dictionary<string, Appearance> WorkspaceAppearances { get; set; } = [];
    public Guid? ActiveChapterID { get; set; }

    public static Session Load()
    {
        var session = File.Exists(Path) ? JsonSerializer.Deserialize<Session>(File.ReadAllText(Path), Json)
            ?? throw new JsonException("The session is empty.") : new Session();
        if (session.Mode != "Manual") session.Mode = "Auto-scroll";
        session.Speed = Math.Clamp(session.Speed, 60, 240);
        session.PlaybackRate = Math.Clamp(session.PlaybackRate, 0.5, 2);
        session.Chapters ??= [];
        session.TitleSelections ??= [];
        session.WorkspaceAppearances ??= [];
        var active = session.Chapters.FirstOrDefault(title => title.Id == session.ActiveChapterID);
        session.WorkspaceTab ??= active?.Workspace ?? active?.SelectedTab ?? "Read";
        if (!Enum.GetNames<Section>().Contains(session.WorkspaceTab)) session.WorkspaceTab = "Read";
        foreach (var title in session.Chapters.ToArray())
        {
            title.Cards ??= [];
            title.ReadingPosition ??= new ReadingPosition();
            title.Text ??= "";
            title.Notes ??= "";
            if (title.Workspace is not null) continue;
            title.Workspace = "Read";
            if (title.Cards.Count > 0)
            {
                var deck = new Title { Name = title.Name, Workspace = "Cards", Cards = title.Cards, SelectedCardID = title.SelectedCardID };
                session.Chapters.Add(deck);
                if (title.Id == session.ActiveChapterID) session.TitleSelections["Cards"] = deck.Id;
                title.Cards = [];
                title.SelectedCardID = null;
            }
            if (!string.IsNullOrEmpty(title.Notes))
            {
                var notes = new Title { Name = title.Name, Workspace = "Notes", Notes = title.Notes };
                session.Chapters.Add(notes);
                if (title.Id == session.ActiveChapterID) session.TitleSelections["Notes"] = notes.Id;
                title.Notes = "";
            }
        }
        foreach (var section in Enum.GetNames<Section>())
        {
            if (!session.Chapters.Any(title => title.Workspace == section))
                session.Chapters.Add(new Title { Workspace = section, Text = section == "Read" ? session.Text : "" });
            if (!session.WorkspaceAppearances.TryGetValue(section, out var appearance))
                session.WorkspaceAppearances[section] = appearance = new Appearance();
            appearance.OpenOnHover ??= session.OpenOnHover;
            appearance.TextSize = Math.Clamp(appearance.TextSize, 18, 36);
            appearance.Width = Math.Clamp(appearance.Width, 360, 760);
            appearance.Height = Math.Clamp(appearance.Height, 220, 700);
            appearance.Transparency = Math.Clamp(appearance.Transparency, 0, 100);
        }
        return session;
    }

    public void Save()
    {
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(System.IO.Path.GetFullPath(Path))!);
        string temporary = Path + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(this, Json));
        File.Move(temporary, Path, overwrite: true);
    }
}

internal sealed class Title
{
    public Guid Id { get; set; } = Guid.NewGuid();
    [System.Text.Json.Serialization.JsonPropertyName("title")]
    public string Name { get; set; } = "Title 1";
    public string? Workspace { get; set; }
    public string Text { get; set; } = "";
    public string Notes { get; set; } = "";
    public List<Card> Cards { get; set; } = [];
    public Guid? SelectedCardID { get; set; }
    public string? SelectedTab { get; set; }
    public ReadingPosition ReadingPosition { get; set; } = new();
    public override string ToString() => string.IsNullOrWhiteSpace(Name) ? "Untitled" : Name;
}

internal sealed class Card
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Title { get; set; } = "";
    public string Details { get; set; } = "";
    public string Notes { get; set; } = "";
    public bool Completed { get; set; }
    public override string ToString() => (Completed ? "✓  " : "○  ") + (string.IsNullOrWhiteSpace(Title) ? "Untitled card" : Title);
}

internal sealed class Appearance
{
    public double TextSize { get; set; } = 24;
    public double Width { get; set; } = 580;
    public double Height { get; set; } = 300;
    public double Transparency { get; set; }
    public string Ink { get; set; } = "Soft cyan";
    public bool? OpenOnHover { get; set; }
}

internal sealed class ReadingPosition
{
    public int WordIndex { get; set; }
    public double WordProgress { get; set; }
    public bool Finished { get; set; }
}

internal sealed class Script(string text)
{
    public Match[] Words { get; } = Regex.Matches(text, @"\S+").ToArray();

    public int Paragraph(int current, bool forward)
    {
        if (Words.Length == 0) return 0;
        for (int index = forward ? current + 1 : current - 1;
             index > 0 && index < Words.Length; index += forward ? 1 : -1)
        {
            var previous = Words[index - 1];
            if (text.AsSpan(previous.Index + previous.Length, Words[index].Index - previous.Index - previous.Length)
                .IndexOfAny('\n', '\r', '\u2029') >= 0) return index;
        }
        return forward ? current : 0;
    }

    public void Advance(ReadingPosition position, double elapsed, double wordsPerMinute)
    {
        if (Words.Length == 0 || position.Finished) return;
        double progress = position.WordProgress + elapsed * wordsPerMinute / 60;
        int wholeWords = (int)progress;
        int index = position.WordIndex + wholeWords;
        position.WordIndex = Math.Min(index, Words.Length - 1);
        position.Finished = index >= Words.Length;
        position.WordProgress = position.Finished ? 0 : progress - wholeWords;
    }
}
