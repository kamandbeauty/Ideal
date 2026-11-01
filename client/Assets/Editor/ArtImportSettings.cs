using UnityEditor;
using UnityEngine;
using Shazdeh.Game;

namespace Shazdeh.EditorTools
{
    /// <summary>
    /// Import rules for anything dropped in Assets/Game/Resources/art/.
    ///
    /// This exists because "the artist exported a PNG" is exactly the moment a project starts to rot:
    /// one file arrives as a Texture instead of a Sprite, ships uncompressed at 4096 px, and nobody
    /// notices until the build is 90 MB and blurry. The importer enforces the contract in
    /// art/manifest.json automatically, so a correct file needs no manual step and a wrong one is fixed
    /// on the way in.
    ///
    /// The manifest's per-asset sizes are enforced by `tools/art/art.py --check` (CI), because an
    /// importer cannot read a JSON file from inside OnPreprocessTexture without becoming fragile.
    /// </summary>
    public sealed class ArtImportSettings : AssetPostprocessor
    {
        const string ArtFolder = "Assets/Game/Resources/art/";

        void OnPreprocessTexture()
        {
            if (!assetPath.StartsWith(ArtFolder)) return;

            var importer = (TextureImporter)assetImporter;
            importer.textureType = TextureImporterType.Sprite;
            importer.spriteImportMode = SpriteImportMode.Single;
            importer.spritePixelsPerUnit = 100f;
            importer.alphaIsTransparency = true;
            importer.mipmapEnabled = false;                 // UI is never minified; mips only cost memory
            importer.filterMode = FilterMode.Bilinear;
            importer.wrapMode = TextureWrapMode.Clamp;
            importer.textureCompression = TextureImporterCompression.CompressedHQ;
            importer.maxTextureSize = 2048;
            importer.isReadable = false;

            var settings = new TextureImporterPlatformSettings
            {
                name = "Android",
                overridden = true,
                maxTextureSize = 2048,
                format = TextureImporterFormat.ASTC_6x6,
                compressionQuality = 100
            };
            importer.SetPlatformTextureSettings(settings);

            settings.name = "iPhone";
            importer.SetPlatformTextureSettings(settings);
        }

        void OnPostprocessTexture(Texture2D texture)
        {
            if (!assetPath.StartsWith(ArtFolder)) return;

            string id = System.IO.Path.GetFileNameWithoutExtension(assetPath);
            if (!ArtCatalog.TryGet(id, out var entry))
            {
                Debug.LogWarning(
                    "[art] " + assetPath + " is not in art/manifest.json, so nothing will ever load it. " +
                    "Add it to the manifest (python3 tools/art/art.py --emit) or delete the file.");
                return;
            }

            if (texture.width != entry.Width || texture.height != entry.Height)
            {
                Debug.LogError(
                    "[art] " + id + " is " + texture.width + "x" + texture.height + ", the manifest says " +
                    entry.Width + "x" + entry.Height + ". Fix the export or the manifest — a wrong size " +
                    "looks like a layout bug later.");
            }
        }
    }
}
