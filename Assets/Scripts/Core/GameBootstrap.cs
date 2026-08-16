using UnityEngine;

namespace RubyRun3D.Core
{
    public static class GameBootstrap
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Start()
        {
            if(Object.FindFirstObjectByType<GameManager>())return;
            Screen.orientation=ScreenOrientation.Portrait;
            var root=new GameObject("RubyRun3D");Object.DontDestroyOnLoad(root);root.AddComponent<GameManager>().Initialize();
        }
    }
}
