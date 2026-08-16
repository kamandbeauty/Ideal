#if UNITY_EDITOR
using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace RubyRun3D.Editor
{
    public static class BuildAndroid
    {
        public static void BuildApk() => Build(false);
        public static void BuildAab() => Build(true);

        static void Build(bool bundle)
        {
            ProjectConfigurator.EnsureUrp();
            PlayerSettings.companyName="Studio Javid";PlayerSettings.productName="Ruby Run 3D";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android,"com.studiojavid.rubyrun");
            PlayerSettings.bundleVersion="1.0.0";PlayerSettings.Android.bundleVersionCode=1;
            PlayerSettings.Android.minSdkVersion=AndroidSdkVersions.AndroidApiLevel24;
            PlayerSettings.Android.targetSdkVersion=(AndroidSdkVersions)36;
            PlayerSettings.defaultInterfaceOrientation=UIOrientation.Portrait;
            PlayerSettings.Android.targetArchitectures=AndroidArchitecture.ARM64;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android,ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.minifyRelease=true;PlayerSettings.Android.minifyDebug=false;
            EditorUserBuildSettings.buildAppBundle=bundle;
            ConfigureSigning();
            Directory.CreateDirectory("Build/Android");
            var path=bundle?"Build/Android/RubyRun3D-release.aab":"Build/Android/RubyRun3D-release.apk";
            var options=new BuildPlayerOptions{scenes=new[]{"Assets/Scenes/Bootstrap.unity"},locationPathName=path,target=BuildTarget.Android,options=BuildOptions.CleanBuildCache};
            var report=BuildPipeline.BuildPlayer(options);
            if(report.summary.result!=BuildResult.Succeeded)throw new Exception($"Android build failed: {report.summary.result}, {report.summary.totalErrors} errors");
            Debug.Log($"Built {path} ({report.summary.totalSize} bytes)");
        }

        static void ConfigureSigning()
        {
            var keystore=Environment.GetEnvironmentVariable("ANDROID_KEYSTORE_PATH");
            var storePassword=Environment.GetEnvironmentVariable("ANDROID_KEYSTORE_PASSWORD");
            var alias=Environment.GetEnvironmentVariable("ANDROID_KEY_ALIAS");
            var keyPassword=Environment.GetEnvironmentVariable("ANDROID_KEY_PASSWORD");
            if(string.IsNullOrWhiteSpace(keystore)||string.IsNullOrWhiteSpace(storePassword)||string.IsNullOrWhiteSpace(alias)||string.IsNullOrWhiteSpace(keyPassword))
                throw new InvalidOperationException("Release signing environment is incomplete. Keystore and all four signing values are required.");
            PlayerSettings.Android.useCustomKeystore=true;PlayerSettings.Android.keystoreName=Path.GetFullPath(keystore);
            PlayerSettings.Android.keystorePass=storePassword;PlayerSettings.Android.keyaliasName=alias;PlayerSettings.Android.keyaliasPass=keyPassword;
        }
    }
}
#endif
