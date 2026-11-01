using System.Collections.Generic;
using System.IO;
using Shazdeh.Content;
using Shazdeh.Core;
using Shazdeh.Game;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Shazdeh.EditorTools
{
    /// <summary>
    /// Project menu for the things a human should not do by hand: building the scenes from code (so no
    /// .unity file has to be hand-edited), validating content, and building the UI font asset.
    /// </summary>
    public static class ShazdehMenu
    {
        public const string ScenesFolder = "Assets/Scenes";
        public const string AppScenePath = ScenesFolder + "/App.unity";
        public const string DesignScenePath = ScenesFolder + "/_DesignSystem.unity";
        public const string PersianCheckScenePath = ScenesFolder + "/_PersianCheck.unity";

        [MenuItem("کاخ شازده/Create scenes")]
        public static void CreateScenes()
        {
            var app = CreateScene<AppRoot>(AppScenePath);
            var design = CreateScene<DesignSystemView>(DesignScenePath);
            var persian = CreateScene<Game.Ui.PersianCheckView>(PersianCheckScenePath);

            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(app, true),
                new EditorBuildSettingsScene(design, false),
                new EditorBuildSettingsScene(persian, false)
            };

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            if (!Game.Ui.ShazdehFonts.IsPersianFontInstalled)
                Debug.LogWarning("No Persian UI font yet: run کاخ شازده → Build UI font, or Persian text will draw with the fallback font. See docs/ui.md.");

            Debug.Log("Scenes ready: " + AppScenePath + " (build), " + DesignScenePath + " (design check), " +
                      PersianCheckScenePath + " (Persian check)");
        }

        [MenuItem("کاخ شازده/Validate levels")]
        public static void ValidateLevels()
        {
            var errors = new List<string>();
            var levels = LoadLevelsFromResources(errors);

            for (int i = 0; i < levels.Count; i++)
            {
                var levelErrors = LevelValidator.Validate(levels[i]);
                for (int e = 0; e < levelErrors.Count; e++) errors.Add(levelErrors[e]);
            }
            errors.AddRange(LevelValidator.ValidateCatalog(levels));

            if (errors.Count == 0)
            {
                Debug.Log("Levels OK: " + levels.Count + " levels, 0 errors.");
                return;
            }

            for (int i = 0; i < errors.Count; i++) Debug.LogError(errors[i]);
            Debug.LogError("Level validation failed with " + errors.Count + " error(s).");
        }

        [MenuItem("کاخ شازده/Check Persian text")]
        public static void CheckPersianText()
        {
            var samples = Game.Ui.PersianCheckView.Samples();
            for (int i = 0; i < samples.Length; i++)
            {
                string shaped = Shazdeh.Core.Text.PersianText.Shape(samples[i]);
                string visual = Shazdeh.Core.Text.PersianText.ToVisualOrder(shaped);
                Debug.Log("[text] " + samples[i] + " → shaped " + shaped + " → drawn " + visual);
            }
        }

        static List<LevelDefinition> LoadLevelsFromResources(List<string> errors)
        {
            var levels = new List<LevelDefinition>();
            for (int n = 1; n <= LevelSource.DefaultLevelCount; n++)
            {
                var level = LevelSource.LoadLevel(n, LevelSource.DefaultChapter, errors);
                if (level != null) levels.Add(level);
            }
            return levels;
        }

        /// <summary>Used by CI as well: creates the boot scene if the repo has never been opened in the editor.</summary>
        public static string EnsureAppScene()
        {
            if (!File.Exists(AppScenePath)) CreateScenes();
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(AppScenePath) == null) CreateScenes();
            return AppScenePath;
        }

        static string CreateScene<T>(string path) where T : MonoBehaviour
        {
            Directory.CreateDirectory(ScenesFolder);

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var root = new GameObject(typeof(T).Name);
            root.AddComponent<T>();

            EditorSceneManager.SaveScene(scene, path);
            return path;
        }
    }
}
