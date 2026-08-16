using System;
using System.Collections.Generic;
using RubyRun3D.Army;
using RubyRun3D.Data;
using RubyRun3D.Enemies;
using RubyRun3D.Gates;
using RubyRun3D.Player;
using UnityEngine;

namespace RubyRun3D.Stage
{
    public sealed class StageManager:MonoBehaviour
    {
        readonly List<GameObject> spawned=new();
        Transform player;ArmyManager army;PlayerController controller;StageDefinition definition;
        public event Action<string,int,int> GateFeedback;
        public event Action<bool> Finished;
        bool ended;
        public void Initialize(Transform runner,ArmyManager playerArmy,PlayerController playerController,StageDefinition stage)
        {
            player=runner;army=playerArmy;controller=playerController;definition=stage;BuildEnvironment();BuildGates();BuildWaves();
        }
        void BuildEnvironment()
        {
            var road=Core.StylizedFactory.Material(new Color(.44f,.39f,.32f));var grass=Core.StylizedFactory.Material(new Color(.24f,.62f,.31f));
            for(var z=0;z<definition.length;z+=12)
            {
                var section=CreateSurface("Road",new Vector3(0,-.12f,z+6),new Vector3(8,0.22f,12),road);spawned.Add(section);
                spawned.Add(CreateSurface("GrassL",new Vector3(-8,-.18f,z+6),new Vector3(8,0.16f,12),grass));
                spawned.Add(CreateSurface("GrassR",new Vector3(8,-.18f,z+6),new Vector3(8,0.16f,12),grass));
                for(var side=-1;side<=1;side+=2)
                {
                    var prop=Core.StylizedFactory.CreateProp($"Prop_{side}_{z}",transform,new Vector3(side*UnityEngine.Random.Range(6f,10f),0,z+UnityEngine.Random.Range(1f,11f)),z/12+side);
                    spawned.Add(prop);
                }
            }
            for(var i=0;i<10;i++)
            {
                var flower=Core.StylizedFactory.Part("Flower",transform,Core.StylizedFactory.Sphere(),new Vector3((i%2==0?-1:1)*UnityEngine.Random.Range(4.8f,7f),.12f,UnityEngine.Random.Range(3,definition.length-3)),Vector3.one*.1f,new Color(1f,.55f,.72f));spawned.Add(flower);
            }
        }
        GameObject CreateSurface(string name,Vector3 position,Vector3 scale,Material material)
        {
            var go=Core.StylizedFactory.Part(name,transform,Core.StylizedFactory.Box(),position,scale,Color.white);go.GetComponent<Renderer>().sharedMaterial=material;return go;
        }
        void BuildGates()
        {
            foreach(var pair in definition.gatePairs)
            {
                var root=new GameObject($"GatePair_{pair.z}");root.transform.SetParent(transform);root.transform.position=new Vector3(0,0,pair.z);
                var gate=root.AddComponent<GatePairController>();gate.Initialize(player,army,pair.leftOperation,pair.leftValue,pair.rightOperation,pair.rightValue);
                gate.GateApplied+=(label,before,after)=>GateFeedback?.Invoke(label,before,after);spawned.Add(root);
            }
        }
        void BuildWaves()
        {
            foreach(var wave in definition.waves)
            for(var i=0;i<wave.count;i++)
            {
                var columns=Mathf.CeilToInt(Mathf.Sqrt(wave.count));var x=(i%columns-(columns-1)*.5f)*1.25f;var z=wave.z+(i/columns)*1.25f;
                var root=new GameObject($"Enemy_{wave.archetype}_{i}");root.transform.SetParent(transform);root.transform.position=new Vector3(x,0,z);
                Core.StylizedFactory.CreateEnemy(root.transform,wave.archetype).AddComponent<Core.BobAnimator>();
                root.AddComponent<EnemyController>().Initialize(wave.archetype,player,army,1+(definition.stageNumber-1)*.08f);spawned.Add(root);
            }
        }
        void Update()
        {
            if(ended)return;
            if(!army.RubyAlive){ended=true;controller.Running=false;Finished?.Invoke(false);return;}
            if(player.position.z>=definition.length&&EnemyController.AliveCount==0){ended=true;controller.Running=false;Finished?.Invoke(true);}
        }
    }
}
