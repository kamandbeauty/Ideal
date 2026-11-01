using System.IO;
using TMPro;
using UnityEditor;
using UnityEngine;
using UnityEngine.TextCore.LowLevel;

namespace Shazdeh.EditorTools
{
    /// <summary>
    /// Optional optimisation: bake the two dynamic font assets into .asset files.
    ///
    /// The game does not need this — <see cref="Shazdeh.Game.Ui.ShazdehFonts"/> builds a dynamic asset
    /// from the shipped Vazir TTF on first use, which is why a fresh clone renders Persian with no
    /// setup. Baking helps on low-end devices: the atlas and material are loaded with the game instead
    /// of being constructed at boot, and the SDF render mode is pinned at build time rather than
    /// depending on runtime defaults.
    ///
    /// The source TTFs stay in Resources either way: they are the licence-bearing files and the
    /// fallback path.
    /// </summary>
    public static class TmpFontSetup
    {
        const string OutputFolder = "Assets/Game/Resources/fonts";

        [MenuItem("کاخ شازده/Build UI font assets (optional)")]
        public static void BuildAll()
        {
            bool ok = Bake("Vazir-Medium", "shazdeh-ui");
            ok &= Bake("Vazir-Bold", "shazdeh-ui-bold");

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Shazdeh.Game.Ui.ShazdehFonts.ResetCache();

            if (ok) Debug.Log("UI font assets baked into " + OutputFolder + ". The runtime path is no longer used.");
            else Debug.LogError("Font baking failed. The game still works: it builds both assets at runtime from the TTF.");
        }

        static bool Bake(string ttfName, string assetName)
        {
            string sourcePath = OutputFolder + "/" + ttfName + ".ttf";
            string assetPath = OutputFolder + "/" + assetName + ".asset";

            var source = AssetDatabase.LoadAssetAtPath<Font>(sourcePath);
            if (source == null)
            {
                Debug.LogError("Missing font source " + sourcePath + ". The Vazir TTFs ship with the repo; " +
                               "check that they were not removed (see Assets/Fonts/README.md).");
                return false;
            }

            var asset = TMP_FontAsset.CreateFontAsset(
                source,
                72,                                     // sampling point size
                9,                                      // atlas padding, in pixels
                GlyphRenderMode.SDFAA,
                1024,
                1024,
                AtlasPopulationMode.Dynamic,
                true);

            if (asset == null)
            {
                Debug.LogError("TMP refused to build " + assetName + " from " + sourcePath);
                return false;
            }

            asset.name = assetName;

            if (File.Exists(assetPath)) AssetDatabase.DeleteAsset(assetPath);
            AssetDatabase.CreateAsset(asset, assetPath);

            // The atlas texture and material must be saved as sub-assets, or they vanish on the next
            // domain reload and every label turns into empty boxes.
            if (asset.material != null) AssetDatabase.AddObjectToAsset(asset.material, asset);
            if (asset.atlasTextures != null)
            {
                for (int i = 0; i < asset.atlasTextures.Length; i++)
                {
                    var texture = asset.atlasTextures[i];
                    if (texture == null) continue;
                    texture.name = assetName + " atlas " + i;
                    AssetDatabase.AddObjectToAsset(texture, asset);
                }
            }

            EditorUtility.SetDirty(asset);
            Debug.Log("Baked " + assetPath + " from " + sourcePath);
            return true;
        }
    }
}
