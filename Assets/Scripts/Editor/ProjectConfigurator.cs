#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace RubyRun3D.Editor
{
    [InitializeOnLoad]
    public static class ProjectConfigurator
    {
        const string GeneratedFolder="Assets/Settings";
        const string RendererPath=GeneratedFolder+"/RubyRunMobileRenderer.asset";
        const string PipelinePath=GeneratedFolder+"/RubyRunMobileURP.asset";

        static ProjectConfigurator()=>EditorApplication.delayCall+=EnsureUrp;

        public static void EnsureUrp()
        {
            if(!Directory.Exists(GeneratedFolder))Directory.CreateDirectory(GeneratedFolder);
            var renderer=AssetDatabase.LoadAssetAtPath<UniversalRendererData>(RendererPath);
            if(!renderer){renderer=ScriptableObject.CreateInstance<UniversalRendererData>();renderer.name="Ruby Run Mobile Renderer";AssetDatabase.CreateAsset(renderer,RendererPath);}
            var pipeline=AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(PipelinePath);
            if(!pipeline){pipeline=UniversalRenderPipelineAsset.Create(renderer);pipeline.name="Ruby Run Mobile URP";pipeline.renderScale=1f;pipeline.msaaSampleCount=2;pipeline.supportsHDR=false;pipeline.shadowDistance=35;AssetDatabase.CreateAsset(pipeline,PipelinePath);}
            GraphicsSettings.defaultRenderPipeline=pipeline;
            var previous=QualitySettings.GetQualityLevel();
            for(var i=0;i<QualitySettings.names.Length;i++){QualitySettings.SetQualityLevel(i,false);QualitySettings.renderPipeline=pipeline;}
            QualitySettings.SetQualityLevel(previous,false);AssetDatabase.SaveAssets();
        }
    }
}
#endif
