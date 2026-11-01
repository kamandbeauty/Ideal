using Shazdeh.Core.Text;
using TMPro;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// The only way text reaches a label.
    ///
    /// A screen never assigns TMP_Text.text itself: it calls one of these, which shapes and reorders
    /// Persian first (Shazdeh.Core.Text.PersianText) and formats numbers as Persian numerals. That
    /// keeps two promises: Persian is always readable, and no screen decides for itself whether
    /// "1234" should look like "۱۲٬۳۴۵".
    ///
    /// The strings a screen passes in are the logical strings an author writes — «مرحله ۳», not the
    /// presentation-form soup the renderer needs.
    /// </summary>
    public static class RtlText
    {
        public static void Set(TMP_Text label, string logical)
        {
            if (label == null) return;
            label.text = PersianText.ForDisplay(logical ?? string.Empty);
        }

        /// <summary>Sets a string that already passed through the shaper (for cached labels).</summary>
        public static void SetVisual(TMP_Text label, string visual)
        {
            if (label == null) return;
            label.text = visual ?? string.Empty;
        }

        public static void SetNumber(TMP_Text label, long value) => Set(label, PersianText.Number(value));

        public static void SetTime(TMP_Text label, int seconds) => Set(label, PersianText.Time(seconds));

        /// <summary>«۳ از ۵» — the shape of every counter in the HUD.</summary>
        public static void SetFraction(TMP_Text label, long current, long total)
        {
            Set(label, PersianText.Number(current) + " " + FromWord + " " + PersianText.Number(total));
        }

        /// <summary>«جان» is the word between the two numbers of a fraction. Kept here, not in the screen.</summary>
        const string FromWord = "از";
    }
}
