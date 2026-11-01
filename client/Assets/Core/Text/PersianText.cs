using System;
using System.Collections.Generic;
using System.Text;

namespace Shazdeh.Core.Text
{
    /// <summary>
    /// Persian text, made ready for a renderer that only knows how to draw code points left to right.
    ///
    /// TextMeshPro does no shaping and no bidi, so a Persian string drawn as-is comes out as isolated
    /// letters in reverse reading order. Two steps fix that, and both are pure C# so they can be unit
    /// tested without Unity:
    ///
    ///   Shape()        logical letters  →  the presentation forms their neighbours imply
    ///                     "کاخ" → U+06A9 → U+06A9 initial, ... USING the Unicode forms table
    ///   ToVisualOrder() logical order   →  the order a left-to-right renderer must draw
    ///                     reverses RTL runs, leaves Latin words and numbers alone, mirrors brackets
    ///
    /// Nothing here is fa-specific magic: it is the subset of the Unicode Arabic joining algorithm and
    /// the bidi algorithm that a Persian UI needs. It does not try to be a general bidi engine — there
    /// is no embedded Hebrew, no numbers-in-brackets-in-numbers — and the tests say exactly what is
    /// covered so nobody has to guess.
    /// </summary>
    public static class PersianText
    {
        // ---- public API ---------------------------------------------------------------------------

        /// <summary>Shapes and reorders. This is what a UI calls before handing a string to TMP.</summary>
        public static string ForDisplay(string logical) => ToVisualOrder(Shape(logical));

        /// <summary>
        /// Replaces each letter with the form its neighbours imply. Order is unchanged; zero-width
        /// non-joiners are consumed (they did their job by breaking a connection).
        /// </summary>
        public static string Shape(string logical)
        {
            if (string.IsNullOrEmpty(logical)) return logical ?? string.Empty;

            int n = logical.Length;
            var output = new StringBuilder(n + 4);

            for (int i = 0; i < n; i++)
            {
                char c = logical[i];

                if (c == PersianForms.Zwnj) continue; // a joining break, not a glyph

                if (!PersianForms.IsLetter(c) && c != PersianForms.Tatweel)
                {
                    output.Append(c);
                    continue;
                }

                if (c == PersianForms.Tatweel)
                {
                    output.Append(c); // a connector with no forms of its own
                    continue;
                }

                bool joinsPrevious = JoinsPrevious(logical, i);
                bool joinsNext = JoinsNext(logical, i);

                // LAM + ALEF: one glyph, and the alef is consumed by it.
                if (c == Lam && joinsNext && NextLetter(logical, i) == Alef)
                {
                    output.Append(joinsPrevious ? PersianForms.LamAlefFinal : PersianForms.LamAlefIsolated);
                    i = SkipTransparent(logical, i + 2) - 1; // skip the alef; the loop increments
                    continue;
                }

                output.Append(PersianForms.Form(c, joinsPrevious, joinsNext));
            }

            return output.ToString();
        }

        /// <summary>
        /// Reorders shaped text for a left-to-right renderer: RTL runs are reversed, Latin words and
        /// numbers keep their own order, and brackets inside RTL text are mirrored.
        /// </summary>
        public static string ToVisualOrder(string shaped)
        {
            if (string.IsNullOrEmpty(shaped)) return shaped ?? string.Empty;

            var clusters = Cluster(shaped);
            if (clusters.Count == 0) return string.Empty;

            // Group clusters into runs of the same direction. A neutral (space, comma, dash) belongs to
            // the run it sits in, so it is held back until the next letter decides which run that is.
            var runs = new List<Run>(4);
            var pending = new List<Cluster>(2);
            Run current = null;

            for (int i = 0; i < clusters.Count; i++)
            {
                var cluster = clusters[i];
                Direction direction = Classify(cluster.Text[0]);

                if (direction == Direction.Neutral)
                {
                    pending.Add(cluster);
                    continue;
                }

                if (current == null || current.Direction != direction)
                {
                    current = new Run(direction);
                    runs.Add(current);
                }

                current.Clusters.AddRange(pending);
                pending.Clear();
                current.Clusters.Add(cluster);
            }

            if (pending.Count > 0)
            {
                if (current == null)
                {
                    current = new Run(Direction.Neutral);
                    runs.Add(current);
                }
                current.Clusters.AddRange(pending);
            }

            var output = new StringBuilder(shaped.Length + 4);
            for (int r = runs.Count - 1; r >= 0; r--) // the line is laid out right to left
            {
                var run = runs[r];
                bool rtl = run.Direction == Direction.Rtl;
                if (rtl)
                {
                    for (int c = run.Clusters.Count - 1; c >= 0; c--) AppendMirrored(output, run.Clusters[c].Text);
                }
                else
                {
                    for (int c = 0; c < run.Clusters.Count; c++) output.Append(run.Clusters[c].Text);
                }
            }

            return output.ToString();
        }

        // ---- digits -------------------------------------------------------------------------------

        const char PersianZero = '\u06F0';
        const char PersianNine = '\u06F9';
        const char ThousandsSeparator = '\u066C'; // ٬
        const char DecimalSeparator = '\u066B';   // ٫

        public static bool IsPersianDigit(char c) => c >= PersianZero && c <= PersianNine;

        /// <summary>ASCII digits → Persian digits, leaving everything else alone.</summary>
        public static string ToPersianDigits(string text)
        {
            if (string.IsNullOrEmpty(text)) return text ?? string.Empty;

            var sb = new StringBuilder(text.Length);
            for (int i = 0; i < text.Length; i++)
            {
                char c = text[i];
                sb.Append(c >= '0' && c <= '9' ? (char)(PersianZero + (c - '0')) : c);
            }
            return sb.ToString();
        }

        /// <summary>Persian digits → ASCII digits, for parsing.</summary>
        public static string ToLatinDigits(string text)
        {
            if (string.IsNullOrEmpty(text)) return text ?? string.Empty;

            var sb = new StringBuilder(text.Length);
            for (int i = 0; i < text.Length; i++)
            {
                char c = text[i];
                sb.Append(IsPersianDigit(c) ? (char)('0' + (c - PersianZero)) : c);
            }
            return sb.ToString();
        }

        /// <summary>A whole number as the player reads it: ۱۲٬۳۴۵ — Persian digits, Persian separator.</summary>
        public static string Number(long value)
        {
            bool negative = value < 0;
            ulong magnitude = negative ? (ulong)(-(value + 1)) + 1UL : (ulong)value;

            var digits = magnitude.ToString();
            var sb = new StringBuilder(digits.Length + digits.Length / 3 + 1);
            if (negative) sb.Append('\u2212'); // minus sign, not a hyphen

            int lead = digits.Length % 3;
            if (lead == 0) lead = 3;
            sb.Append(ToPersianDigits(digits.Substring(0, lead)));
            for (int i = lead; i < digits.Length; i += 3)
            {
                sb.Append(ThousandsSeparator);
                sb.Append(ToPersianDigits(digits.Substring(i, 3)));
            }
            return sb.ToString();
        }

        public static string Number(int value) => Number((long)value);

        /// <summary>A countdown as the HUD shows it: ۲۹:۵۹, or ۰۱:۳۰:۰۰ past an hour.</summary>
        public static string Time(int seconds)
        {
            if (seconds < 0) seconds = 0;
            int hours = seconds / 3600;
            int minutes = seconds % 3600 / 60;
            int secs = seconds % 60;

            string text = hours > 0
                ? hours.ToString("00") + ":" + minutes.ToString("00") + ":" + secs.ToString("00")
                : minutes.ToString("00") + ":" + secs.ToString("00");
            return ToPersianDigits(text);
        }

        /// <summary>Keeps a decimal price readable: ۴٫۵</summary>
        public static string Decimal(long whole, int tenths) => Number(whole) + DecimalSeparator + ToPersianDigits(tenths.ToString());

        // ---- the joining algorithm ----------------------------------------------------------------

        const char Lam = '\u0644';
        const char Alef = '\u0627';

        static bool IsBreak(char c) => c == PersianForms.Zwnj;

        /// <summary>Index of the next character that is not a mark riding on the previous one.</summary>
        static int SkipTransparent(string text, int index)
        {
            while (index < text.Length && PersianForms.IsTransparent(text[index])) index++;
            return index;
        }

        /// <summary>The next letter, looking past marks and joiners. '\0' when there is none.</summary>
        static char NextLetter(string text, int index)
        {
            for (int i = SkipTransparent(text, index + 1); i < text.Length; i++)
            {
                char c = text[i];
                if (IsBreak(c)) return '\0';
                if (PersianForms.IsTransparent(c)) continue;
                if (PersianForms.IsLetter(c) || c == PersianForms.Tatweel) return c;
                return '\0'; // a space or a digit ends the word
            }
            return '\0';
        }

        /// <summary>True when the letter before joins forward to this one.</summary>
        static bool JoinsPrevious(string text, int index)
        {
            for (int i = index - 1; i >= 0; i--)
            {
                char c = text[i];
                if (PersianForms.IsTransparent(c)) continue;
                if (IsBreak(c)) return false;
                if (c == PersianForms.Tatweel) return true;

                if (!PersianForms.IsLetter(c)) return false;
                PersianForms.TryGetJoinType(c, out JoinType previous);

                // The current letter must also accept a connection from the right.
                PersianForms.TryGetJoinType(text[index], out JoinType current);
                return previous == JoinType.Dual && current != JoinType.None;
            }
            return false;
        }

        /// <summary>True when this letter joins forward to the letter after it.</summary>
        static bool JoinsNext(string text, int index)
        {
            PersianForms.TryGetJoinType(text[index], out JoinType current);
            if (current != JoinType.Dual) return false;

            char next = NextLetter(text, index);
            if (next == '\0') return false;
            if (next == PersianForms.Tatweel) return true;

            PersianForms.TryGetJoinType(next, out JoinType following);
            return following != JoinType.None;
        }

        // ---- runs and clusters --------------------------------------------------------------------

        enum Direction : byte
        {
            Neutral = 0,
            Rtl = 1,
            Ltr = 2
        }

        struct Cluster
        {
            public string Text;
        }

        sealed class Run
        {
            public readonly Direction Direction;
            public readonly List<Cluster> Clusters = new List<Cluster>();

            public Run(Direction direction)
            {
                Direction = direction;
            }
        }

        static bool IsRtlChar(char c) =>
            (c >= '\u0590' && c <= '\u05FF') ||       // Hebrew, for completeness
            (c >= '\u0600' && c <= '\u06FF') ||       // Arabic / Persian
            (c >= '\u0750' && c <= '\u077F') ||
            (c >= '\uFB50' && c <= '\uFDFF') ||       // presentation forms
            (c >= '\uFE70' && c <= '\uFEFF') ||
            c == '\u200F';

        static bool IsLtrChar(char c) =>
            (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || IsPersianDigit(c) ||
            c == ThousandsSeparator || c == DecimalSeparator;

        static Direction Classify(char c)
        {
            if (IsRtlChar(c)) return Direction.Rtl;
            if (IsLtrChar(c)) return Direction.Ltr;
            return Direction.Neutral;
        }

        /// <summary>A letter plus the marks that ride on it: they must never be separated by a reversal.</summary>
        static List<Cluster> Cluster(string shaped)
        {
            var clusters = new List<Cluster>(shaped.Length);
            for (int i = 0; i < shaped.Length; i++)
            {
                char c = shaped[i];
                int start = i;
                while (i + 1 < shaped.Length && PersianForms.IsTransparent(shaped[i + 1])) i++;
                clusters.Add(new Cluster { Text = shaped.Substring(start, i - start + 1) });
            }
            return clusters;
        }

        static void AppendMirrored(StringBuilder output, string cluster)
        {
            for (int i = 0; i < cluster.Length; i++)
            {
                switch (cluster[i])
                {
                    case '(': output.Append(')'); break;
                    case ')': output.Append('('); break;
                    case '[': output.Append(']'); break;
                    case ']': output.Append('['); break;
                    case '{': output.Append('}'); break;
                    case '}': output.Append('{'); break;
                    case '<': output.Append('>'); break;
                    case '>': output.Append('<'); break;
                    case '\u00AB': output.Append('\u00BB'); break; // «
                    case '\u00BB': output.Append('\u00AB'); break; // »
                    default: output.Append(cluster[i]); break;
                }
            }
        }
    }
}
