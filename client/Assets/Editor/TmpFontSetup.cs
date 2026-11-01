using System.IO;
using TMPro;
using UnityEditor;
using UnityEngine;
using UnityEngine.TextCore.LowLevel;

namespace Shazdeh.EditorTools
{
    /// <summary>
    /// Builds the one font asset the game uses, from whatever Persian font the developer put in
    /// Assets/Fonts/. The repository ships no font binary on purpose (a Persian font is a licensed
    /// asset, and the design was drawn against Vazirmatn which is SIL OFL — see docs/ui.md).
    ///
    /// The atlas is dynamic: glyphs are rasterised on demand at runtime, which keeps the download small
    /// and means a character that only appears in a level title still renders.
    /// </summary>
    public static class TmpFontSetup
    {
        const string FontsFolder = "Assets/Fonts";
        const string OutputFolder = "Assets/Game/Resources/fonts";
        const string OutputPath = OutputFolder + "/shazdeh-ui.asset";

        const int SamplingPointSize = 72;
        const int AtlasPadding = 9;
        const int AtlasSize = 1024;

        [MenuItem("کاخ شازده/Build UI font")]
        public static void Build()
        {
            string fontPath = FindFontPath();
            if (fontPath == null)
            {
                Debug.LogError(
                    "No font found in " + FontsFolder + ". Put a Persian TTF/OTF there first " +
                    "(Vazirmatn is SIL OFL and matches the design), then run this again. See docs/ui.md.");
                return;
            }

            var font = AssetDatabase.LoadAssetAtPath<Font>(fontPath);
            if (font == null)
            {
                Debug.LogError("Could not load a Unity Font from " + fontPath + ".");
                return;
            }

            var asset = TMP_FontAsset.CreateFontAsset(
                font,
                SamplingPointSize,
                AtlasPadding,
                GlyphRenderMode.SDFAA,
                AtlasSize,
                AtlasSize,
                AtlasPopulationMode.Dynamic,
                true);

            if (asset == null)
            {
                Debug.LogError("TMP refused to build a font asset from " + fontPath + ".");
                return;
            }

            asset.name = "shazdeh-ui";

            Directory.CreateDirectory(OutputFolder);

            // The atlas texture and material must be saved as sub-assets of the font asset, or they are
            // dropped on the next domain reload and every label turns into empty boxes.
            AssetDatabase.CreateAsset(asset, OutputPath);
            if (asset.material != null) AssetDatabase.AddObjectToAsset(asset.material, asset);
            if (asset.atlasTextures != null)
            {
                for (int i = 0; i < asset.atlasTextures.Length; i++)
                {
                    var texture = asset.atlasTextures[i];
                    if (texture == null) continue;
                    texture.name = "shazdeh-ui atlas " + i;
                    AssetDatabase.AddObjectToAsset(texture, asset);
                }
            }

            EditorUtility.SetDirty(asset);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            Shazdeh.Game.Ui.ShazdehFonts.ResetCache();
            Debug.Log("UI font built: " + OutputPath + " from " + fontPath +
                      ". Open Assets/Scenes/_DesignSystem.unity to check the Persian glyphs.");
        }

        static string FindFontPath()
        {
            if (!Directory.Exists(FontsFolder)) return null;

            var guids = AssetDatabase.FindAssets("t:Font", new[] { FontsFolder });
            for (int i = 0; i < guids.Length; i++)
            {
                string path = AssetDatabase.GUIDToAssetPath(guids[i]);
                if (path.EndsWith(".ttf") || path.EndsWith(".otf")) return path;
            }
            return null;
        }
    }
}
