using System;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using Shazdeh.Content;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// The meta layer, on one screen: every district of the chapter, its tasks, their prices in potions,
    /// and the chest that opens when the district is finished.
    ///
    /// It is deliberately a list and not a map. The world map is a later milestone; what matters now is
    /// that the bridge between the puzzle and the palace works and is readable: earn potions on the
    /// board, spend them here, watch a district fill up.
    /// </summary>
    public sealed class DistrictScreen : UiScreen
    {
        public Action BackRequested;

        sealed class Row
        {
            public DistrictDefinition District;
            public readonly List<Button> TaskButtons = new List<Button>(4);
            public readonly List<TextMeshProUGUI> TaskLabels = new List<TextMeshProUGUI>(4);
            public TextMeshProUGUI Title;
            public TextMeshProUGUI Progress;
            public Button BuildAll;
            public TextMeshProUGUI BuildAllLabel;
            public Button Chest;
            public TextMeshProUGUI ChestLabel;
            public Image ChestIcon;
            public Image Plate;
            public string PlateKey;
            public bool ChestWasOpen;
            public float ChestPopAt = -1f;
        }

        readonly List<Row> _rows = new List<Row>(3);
        TextMeshProUGUI _potions;

        // The chest's payoff. One burst object for the whole screen: a second chest opening while the
        // first is still in the air restarts the same burst instead of stacking a second one.
        Image _coinBurst;
        float _coinBurstAt = -1f;
        const float CoinBurstSeconds = 0.90f;

        protected override void Build()
        {
            UiKit.Background(Root, Tokens.Bg);

            var title = UiKit.LabelBold(Root, "title", "ناحیه‌های فصل یک", Tokens.Type.Xl, Tokens.Text, TextAlignmentOptions.Center);
            UiKit.Place(title.rectTransform, 0f, 100f, UiKit.CanvasWidth, 32f);

            _potions = UiKit.Label(Root, "potions", "", Tokens.Type.Sm, Tokens.Accent, TextAlignmentOptions.Center);
            UiKit.Place(_potions.rectTransform, 0f, 134f, UiKit.CanvasWidth, 22f);

            UiKit.Button(Root, "back", "بازگشت", UiKit.CanvasWidth - 20f - 96f, 44f, 96f, 44f,
                Tokens.SurfaceRaised, Tokens.Text, () => BackRequested?.Invoke(), (int)Tokens.Radius.Md);

            BuildRows();
        }

        void BuildRows()
        {
            var districts = Session?.Meta?.Districts;
            if (districts == null || districts.Count == 0)
            {
                var empty = UiKit.Label(Root, "empty", "ناحیه‌ای بارگذاری نشد", Tokens.Type.Base, Tokens.Danger, TextAlignmentOptions.Center);
                UiKit.Place(empty.rectTransform, 20f, 220f, UiKit.CanvasWidth - 40f, 24f);
                return;
            }

            float cardWidth = UiKit.CanvasWidth - 40f;
            for (int i = 0; i < districts.Count && i < 3; i++)
            {
                var row = new Row { District = districts[i] };
                float y = 168f + i * 190f;
                BuildCard(row, cardWidth, y);
                _rows.Add(row);
            }
        }

        void BuildCard(Row row, float cardWidth, float y)
        {
            var card = UiKit.Panel(Root, "district_" + row.District.Id, 20f, y, cardWidth, 176f,
                Tokens.Surface, (int)Tokens.Radius.Panel);

            // The district plate (art/district_<id>.png) sits under the tasks when it exists. Its
            // colours are the artist's; the tasks stay on a dimmed band so the labels keep their contrast.
            var plate = UiKit.Panel(card, "plate", 0f, 0f, cardWidth, 176f, new Color(1f, 1f, 1f, 0f), (int)Tokens.Radius.Panel);
            row.Plate = plate.GetComponent<Image>();
            row.Plate.raycastTarget = false;
            row.PlateKey = "district_" + row.District.Id.Replace('-', '_');
            plate.SetAsFirstSibling();

            row.Title = UiKit.LabelRight(card, "title", row.District.Title, Tokens.Type.Lg, Tokens.Text);
            UiKit.Place(row.Title.rectTransform, 16f, 12f, cardWidth - 100f, 26f);

            row.Progress = UiKit.LabelLeft(card, "progress", "", Tokens.Type.Xs, Tokens.TextMuted);
            UiKit.Place(row.Progress.rectTransform, cardWidth - 96f, 18f, 80f, 20f);

            // Four tasks: two columns, two rows, first task top-right because the layout reads RTL.
            float pillWidth = 160f;
            float pillHeight = 34f;
            float rightX = cardWidth - 16f - pillWidth;
            float leftX = rightX - Tokens.Space.S2 - pillWidth;

            for (int t = 0; t < row.District.Tasks.Count && t < 4; t++)
            {
                var task = row.District.Tasks[t];
                float x = t % 2 == 0 ? rightX : leftX;
                float pillY = 48f + (t / 2) * (pillHeight + Tokens.Space.S2);

                var capturedTask = task;
                var button = UiKit.Button(card, "task_" + task.Key, TaskText(task), x, pillY, pillWidth, pillHeight,
                    Tokens.SurfaceRaised, Tokens.Text, () => Session.BuildTask(row.District, capturedTask),
                    (int)Tokens.Radius.Sm);

                row.TaskButtons.Add(button);
                row.TaskLabels.Add(button.GetComponentInChildren<TextMeshProUGUI>());
            }

            row.BuildAll = UiKit.Button(card, "build_all", "همه را بساز", 16f, 132f, 200f, 34f,
                Tokens.Accent, Tokens.OnAccent, () => Session.BuildDistrict(row.District), (int)Tokens.Radius.Sm);
            row.BuildAllLabel = row.BuildAll.GetComponentInChildren<TextMeshProUGUI>();

            row.Chest = UiKit.Button(card, "chest", "صندوق", cardWidth - 16f - 127f, 132f, 127f, 34f,
                Tokens.Gold, Tokens.OnGold, () => Session.OpenChest(row.District), (int)Tokens.Radius.Sm);
            row.ChestLabel = row.Chest.GetComponentInChildren<TextMeshProUGUI>();

            // The chest is an object, not a word: the sprite sits inside the button and becomes the
            // open chest the moment the district is finished, with one pop.
            var icon = UiKit.Panel(row.Chest.transform, "chest_icon", 127f - 26f - 6f, 4f, 26f, 26f,
                new Color(1f, 1f, 1f, 0f));
            row.ChestIcon = icon.GetComponent<Image>();
            row.ChestIcon.raycastTarget = false;
            UiKit.Place(row.ChestLabel.rectTransform, 6f, 0f, 127f - 38f, 34f);
        }

        static string TaskText(TaskDefinition task) =>
            task.Title + " " + Core.Text.PersianText.Number(task.PotionCost);

        public override void Refresh()
        {
            if (Session == null) return;

            RtlText.Set(_potions, Core.Text.PersianText.Number(Session.Wallet.Potions) + " معجون در دسترس");

            for (int i = 0; i < _rows.Count; i++)
            {
                var row = _rows[i];
                var district = row.District;

                int done = 0;
                for (int t = 0; t < row.TaskButtons.Count && t < district.Tasks.Count; t++)
                {
                    var task = district.Tasks[t];
                    bool complete = Session.IsTaskDone(task);

                    row.TaskButtons[t].interactable = !complete && Session.Wallet.CanAffordPotions(task.PotionCost);
                    var image = row.TaskButtons[t].targetGraphic as Image;
                    if (image != null) image.color = complete ? Tokens.AccentStrong : Tokens.SurfaceRaised;

                    RtlText.Set(row.TaskLabels[t], complete
                        ? task.Title + " " + DoneWord
                        : TaskText(task));

                    if (complete) done++;
                }

                long remaining = Session.RemainingPotions(district);
                bool built = Session.IsDistrictBuilt(district);
                bool chestOpen = Session.IsChestOpen(district);

                RtlText.Set(row.Progress, Core.Text.PersianText.Number(done) + " از " +
                    Core.Text.PersianText.Number(district.Tasks.Count));

                row.BuildAll.gameObject.SetActive(!built);
                row.BuildAll.interactable = !built && Session.Wallet.CanAffordPotions(remaining) && remaining > 0;
                RtlText.Set(row.BuildAllLabel, "همه را بساز " + Core.Text.PersianText.Number(remaining));

                row.Chest.interactable = built && !chestOpen;
                if (chestOpen) RtlText.Set(row.ChestLabel, "باز شد");
                else if (built) RtlText.Set(row.ChestLabel, "باز کن");
                else RtlText.Set(row.ChestLabel, "صندوق");

                if (chestOpen && !row.ChestWasOpen)
                {
                    row.ChestWasOpen = true;
                    row.ChestPopAt = Time.unscaledTime;
                    SpawnCoinBurst(row);
                }

                RefreshChestIcon(row, chestOpen);
                RefreshPlate(row, built);
            }
        }

        void RefreshChestIcon(Row row, bool chestOpen)
        {
            if (row.ChestIcon == null) return;

            string id = chestOpen ? "reward_chest_open" : "reward_chest";
            if (ArtLibrary.ApplyTo(row.ChestIcon, id)) return;

            // No chest art: the button keeps its word, and the icon takes itself out of the layout.
            row.ChestIcon.gameObject.SetActive(false);
        }

        /// <summary>
        /// A finished district switches to its lit plate — same camera, same wall, lamps on. The plate
        /// stays dimmed so the task labels keep their contrast; only the alpha moves, by a little.
        /// </summary>
        void RefreshPlate(Row row, bool built)
        {
            if (row.Plate == null) return;

            string id = built ? row.PlateKey + "_lit" : row.PlateKey;
            if (!ArtLibrary.ApplyTo(row.Plate, id) && built && !ArtLibrary.ApplyTo(row.Plate, row.PlateKey))
            {
                row.Plate.gameObject.SetActive(false);
                return;
            }

            row.Plate.color = built ? new Color(1f, 1f, 1f, 0.46f) : new Color(1f, 1f, 1f, 0.35f);
        }

        /// <summary>
        /// The coins the chest paid out, thrown once over the chest button. Built on first use, hidden
        /// when the art is missing, and animated by the same unscaled clock as the pop.
        /// </summary>
        void SpawnCoinBurst(Row row)
        {
            if (row.ChestIcon == null) return;

            if (_coinBurst == null)
            {
                var go = UiKit.Panel(Root, "coin_burst", 0f, 0f, 96f, 96f, Color.white);
                _coinBurst = go.GetComponent<Image>();
                _coinBurst.raycastTarget = false;
                if (!ArtLibrary.ApplyTo(_coinBurst, "fx_coins"))
                {
                    go.SetActive(false);
                    _coinBurst = null;
                    return;
                }
            }

            var anchor = row.ChestIcon.rectTransform;
            var rt = _coinBurst.rectTransform;
            rt.SetParent(anchor.parent, false);
            rt.SetAsLastSibling();
            rt.anchoredPosition = anchor.anchoredPosition;
            rt.sizeDelta = new Vector2(96f, 96f);
            _coinBurst.gameObject.SetActive(true);
            _coinBurstAt = Time.unscaledTime;
        }

        /// <summary>One pop when a chest opens: 350 ms, no coroutine, nothing allocated.</summary>
        void Update()
        {
            for (int i = 0; i < _rows.Count; i++)
            {
                var row = _rows[i];
                if (row.ChestPopAt < 0f || row.ChestIcon == null) continue;

                float t = Mathf.Clamp01((Time.unscaledTime - row.ChestPopAt) / 0.35f);
                row.ChestIcon.rectTransform.localScale = Vector3.one * (1f + 0.45f * Mathf.Sin(t * Mathf.PI));
                if (t >= 1f) row.ChestPopAt = -1f;
            }

            if (_coinBurst != null && _coinBurstAt >= 0f)
            {
                float t = Mathf.Clamp01((Time.unscaledTime - _coinBurstAt) / CoinBurstSeconds);
                float grow = 1f - (1f - t) * (1f - t);           // fast out, then settle
                _coinBurst.rectTransform.localScale = Vector3.one * (0.55f + 0.75f * grow);
                float fade = Mathf.Clamp01((1f - t) / 0.45f);     // hold, then fall away
                _coinBurst.color = new Color(1f, 1f, 1f, fade);
                if (t >= 1f)
                {
                    _coinBurstAt = -1f;
                    _coinBurst.gameObject.SetActive(false);
                }
            }
        }

        const string DoneWord = "ساخته شد";
    }
}
