using TMPro;
using UnityEngine;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// The always-on strip: coins, potions, lives. It exists on every screen because the whole game is
    /// the loop between those three numbers, and a player should never have to open a menu to see them.
    ///
    /// RTL placement: lives are the number you spend by playing, so they sit at the right end where a
    /// Persian reader's eye starts; the two currencies sit at the other end.
    /// </summary>
    public sealed class TopBar : MonoBehaviour
    {
        const float Height = 48f;
        const float Pad = 20f;

        TextMeshProUGUI _coins;
        TextMeshProUGUI _potions;
        TextMeshProUGUI _lives;
        TextMeshProUGUI _timer;
        GameSession _session;

        public static TopBar Create(Transform parent, GameSession session)
        {
            var go = new GameObject("TopBar", typeof(RectTransform));
            go.transform.SetParent(parent, false);

            var bar = go.AddComponent<TopBar>();
            bar.Build(session);
            return bar;
        }

        void Build(GameSession session)
        {
            _session = session;

            var root = (RectTransform)transform;
            root.anchorMin = new Vector2(0f, 1f);
            root.anchorMax = new Vector2(1f, 1f);
            root.pivot = new Vector2(0.5f, 1f);
            root.anchoredPosition = new Vector2(0f, -Tokens.Hud.SafeTop);
            root.sizeDelta = new Vector2(0f, Height);

            float width = UiKit.CanvasWidth;
            float pillWidth = 118f;
            float pillHeight = Height;

            // coins — left end
            var coinsPill = UiKit.Panel(root, "coins", Pad, 0f, pillWidth, pillHeight, Tokens.SurfaceRaised, (int)Tokens.Radius.Md);
            _coins = UiKit.Label(coinsPill, "value", "", Tokens.Hud.Currency, Tokens.Gold, TextAlignmentOptions.Center);
            UiKit.Stretch(_coins.rectTransform, Tokens.Space.S3, 0f);

            // potions — next to the coins
            float potionsX = Pad + pillWidth + Tokens.Space.S2;
            var potionsPill = UiKit.Panel(root, "potions", potionsX, 0f, pillWidth, pillHeight, Tokens.SurfaceRaised, (int)Tokens.Radius.Md);
            _potions = UiKit.Label(potionsPill, "value", "", Tokens.Hud.Currency, Tokens.Accent, TextAlignmentOptions.Center);
            UiKit.Stretch(_potions.rectTransform, Tokens.Space.S3, 0f);

            // lives — right end
            float livesX = width - Pad - pillWidth;
            var livesPill = UiKit.Panel(root, "lives", livesX, 0f, pillWidth, pillHeight, Tokens.SurfaceRaised, (int)Tokens.Radius.Md);
            _lives = UiKit.Label(livesPill, "value", "", Tokens.Hud.Currency, Tokens.Text, TextAlignmentOptions.Center);
            UiKit.Place(_lives.rectTransform, 0f, Tokens.Space.S1, pillWidth, 20f);

            _timer = UiKit.Label(livesPill, "timer", "", Tokens.Type.Xs, Tokens.TextMuted, TextAlignmentOptions.Center);
            UiKit.Place(_timer.rectTransform, 0f, Height - 20f, pillWidth, 16f);

            Refresh();
        }

        public void Refresh()
        {
            if (_session == null) return;

            RtlText.Set(_coins, Core.Text.PersianText.Number(_session.Wallet.Coins) + " " + CoinWord);
            RtlText.Set(_potions, Core.Text.PersianText.Number(_session.Wallet.Potions) + " " + PotionWord);

            var lives = _session.Lives;
            RtlText.Set(_lives, Core.Text.PersianText.Number(lives.Current) + " " + LifeWord);

            if (lives.IsFull) RtlText.Set(_timer, FullWord);
            else RtlText.SetTime(_timer, lives.NextRefillInSeconds);
        }

        // Words, kept in one place so a copy change is a one-line change.
        const string CoinWord = "سکه";
        const string PotionWord = "معجون";
        const string LifeWord = "جان";
        const string FullWord = "پر";
    }
}
