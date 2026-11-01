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
        }

        readonly List<Row> _rows = new List<Row>(3);
        TextMeshProUGUI _potions;

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
            var plateImage = plate.GetComponent<Image>();
            plateImage.raycastTarget = false;
            if (ArtLibrary.ApplyTo(plateImage, "district_" + row.District.Id.Replace('-', '_')))
            {
                plateImage.color = new Color(1f, 1f, 1f, 0.35f);
                plate.SetAsFirstSibling();
            }
            else
            {
                plate.gameObject.SetActive(false);
            }

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
            }
        }

        const string DoneWord = "ساخته شد";
    }
}
