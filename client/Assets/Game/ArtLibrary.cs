using System.Collections.Generic;
using UnityEngine;

namespace Shazdeh.Game
{
    /// <summary>
    /// Sprites by id, with a placeholder when the id has no art yet.
    ///
    /// Every screen asks for art the same way: `ArtLibrary.Get("piece_firouzeh")`. If the PNG is not
    /// there, Get returns null and the screen draws what it drew before — a token-coloured shape. That
    /// is what lets art arrive one file at a time without breaking the game, and it is why the art can
    /// be commissioned late without blocking the build.
    ///
    /// Ids come from ArtCatalog.gen.cs, generated from art/manifest.json. A screen cannot invent an id:
    /// it either exists in the catalog or the call is a typo. Use <see cref="IsKnown"/> to assert that
    /// in tests.
    /// </summary>
    public static class ArtLibrary
    {
        public const string ResourceFolder = "art/";

        static readonly Dictionary<string, Sprite> Cache = new Dictionary<string, Sprite>(64);
        static readonly List<string> MissingRequired = new List<string>(8);

        /// <summary>The sprite, or null when the art does not exist yet. Never throws.</summary>
        public static Sprite Get(string id)
        {
            if (string.IsNullOrEmpty(id)) return null;

            if (Cache.TryGetValue(id, out var cached)) return cached; // null is a valid cached answer

            var sprite = Resources.Load<Sprite>(ResourceFolder + id);
            Cache[id] = sprite;
            return sprite;
        }

        public static bool Has(string id) => Get(id) != null;

        /// <summary>True when the id is in the generated catalog — i.e. somebody is supposed to draw it.</summary>
        public static bool IsKnown(string id) => ArtCatalog.TryGet(id, out _);

        /// <summary>Drops the cache; the editor menu uses it after art is imported.</summary>
        public static void ResetCache() => Cache.Clear();

        /// <summary>
        /// Required ids that have no file yet, computed once and cached. The editor menu prints it; a
        /// build script can refuse to ship while it is not empty.
        /// </summary>
        public static IReadOnlyList<string> MissingRequiredIds
        {
            get
            {
                if (MissingRequired.Count > 0) return MissingRequired;

                foreach (var entry in ArtCatalog.Required())
                {
                    if (!Has(entry.Id)) MissingRequired.Add(entry.Id);
                }
                return MissingRequired;
            }
        }

        /// <summary>
        /// Places a sprite on a renderer so it fills one board cell regardless of its pixel size, and
        /// resets the tint so an artist's colours are not multiplied by a token colour.
        /// </summary>
        public static bool ApplyTo(SpriteRenderer renderer, string id, float worldSize)
        {
            if (renderer == null) return false;

            var sprite = Get(id);
            if (sprite == null) return false;

            renderer.sprite = sprite;
            renderer.color = Color.white;

            float largest = Mathf.Max(sprite.bounds.size.x, sprite.bounds.size.y);
            renderer.transform.localScale = largest <= 0f ? Vector3.one : Vector3.one * (worldSize / largest);
            return true;
        }

        /// <summary>Sets an Image's sprite when the art exists; false means "keep your placeholder".</summary>
        public static bool ApplyTo(UnityEngine.UI.Image image, string id, bool preserveAspect = true)
        {
            if (image == null) return false;

            var sprite = Get(id);
            if (sprite == null) return false;

            image.sprite = sprite;
            image.color = Color.white;
            image.type = UnityEngine.UI.Image.Type.Simple;
            image.preserveAspect = preserveAspect;
            return true;
        }
    }
}
