using System.Collections.Generic;
using Shazdeh.Content;
using Shazdeh.Core;
using UnityEngine;

namespace Shazdeh.Game
{
    /// <summary>
    /// Where levels come from today: Resources. The architecture wants them served from the CDN with
    /// this as the bundled fallback, so every caller goes through this one class and swapping the
    /// source later is a change in one file.
    /// </summary>
    public static class LevelSource
    {
        public const string DefaultChapter = "ch01";
        public const int DefaultLevelCount = 10;

        public static string LoadJson(int number, string chapter)
        {
            string path = "levels/" + chapter + "/level-" + number.ToString("000");
            var asset = Resources.Load<TextAsset>(path);
            return asset != null ? asset.text : null;
        }

        public static LevelDefinition LoadLevel(int number, string chapter, List<string> errors)
        {
            string json = LoadJson(number, chapter);
            if (json == null)
            {
                if (errors != null) errors.Add("level " + number + " not found in Resources");
                return null;
            }

            var level = LevelParser.Parse(json, errors);

            if (level != null && errors != null)
            {
                var validation = LevelValidator.Validate(level);
                errors.AddRange(validation);
            }
            return level;
        }

        public static List<LevelDefinition> LoadChapter(string chapter, int count, List<string> errors)
        {
            var levels = new List<LevelDefinition>();
            for (int n = 1; n <= count; n++)
            {
                var level = LoadLevel(n, chapter, errors);
                if (level != null) levels.Add(level);
            }
            return levels;
        }
    }
}
