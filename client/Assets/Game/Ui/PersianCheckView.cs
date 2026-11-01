using Shazdeh.Core.Text;
using TMPro;
using UnityEngine;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// The "does Persian actually render" scene. It draws the strings the game ships, through the real
    /// path (PersianText → RtlText → TMP → the UI font), so that a font problem, a shaper problem and a
    /// layout problem each look different instead of all looking like "it is broken".
    ///
    /// Open it from Assets/Scenes/_PersianCheck.unity (menu: کاخ شازده → Create scenes) and read the
    /// lines. If letters are joined and the line runs right to left, the shaper and the font agree.
    /// </summary>
    public sealed class PersianCheckView : MonoBehaviour
    {
        void Start()
        {
            var canvas = UiKit.CreateCanvas("PersianCheckCanvas");

            var root = canvas.transform;
            UiKit.Background(root, Tokens.Bg);

            float width = UiKit.CanvasWidth;

            var asciiNote = UiKit.Label(root, "ascii_note",
                "Persian specimen - read the Persian, ignore this line",
                Tokens.Type.Xs, Tokens.TextMuted, TextAlignmentOptions.Center);
            UiKit.Place(asciiNote.rectTransform, 16f, 14f, width - 32f, 20f);

            float y = 48f;

            if (!ShazdehFonts.IsPersianFontInstalled)
            {
                var warning = UiKit.LabelRight(root, "no_font",
                    "فونت فارسی نصب نشده است — کاخ شازده ← Build UI font",
                    Tokens.Type.Sm, Tokens.Danger);
                UiKit.Place(warning.rectTransform, 16f, y, width - 32f, 22f);
                y += 34f;
            }

            y = Line(root, y, "کاخِ شازده", Tokens.Type.Display, Tokens.Gold, "display 34 · gold");
            y = Line(root, y, "فصل یک — میدانِ فیروزه", Tokens.Type.Xl, Tokens.Text, "xl 26 · text");
            y = Line(root, y, "برای ساخت ناحیه، معجون خرج کن", Tokens.Type.Base, Tokens.Text, "base 16");
            y = Line(root, y, "۱۳ از ۱۰ مرحله", Tokens.Type.Sm, Tokens.TextMuted, "sm 14 · muted");
            y = Line(root, y, "جان بعدی تا ۲۹:۵۹", Tokens.Type.Sm, Tokens.Warning, "countdown");
            y = Line(root, y, "۱٬۲۳۴٬۵۶۷ سکه", Tokens.Type.Base, Tokens.Gold, "grouped number");
            y = Line(root, y, "۰۱۲۳۴۵۶۷۸۹", Tokens.Type.Base, Tokens.Text, "digits");
            y = Line(root, y, "«صندوق ناحیه» باز شد!", Tokens.Type.Base, Tokens.Success, "guillemets + !");
            y = Line(root, y, "می‌روم، می‌آیم، نمی‌دانم", Tokens.Type.Base, Tokens.Text, "zero-width non-joiner");
            y = Line(root, y, "متن انگلیسی Royal Match در جمله", Tokens.Type.Base, Tokens.Text, "mixed direction");
            y = Line(root, y, "شازده (کاخ) — نسخهٔ ۱٫۰", Tokens.Type.Base, Tokens.Text, "mirrored brackets");

            var button = UiKit.Button(root, "button", "شروع", 16f, y + 8f, width - 32f, Tokens.Hud.TouchTarget,
                Tokens.Accent, Tokens.OnAccent, null, (int)Tokens.Radius.Md);
            UiKit.Place((RectTransform)button.transform, 16f, y + 8f, width - 32f, Tokens.Hud.TouchTarget);
            y += Tokens.Hud.TouchTarget + 24f;

            var disabled = UiKit.Button(root, "disabled", "مرحله هنوز باز نشده است", 16f, y, width - 32f,
                Tokens.Hud.TouchTarget, Tokens.SurfaceRaised, Tokens.TextMuted, null, (int)Tokens.Radius.Md);
            disabled.interactable = false;
            UiKit.Place((RectTransform)disabled.transform, 16f, y, width - 32f, Tokens.Hud.TouchTarget);
        }

        static float Line(Transform root, float y, string text, float size, Color color, string note)
        {
            var label = UiKit.LabelRight(root, "line_" + Mathf.RoundToInt(y), text, size, color);
            UiKit.Place(label.rectTransform, 16f, y, UiKit.CanvasWidth - 32f, size * 1.5f);
            y += size * 1.5f + 6f;

            var caption = UiKit.LabelLeft(root, "note_" + Mathf.RoundToInt(y), note, Tokens.Type.Xs, Tokens.TextMuted);
            UiKit.Place(caption.rectTransform, 16f, y - 2f, UiKit.CanvasWidth - 32f, 14f);
            y += 18f;

            return y;
        }

        /// <summary>Lets a test or a build script read the same strings this scene shows.</summary>
        public static string[] Samples()
        {
            return new[]
            {
                "کاخِ شازده",
                "۱۳ از ۱۰ مرحله",
                "جان بعدی تا ۲۹:۵۹",
                "۱٬۲۳۴٬۵۶۷ سکه",
                "متن انگلیسی Royal Match در جمله",
                "شازده (کاخ) — نسخهٔ ۱٫۰"
            };
        }

        /// <summary>Every sample, shaped — used by the console check below.</summary>
        public static string Describe()
        {
            var sb = new System.Text.StringBuilder(256);
            var samples = Samples();
            for (int i = 0; i < samples.Length; i++)
                sb.AppendLine(samples[i] + "  →  " + PersianText.ForDisplay(samples[i]));
            return sb.ToString();
        }
    }
}
