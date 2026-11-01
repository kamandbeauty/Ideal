using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.TextCore.LowLevel;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// Where the font comes from. Vazir ships with the game (SIL OFL, see Assets/Fonts/OFL.txt), so
    /// Persian works on a fresh clone with no setup step:
    ///
    ///   1. a prebuilt TMP asset at Resources/fonts/shazdeh-ui(-bold) wins, if an artist/designer made
    ///      one with **کاخ شازده → Build UI font** (smaller memory, faster first frame);
    ///   2. otherwise the TTF in Resources is turned into a dynamic SDF font asset on first use. Glyphs
    ///      rasterise on demand, which is what a game wants anyway: a word that only appears in one
    ///      level title still renders.
    ///
    /// The dynamic path is the default one, because a font asset is a binary that only Unity can make
    /// and CI must never depend on somebody having opened the editor.
    ///
    /// Two weights, matching the token scale: Medium (500) for body and buttons, Bold (700) for
    /// titles. The type scale asks for 800/900 in two places; Vazir's Bold is the closest weight that
    /// does not ship a third 100 KB file for one line of text.
    /// </summary>
    public static class ShazdehFonts
    {
        public const string UiAssetPath = "fonts/shazdeh-ui";
        public const string BoldAssetPath = "fonts/shazdeh-ui-bold";
        public const string UiSourcePath = "fonts/Vazir-Medium";
        public const string BoldSourcePath = "fonts/Vazir-Bold";

        const int SamplingPointSize = 72;
        const int AtlasPadding = 9;
        const int AtlasSize = 1024;

        static TMP_FontAsset _ui;
        static TMP_FontAsset _bold;
        static readonly List<string> Warnings = new List<string>();

        /// <summary>Body font. Never null in practice; falls back to TMP's default as a last resort.</summary>
        public static TMP_FontAsset Ui => _ui != null ? _ui : _ui = Load(UiAssetPath, UiSourcePath, "UI");

        /// <summary>Title font.</summary>
        public static TMP_FontAsset Bold => _bold != null ? _bold : _bold = Load(BoldAssetPath, BoldSourcePath, "bold");

        /// <summary>True when the shippable Vazir files are where they should be.</summary>
        public static bool IsPersianFontInstalled =>
            Resources.Load<TMP_FontAsset>(UiAssetPath) != null || Resources.Load<Font>(UiSourcePath) != null;

        static TMP_FontAsset Load(string assetPath, string sourcePath, string label)
        {
            var prebuilt = Resources.Load<TMP_FontAsset>(assetPath);
            if (prebuilt != null) return prebuilt;

            var source = Resources.Load<Font>(sourcePath);
            if (source != null)
            {
                var dynamicAsset = CreateFrom(source, label);
                if (dynamicAsset != null) return dynamicAsset;
            }

            Warn("[" + label + "] " + sourcePath + " not found in Resources; falling back to the TMP default. " +
                 "Persian will not render correctly. See docs/ui.md.");
            return TryDefaultFont();
        }

        static TMP_FontAsset CreateFrom(Font source, string label)
        {
            try
            {
                var asset = TMP_FontAsset.CreateFontAsset(
                    source, SamplingPointSize, AtlasPadding, GlyphRenderMode.SDFAA,
                    AtlasSize, AtlasSize, AtlasPopulationMode.Dynamic, true);

                if (asset == null)
                {
                    Warn("[" + label + "] TMP could not build a font asset from " + source.name);
                    return null;
                }

                asset.name = "shazdeh-ui-" + label + " (runtime)";
                return asset;
            }
            catch (System.Exception error)
            {
                Warn("[" + label + "] font asset creation failed: " + error.Message);
                return null;
            }
        }

        static TMP_FontAsset TryDefaultFont()
        {
            try
            {
                return TMP_Settings.defaultFontAsset;
            }
            catch
            {
                return null; // TMP essentials were never imported
            }
        }

        static void Warn(string message)
        {
            if (Warnings.Contains(message)) return;
            Warnings.Add(message);
            Debug.LogWarning(message);
        }

        /// <summary>Every warning raised so far — a boot log or a test can assert there were none.</summary>
        public static IReadOnlyList<string> RaisedWarnings => Warnings;

        /// <summary>For the editor tools and tests: forget the cached lookup.</summary>
        public static void ResetCache()
        {
            _ui = null;
            _bold = null;
            Warnings.Clear();
        }
    }
}
