using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using Shazdeh.Core;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// The booster shop: five boosters, five prices, coins. It closes the one hole the booster bar
    /// left — <see cref="GameSession.BuyBooster"/> has been priced and tested since M4, and nothing
    /// opened it, so a player who spent their starter boosters could never get another one.
    ///
    /// All the rules live in <see cref="BoosterBag.Buy"/>: all-or-nothing, capped at
    /// `BoosterCatalog.MaxOwned`, and it refuses before it spends. This screen's job is to *show*
    /// those rules — a full row says so, an unaffordable row is off — rather than to re-implement them.
    /// </summary>
    public sealed class ShopScreen : UiScreen
    {
        public Action BackRequested;

        sealed class Row
        {
            public BoosterKind Kind;
            public Button Buy;
            public TextMeshProUGUI BuyLabel;
            public TextMeshProUGUI Price;
            public TextMeshProUGUI Owned;
        }

        static readonly BoosterKind[] Kinds =
        {
            BoosterKind.Mallet, BoosterKind.Ram, BoosterKind.Auger, BoosterKind.Whirlwind, BoosterKind.Falcon
        };

        const float RowHeight = 76f;
        const float RowGap = 10f;
        const float FirstRowY = 176f;

        readonly Row[] _rows = new Row[Kinds.Length];

        TextMeshProUGUI _hint;
        float _hintUntil;

        protected override void Build()
        {
            UiKit.Background(Root, Tokens.Bg);

            var title = UiKit.LabelBold(Root, "title", "فروشگاه", Tokens.Type.Xl, Tokens.Text, TextAlignmentOptions.Center);
            UiKit.Place(title.rectTransform, 0f, 96f, UiKit.CanvasWidth, 34f);

            UiKit.Rule(Root, (UiKit.CanvasWidth - 64f) * 0.5f, 136f, 64f, Tokens.Gold, 2f);

            var note = UiKit.Label(Root, "note", "با سکه؛ از هر بوستر ۹ عدد جا داری", Tokens.Type.Xs, Tokens.TextMuted,
                TextAlignmentOptions.Center);
            UiKit.Place(note.rectTransform, 20f, 146f, UiKit.CanvasWidth - 40f, 18f);

            for (int i = 0; i < Kinds.Length; i++) BuildRow(i);

            _hint = UiKit.Label(Root, "hint", "", Tokens.Type.Sm, Tokens.Warning, TextAlignmentOptions.Center);
            UiKit.Place(_hint.rectTransform, 20f, 606f, UiKit.CanvasWidth - 40f, 22f);

            UiKit.Button(Root, "back", "بازگشت", 20f, 648f, UiKit.CanvasWidth - 40f, 48f,
                Tokens.SurfaceRaised, Tokens.Text, () => BackRequested?.Invoke(), (int)Tokens.Radius.Md);
        }

        void BuildRow(int index)
        {
            var kind = Kinds[index];
            var row = new Row { Kind = kind };
            _rows[index] = row;

            float y = FirstRowY + index * (RowHeight + RowGap);
            float width = UiKit.CanvasWidth - 40f;

            var card = UiKit.Panel(Root, "row_" + kind, 20f, y, width, RowHeight, Tokens.Surface,
                (int)Tokens.Radius.Md);
            card.GetComponent<Image>().raycastTarget = false;

            // the badge, on the reading side
            const float badge = 48f;
            var icon = UiKit.Panel(card, "badge", width - 16f - badge, (RowHeight - badge) * 0.5f, badge, badge,
                Color.white);
            var image = icon.GetComponent<Image>();
            image.raycastTarget = false;
            if (!ArtLibrary.ApplyTo(image, "booster_" + kind.ToString().ToLowerInvariant())) icon.gameObject.SetActive(false);

            float nameRight = width - 16f - badge - 10f;

            var name = UiKit.LabelRight(card, "name", BoosterCatalog.Name(kind), Tokens.Type.Base, Tokens.Text);
            UiKit.Place(name.rectTransform, 116f, 12f, nameRight - 116f, 22f);

            // price and count share one line, one at each end: they are the same fact about the row
            // ("costs 60, you have 2") and stacking them made the row read as two rows.
            row.Price = UiKit.LabelRight(card, "price", "", Tokens.Type.Sm, Tokens.Gold);
            UiKit.Place(row.Price.rectTransform, 210f, 42f, nameRight - 210f, 20f);

            row.Owned = UiKit.Label(card, "owned", "", Tokens.Type.Xs, Tokens.TextMuted, TextAlignmentOptions.Left);
            UiKit.Place(row.Owned.rectTransform, 116f, 44f, 92f, 18f);

            row.Buy = UiKit.Button(card, "buy", "خرید", 16f, (RowHeight - 36f) * 0.5f, 92f, 36f,
                Tokens.Accent, Tokens.OnAccent, () => Buy(kind), (int)Tokens.Radius.Sm);
            row.BuyLabel = row.Buy.GetComponentInChildren<TextMeshProUGUI>();
        }

        void Buy(BoosterKind kind)
        {
            if (Session == null) return;

            if (Session.BuyBooster(kind))
            {
                _hintUntil = 0f; // a success clears the warning: the row it warned about just changed
                Refresh();
                return;
            }

            // The only way a buy fails with the button live is a coin balance that moved under the
            // shop — a reward, a life refill — so the message is about coins, not about the code.
            RtlText.Set(_hint, "سکه کافی نیست");
            _hint.color = Tokens.Warning;
            _hintUntil = Time.unscaledTime + 1.8f;
            Refresh();
        }

        public override void Refresh()
        {
            if (Session == null) return;

            long coins = Session.Wallet.Coins;
            for (int i = 0; i < _rows.Length; i++)
            {
                var row = _rows[i];
                if (row == null || row.Buy == null) continue;

                int price = BoosterCatalog.Price(row.Kind);
                int owned = Session.Boosters.Count(row.Kind);
                bool full = owned >= BoosterCatalog.MaxOwned;
                bool affordable = coins >= price;

                RtlText.Set(row.Price, Core.Text.PersianText.Number(price) + " سکه");
                RtlText.Set(row.Owned, full ? "پُر" : "دارید " + Core.Text.PersianText.Number(owned));

                row.Price.color = affordable || full ? Tokens.Gold : Tokens.TextMuted;
                row.Owned.color = full ? Tokens.Success : Tokens.TextMuted;

                row.Buy.interactable = affordable && !full;
                RtlText.Set(row.BuyLabel, full ? "پُر" : "خرید");
            }
        }

        void Update()
        {
            if (_hintUntil > 0f && Time.unscaledTime >= _hintUntil)
            {
                _hintUntil = 0f;
                RtlText.Set(_hint, "");
            }
        }
    }
}
