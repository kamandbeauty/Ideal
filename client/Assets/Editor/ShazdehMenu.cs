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
    /// Project menu for the things a human should not do by hand: building the M0 scenes from code
    /// (so no .unity file has to be hand-edited) and validating every level.
    /// </summary>
    public static class ShazdehMenu
    {
        public const string ScenesFolder = "Assets/Scenes";
        public const string GreyBoxScenePath = ScenesFolder + "/M0_Greybox.unity";
        public const string DesignScenePath = ScenesFolder + "/_DesignSystem.unity";

        [MenuItem("کاخ شازده/Create M0 scenes")]
        public static void CreateScenes()
        {
            var grey = CreateScene<GreyBoxGame>(GreyBoxScenePath);
            var design = CreateScene<DesignSystemView>(DesignScenePath);

            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(grey, true),
                new EditorBuildSettingsScene(design, false)
            };

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            Debug.Log("M0 scenes ready: " + GreyBoxScenePath + " (build), " + DesignScenePath + " (design check)");
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
        public static string EnsureGreyBoxScene()
        {
            if (!File.Exists(GreyBoxScenePath)) CreateScenes();
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(GreyBoxScenePath) == null) CreateScenes();
            return GreyBoxScenePath;
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
