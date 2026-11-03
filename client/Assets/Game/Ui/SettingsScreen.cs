using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// The settings screen: four switches, and nothing else.
    ///
    /// It exists now because the flags it edits already did — `SaveData.musicOn`, `sfxOn`,
    /// `hapticsOn`, `pushOn` have been in the save since M1 and gated nothing, which is the worst
    /// of both worlds: a promise in the save file and no way to reach it. Each switch writes the flag
    /// and saves immediately; there is no "apply" button, because a toggle the player has to confirm
    /// is a toggle players forget they changed.
    ///
    /// The four icons have been in the art contract since M3 (`icon_sound`, `icon_music`,
    /// `icon_vibration`, `icon_push`), so the screen was blocked on the screen, not the art.
    ///
    /// It does not implement audio or haptics: it is the switch panel they will read. Claiming
    /// otherwise on a screen the player can see would be a lie about the build.
    /// </summary>
    public sealed class SettingsScreen : UiScreen
    {
        public Action BackRequested;

        enum ToggleKind
        {
            Sfx,
            Music,
            Haptics,
            Push
        }

        sealed class Switch
        {
            public ToggleKind Kind;
            public Image Track;
            public RectTransform Knob;
            public TextMeshProUGUI State;
        }

        const float RowHeight = 64f;
        const float RowGap = 12f;
        const float FirstRowY = 176f;
        const float TrackWidth = 56f;
        const float TrackHeight = 30f;
        const float KnobSize = 24f;

        readonly Switch[] _switches =
        {
            new Switch { Kind = ToggleKind.Sfx },
            new Switch { Kind = ToggleKind.Music },
            new Switch { Kind = ToggleKind.Haptics },
            new Switch { Kind = ToggleKind.Push },
        };

        protected override void Build()
        {
            UiKit.Background(Root, Tokens.Bg);

            var title = UiKit.LabelBold(Root, "title", "تنظیمات", Tokens.Type.Xl, Tokens.Text, TextAlignmentOptions.Center);
            UiKit.Place(title.rectTransform, 0f, 96f, UiKit.CanvasWidth, 34f);

            UiKit.Rule(Root, (UiKit.CanvasWidth - 64f) * 0.5f, 136f, 64f, Tokens.Gold, 2f);

            var note = UiKit.Label(Root, "note", "روی همین دستگاه ذخیره می‌شود", Tokens.Type.Xs, Tokens.TextMuted,
                TextAlignmentOptions.Center);
            UiKit.Place(note.rectTransform, 20f, 146f, UiKit.CanvasWidth - 40f, 18f);

            AddRow(_switches[0], "icon_sound", "صدا", "افکت‌های بازی");
            AddRow(_switches[1], "icon_music", "موسیقی", "موسیقی پس‌زمینه");
            AddRow(_switches[2], "icon_vibration", "لرزش", "بازخورد لمسی");
            AddRow(_switches[3], "icon_push", "یادآور", "یادآوری جان‌ها");

            // Said on the screen, not only in a comment: a switch that does nothing is a bug the
            // player cannot see, and the honest version costs one line of muted text.
            var honest = UiKit.Label(Root, "honest", "صدا و لرزش در این نسخه وصل نشده‌اند", Tokens.Type.Xs,
                Tokens.TextMuted, TextAlignmentOptions.Center);
            UiKit.Place(honest.rectTransform, 20f, 560f, UiKit.CanvasWidth - 40f, 18f);

            UiKit.Button(Root, "back", "بازگشت", 20f, 648f, UiKit.CanvasWidth - 40f, 48f,
                Tokens.SurfaceRaised, Tokens.Text, () => BackRequested?.Invoke(), (int)Tokens.Radius.Md);

            var footer = UiKit.Label(Root, "footer", "کاخِ شازده · نسخهٔ ۰٫۵", Tokens.Type.Xs, Tokens.TextMuted,
                TextAlignmentOptions.Center);
            UiKit.Place(footer.rectTransform, 20f, 704f, UiKit.CanvasWidth - 40f, 18f);
        }

        /// <summary>
        /// One row: a whole 375 × 64 target, not a 30 px switch. The row is the button, the switch is
        /// the state — which is also why the mode is written twice, as a knob position and as a word.
        /// </summary>
        void AddRow(Switch toggle, string iconId, string label, string caption)
        {
            int index = Array.IndexOf(_switches, toggle);
            float y = FirstRowY + index * (RowHeight + RowGap);
            float width = UiKit.CanvasWidth - 40f;

            var row = UiKit.Panel(Root, "row_" + toggle.Kind, 20f, y, width, RowHeight, Tokens.Surface,
                (int)Tokens.Radius.Md);
            var face = row.GetComponent<Image>();
            face.raycastTarget = true;

            var button = row.gameObject.AddComponent<Button>();
            button.targetGraphic = face;
            var colors = button.colors;
            colors.normalColor = Color.white;
            colors.highlightedColor = new Color(1.06f, 1.06f, 1.06f, 1f);
            colors.pressedColor = new Color(0.9f, 0.9f, 0.9f, 1f);
            colors.fadeDuration = Tokens.Motion.Fast;
            button.colors = colors;
            var kind = toggle.Kind;
            button.onClick.AddListener(() => Toggle(kind));

            // the switch, on the left: a track and a knob drawn from the same rounded sprite the rest
            // of the UI uses, so it needs no art and scales with the canvas
            toggle.Track = UiKit.Panel(row, "track", 16f, (RowHeight - TrackHeight) * 0.5f, TrackWidth, TrackHeight,
                Tokens.SurfaceRaised, (int)Tokens.Radius.Pill).GetComponent<Image>();
            toggle.Knob = UiKit.Panel(toggle.Track.transform, "knob", 3f, (TrackHeight - KnobSize) * 0.5f,
                KnobSize, KnobSize, Tokens.TextMuted, (int)Tokens.Radius.Pill);

            toggle.State = UiKit.Label(row, "state", "", Tokens.Type.Sm, Tokens.TextMuted, TextAlignmentOptions.Left);
            UiKit.Place(toggle.State.rectTransform, 84f, (RowHeight - 20f) * 0.5f, 64f, 20f);

            // the icon sits on the reading side, then the label, then the caption under it
            const float iconSize = 26f;
            float textRight = width - 16f;
            if (ArtLibrary.Has(iconId))
            {
                var icon = UiKit.Panel(row, "icon", width - 16f - iconSize, (RowHeight - iconSize) * 0.5f,
                    iconSize, iconSize, Color.white);
                var image = icon.GetComponent<Image>();
                image.raycastTarget = false;
                if (ArtLibrary.ApplyTo(image, iconId)) textRight = width - 16f - iconSize - 10f;
                else icon.gameObject.SetActive(false);
            }

            var name = UiKit.LabelRight(row, "label", label, Tokens.Type.Base, Tokens.Text);
            UiKit.Place(name.rectTransform, 160f, 10f, textRight - 160f, 22f);

            var hint = UiKit.LabelRight(row, "caption", caption, Tokens.Type.Xs, Tokens.TextMuted);
            UiKit.Place(hint.rectTransform, 160f, 34f, textRight - 160f, 18f);
        }

        void Toggle(ToggleKind kind)
        {
            if (Session == null) return;

            var save = Session.Save;
            switch (kind)
            {
                case ToggleKind.Sfx: save.sfxOn = !save.sfxOn; break;
                case ToggleKind.Music: save.musicOn = !save.musicOn; break;
                case ToggleKind.Haptics: save.hapticsOn = !save.hapticsOn; break;
                case ToggleKind.Push: save.pushOn = !save.pushOn; break;
            }

            // Straight to disk: a player who silences the game and kills the app has silenced it.
            Session.SaveNow();
        }

        public override void Refresh()
        {
            if (Session == null) return;

            for (int i = 0; i < _switches.Length; i++)
            {
                var toggle = _switches[i];
                if (toggle.Track == null) continue;

                bool on = IsOn(toggle.Kind);
                toggle.Track.color = on ? Tokens.Accent : Tokens.SurfaceRaised;
                // RTL: "on" is the knob at the left end of the track, the direction the eye leaves in.
                toggle.Knob.anchoredPosition = new Vector2(on ? 3f : TrackWidth - KnobSize - 3f, toggle.Knob.anchoredPosition.y);
                toggle.Knob.GetComponent<Image>().color = on ? Tokens.OnAccent : Tokens.TextMuted;
                toggle.State.color = on ? Tokens.Accent : Tokens.TextMuted;
                RtlText.Set(toggle.State, on ? "روشن" : "خاموش");
            }
        }

        bool IsOn(ToggleKind kind)
        {
            var save = Session.Save;
            switch (kind)
            {
                case ToggleKind.Sfx: return save.sfxOn;
                case ToggleKind.Music: return save.musicOn;
                case ToggleKind.Haptics: return save.hapticsOn;
                default: return save.pushOn;
            }
        }
    }
}
