using System.IO;
using Shazdeh.Game;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Shazdeh.EditorTools
{
    /// <summary>
    /// Headless entry points for GameCI. Called by .github/workflows/unity.yml as
    /// <c>-executeMethod Shazdeh.EditorTools.CiBuild.BuildAndroid</c>.
    ///
    /// Why not the default builder: it needs at least one scene already in Build Settings, and no
    /// scene is committed before the project is first opened in the editor. These methods create the
    /// boot scene from code, so CI works on a fresh clone with nothing but the repo.
    /// </summary>
    public static class CiBuild
    {
        const string AndroidOutput = "build/Android/Shazdeh.aab";
        const string IosOutput = "build/iOS";

        [MenuItem("کاخ شازده/Build/Android (AAB)")]
        public static void BuildAndroidMenu() => BuildAndroid();

        public static void BuildAndroid()
        {
            ApplyPlayerSettings();
            EditorUserBuildSettings.buildAppBundle = true;
            EditorUserBuildSettings.exportAsGoogleAndroidProject = false;
            Run(BuildTarget.Android, AndroidOutput);
        }

        [MenuItem("کاخ شازده/Build/iOS (Xcode project)")]
        public static void BuildIosMenu() => BuildIos();

        public static void BuildIos()
        {
            ApplyPlayerSettings();
            Run(BuildTarget.iOS, IosOutput);
        }

        static void Run(BuildTarget target, string output)
        {
            string scenePath = ShazdehMenu.EnsureAppScene();
            Directory.CreateDirectory(Path.GetDirectoryName(output) ?? "build");

            var options = new BuildPlayerOptions
            {
                scenes = new[] { scenePath },
                locationPathName = output,
                target = target,
                options = BuildOptions.None
            };

            var report = BuildPipeline.BuildPlayer(options);
            var summary = report.summary;

            Debug.Log("Build " + target + ": " + summary.result + ", " + summary.totalSize + " bytes in " +
                      summary.totalTime + ", " + summary.totalErrors + " error(s)");

            if (summary.result != BuildResult.Succeeded)
            {
                // GameCI reads the exit code; a failed build must fail the job.
                EditorApplication.Exit(1);
            }
        }

        static void ApplyPlayerSettings()
        {
            PlayerSettings.companyName = "Shazdeh";
            PlayerSettings.productName = "Shazdeh Palace";
            PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, "com.shazdeh.palace");
            PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.iOS, "com.shazdeh.palace");
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.allowedAutorotateToPortrait = true;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.iOS.targetOSVersionString = "13.0";
        }
    }
}
