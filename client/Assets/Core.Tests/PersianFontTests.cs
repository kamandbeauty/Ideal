using System.Collections.Generic;
using System.Text;
using NUnit.Framework;
using Shazdeh.Game.Ui;
using UnityEngine;

namespace Shazdeh.Core.Tests
{
    /// <summary>
    /// The seam between the shaper and the font: the shaper emits presentation-form code points, so the
    /// shipped typeface must contain them. These run under Unity (CI runs them with the game), because
    /// only Unity can import a TTF and build a TMP atlas — the pure-C# checks live in
    /// tools/text/check_font.py and run on every push.
    /// </summary>
    public sealed class PersianFontTests
    {
        [SetUp]
        public void SetUp()
        {
            ShazdehFonts.ResetCache();
        }

        [Test]
        public void TheShippedFontLoadsWithoutWarnings()
        {
            var font = ShazdehFonts.Ui;

            Assert.IsNotNull(font, "no UI font: Vazir should be in Assets/Game/Resources/fonts");
            Assert.AreEqual(0, ShazdehFonts.RaisedWarnings.Count,
                ShazdehFonts.RaisedWarnings.Count > 0 ? ShazdehFonts.RaisedWarnings[0] : "");
            Assert.IsTrue(ShazdehFonts.IsPersianFontInstalled, "the font resource should be findable by path");
        }

        [Test]
        public void TheBoldWeightLoadsToo()
        {
            Assert.IsNotNull(ShazdehFonts.Bold, "titles use Vazir Bold; it ships next to the body weight");
        }

        [Test]
        public void EveryShippedStringHasEveryGlyph()
        {
            var font = ShazdehFonts.Ui;
            Assert.IsNotNull(font);

            var failures = new StringBuilder();
            var missing = new List<char>();

            for (int i = 0; i < PersianGoldenVectors.Strings.Length; i++)
            {
                string visual = PersianGoldenVectors.Strings[i].Visual;
                missing.Clear();
                bool complete = font.HasCharacters(visual, out missing, false, true);
                if (complete) continue;

                failures.Append('\n').Append('"').Append(PersianGoldenVectors.Strings[i].Logical).Append("\" is missing ");
                for (int m = 0; m < missing.Count; m++) failures.Append("U+").Append(((int)missing[m]).ToString("X4")).Append(' ');
            }

            Assert.AreEqual(0, failures.Length, "the font cannot draw what the shaper emits:" + failures);
        }

        [Test]
        public void PersianDigitsRender()
        {
            var font = ShazdehFonts.Ui;
            Assert.IsNotNull(font);

            var digits = new List<char> { '\u06F0', '\u06F1', '\u06F2', '\u06F3', '\u06F4', '\u06F5', '\u06F6', '\u06F7', '\u06F8', '\u06F9', '\u066C' };
            for (int i = 0; i < digits.Count; i++)
                Assert.IsTrue(font.HasCharacter(digits[i]) || font.HasCharacters(digits[i].ToString(), out _, false, true),
                    "missing Persian numeral U+" + ((int)digits[i]).ToString("X4"));
        }

        [Test]
        public void AShapedSentenceIsStillReadableAsText()
        {
            // A guard against a shaper change that drops characters: the drawn string must have the
            // same number of visible characters as the logical one once zero-width joiners are gone.
            string logical = "برای ساخت ناحیه، معجون خرج کن";
            string visual = Core.Text.PersianText.ForDisplay(logical);

            Assert.AreEqual(logical.Replace("\u200C", "").Length, visual.Length,
                "shaping must replace characters, not lose them");
        }
    }
}
