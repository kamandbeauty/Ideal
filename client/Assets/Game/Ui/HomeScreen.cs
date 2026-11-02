using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// The home hub: who you are (the palace), what you have (the top bar), where you are (the level
    /// card), and the one thing to do next (play). Everything else is one tap away and nothing else
    /// fights for attention — the original's home screen is a single tall illustration with a play
    /// button, and this is the same information hierarchy built from tokens.
    /// </summary>
    public sealed class HomeScreen : UiScreen
    {
        public Action PlayRequested;
        public Action DistrictsRequested;

        TextMeshProUGUI _levelNumber;
        TextMeshProUGUI _progressText;
        TextMeshProUGUI _blockedText;
        TextMeshProUGUI _playLabel;
        RectTransform _progressFill;
        Button _playButton;
        float _progressTrackWidth;

        protected override void Build()
        {
            UiKit.Background(Root, Tokens.Bg);

            // The palace plate. Until the illustration exists (art/manifest.json → home_palace) this is
            // two bands of surface colour: the layout is identical, so replacing the art cannot move a
            // single button.
            var sky = UiKit.Panel(Root, "sky", 0f, 0f, UiKit.CanvasWidth, 300f, Tokens.Surface);
            sky.GetComponent<Image>().raycastTarget = false;
            var skyLower = UiKit.Panel(Root, "sky_lower", 0f, 300f, UiKit.CanvasWidth, 60f, Tokens.Surface);
            skyLower.GetComponent<Image>().raycastTarget = false;

            var palace = UiKit.Panel(Root, "home_palace", 0f, 0f, UiKit.CanvasWidth, 300f, Color.white);
            var palaceImage = palace.GetComponent<Image>();
            palaceImage.raycastTarget = false;
            // Two plates of the same building: the district rebuilt lights the palace, so the home
            // screen itself says what the player just did. Falls back to the night plate whenever the
            // lit one is not in the build.
            string plate = Session != null && Session.IsChapterBuilt && ArtLibrary.Has("home_palace_lit")
                ? "home_palace_lit"
                : "home_palace";
            if (ArtLibrary.ApplyTo(palaceImage, plate))
            {
                sky.gameObject.SetActive(false);
                skyLower.gameObject.SetActive(false);
            }
            else
            {
                palace.gameObject.SetActive(false);
            }

            var title = UiKit.LabelBold(Root, "title", "کاخِ شازده", Tokens.Type.Display, Tokens.Text, TextAlignmentOptions.Center);
            UiKit.Place(title.rectTransform, 0f, 96f, UiKit.CanvasWidth, 48f);

            UiKit.Rule(Root, (UiKit.CanvasWidth - 96f) * 0.5f, 150f, 96f, Tokens.Gold, 2f);

            var subtitle = UiKit.Label(Root, "subtitle", "فصل یک · میدانِ فیروزه", Tokens.Type.Sm, Tokens.TextMuted, TextAlignmentOptions.Center);
            UiKit.Place(subtitle.rectTransform, 0f, 162f, UiKit.CanvasWidth, 22f);

            BuildLevelCard();

            _playButton = UiKit.Button(Root, "play", "شروع", 20f, 528f, UiKit.CanvasWidth - 40f, 56f,
                Tokens.Accent, Tokens.OnAccent, () => PlayRequested?.Invoke(), (int)Tokens.Radius.Md);
            _playLabel = _playButton.GetComponentInChildren<TextMeshProUGUI>();

            // The drawn enamel face, when it exists: same button, better material. The label stays a
            // TMP child, so a missing sprite costs nothing but the flat colour underneath.
            UiKit.StyleButton(_playButton, "button_primary", 18);

            UiKit.Button(Root, "districts", "ناحیه‌ها", 20f, 596f, UiKit.CanvasWidth - 40f, 48f,
                Tokens.SurfaceRaised, Tokens.Text, () => DistrictsRequested?.Invoke(), (int)Tokens.Radius.Md);

            _blockedText = UiKit.Label(Root, "blocked", "", Tokens.Type.Sm, Tokens.Warning, TextAlignmentOptions.Center);
            UiKit.Place(_blockedText.rectTransform, 20f, 656f, UiKit.CanvasWidth - 40f, 22f);

            var footer = UiKit.Label(Root, "footer", "بدون اینترنت هم بازی می‌شود", Tokens.Type.Xs, Tokens.TextMuted, TextAlignmentOptions.Center);
            UiKit.Place(footer.rectTransform, 20f, 700f, UiKit.CanvasWidth - 40f, 18f);
        }

        void BuildLevelCard()
        {
            var card = UiKit.PanelArt(Root, "level_card", 20f, 208f, UiKit.CanvasWidth - 40f, 288f,
                "panel_frame", 22, Tokens.Surface, (int)Tokens.Radius.Panel);
            card.GetComponent<Image>().raycastTarget = false;

            var caption = UiKit.LabelRight(card, "caption", "مرحلهٔ بعدی", Tokens.Type.Sm, Tokens.TextMuted);
            UiKit.Place(caption.rectTransform, 20f, 16f, card.sizeDelta.x - 40f, 22f);

            _levelNumber = UiKit.LabelBold(card, "level", "", Tokens.Type.Display, Tokens.Gold, TextAlignmentOptions.Right);
            UiKit.Place(_levelNumber.rectTransform, 20f, 40f, card.sizeDelta.x - 40f, 52f);

            var track = UiKit.Panel(card, "progress_track", 20f, 108f, card.sizeDelta.x - 40f, 10f,
                Tokens.SurfaceRaised, 5);
            _progressTrackWidth = track.sizeDelta.x;

            _progressFill = UiKit.Panel(track, "progress_fill", 0f, 0f, 0f, 10f, Tokens.Accent, 5);
            _progressFill.anchorMin = new Vector2(1f, 1f); // fills from the right: RTL progress
            _progressFill.anchorMax = new Vector2(1f, 1f);
            _progressFill.pivot = new Vector2(1f, 1f);
            _progressFill.anchoredPosition = Vector2.zero;
            _progressFill.sizeDelta = new Vector2(0f, 10f);

            _progressText = UiKit.LabelRight(card, "progress", "", Tokens.Type.Sm, Tokens.TextMuted);
            UiKit.Place(_progressText.rectTransform, 20f, 126f, card.sizeDelta.x - 40f, 22f);

            var potions = UiKit.LabelRight(card, "potions_hint", "برای ساخت ناحیه‌ها معجون لازم است", Tokens.Type.Xs, Tokens.TextMuted);
            UiKit.Place(potions.rectTransform, 20f, 236f, card.sizeDelta.x - 40f, 20f);
        }

        public override void Refresh()
        {
            if (Session == null) return;

            int level = Session.CurrentLevel;
            RtlText.Set(_levelNumber, Core.Text.PersianText.Number(level));

            int cleared = Session.ClearedCount;
            RtlText.Set(_progressText, Core.Text.PersianText.Number(cleared) + " از " +
                Core.Text.PersianText.Number(Session.LevelCount) + " مرحله تمام شده");

            float ratio = Session.LevelCount <= 0 ? 0f : Mathf.Clamp01((float)cleared / Session.LevelCount);
            _progressFill.sizeDelta = new Vector2(_progressTrackWidth * ratio, _progressFill.sizeDelta.y);

            string blocked = Session.BlockedReason(level);
            RtlText.Set(_blockedText, blocked ?? "");

            _playButton.interactable = blocked == null;
            RtlText.Set(_playLabel, cleared == 0 ? "شروع" : "ادامه");
        }
    }
}
