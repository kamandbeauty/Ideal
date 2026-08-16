using System;
using RubyRun3D.Army;
using RubyRun3D.Combat;
using RubyRun3D.Data;
using UnityEngine;

namespace RubyRun3D.Gates
{
    public sealed class GatePairController : MonoBehaviour
    {
        GateRuntime left;
        GateRuntime right;
        Transform player;
        ArmyManager army;
        bool applied;
        public event Action<string,int,int> GateApplied;

        public void Initialize(Transform runner,ArmyManager armyManager,GateOperation leftOperation,int leftValue,
            GateOperation rightOperation,int rightValue)
        {
            player=runner;army=armyManager;
            left=CreateGate("LeftGate",-2.15f,leftOperation,leftValue);
            right=CreateGate("RightGate",2.15f,rightOperation,rightValue);
        }

        GateRuntime CreateGate(string gateName,float x,GateOperation operation,int value)
        {
            var gate=new GameObject(gateName);gate.transform.SetParent(transform,false);gate.transform.localPosition=new Vector3(x,0,0);
            var runtime=gate.AddComponent<GateRuntime>();runtime.Initialize(operation,value);
            return runtime;
        }

        void Update()
        {
            if(applied||!player||player.position.z<transform.position.z)return;
            applied=true;var selected=player.position.x<0?left:right;var before=army.Count;
            army.ApplyGate(selected.Apply);GateApplied?.Invoke(selected.Label,before,army.Count);
            selected.PlaySelected();(selected==left?right:left).PlayRejected();
        }
    }

    public sealed class GateRuntime:MonoBehaviour
    {
        GateOperation operation;int value;Color color;Transform glow;
        public string Label=>operation switch{GateOperation.Add=>$"+{value}",GateOperation.Subtract=>$"−{value}",GateOperation.Multiply=>$"×{value}",GateOperation.Divide=>$"÷{value}",_=>value.ToString()};
        public void Initialize(GateOperation op,int number)
        {
            operation=op;value=number;
            color=op switch{GateOperation.Subtract=>new Color(.92f,.16f,.2f),GateOperation.Multiply=>new Color(.44f,.24f,.95f),GateOperation.Divide=>new Color(.95f,.45f,.12f),_=>new Color(.14f,.78f,.4f)};
            Core.StylizedFactory.Part("PostL",transform,Core.StylizedFactory.Box(),new Vector3(-1.25f,1.5f,0),new Vector3(.22f,3f,.28f),color);
            Core.StylizedFactory.Part("PostR",transform,Core.StylizedFactory.Box(),new Vector3(1.25f,1.5f,0),new Vector3(.22f,3f,.28f),color);
            glow=Core.StylizedFactory.Part("HeaderGlow",transform,Core.StylizedFactory.Box(),new Vector3(0,3f,0),new Vector3(2.72f,.32f,.32f),color).transform;
            var textObject=new GameObject("GateLabel");textObject.transform.SetParent(transform,false);textObject.transform.localPosition=new Vector3(0,1.85f,-.16f);textObject.transform.localRotation=Quaternion.Euler(0,180,0);
            var text=textObject.AddComponent<TextMesh>();text.text=Label;text.fontSize=90;text.characterSize=.035f;text.anchor=TextAnchor.MiddleCenter;text.alignment=TextAlignment.Center;text.color=Color.white;text.fontStyle=FontStyle.Bold;
        }
        public int Apply(int count)=>operation switch{GateOperation.Add=>count+value,GateOperation.Subtract=>Mathf.Max(0,count-value),GateOperation.Multiply=>count*value,GateOperation.Divide=>Mathf.Max(0,count/Mathf.Max(1,value)),_=>count};
        public void PlaySelected(){VfxBurst.Spawn(transform.position+Vector3.up*1.6f,color,14);StartCoroutine(Pulse());}
        public void PlayRejected(){foreach(var renderer in GetComponentsInChildren<Renderer>())renderer.material.color*=.4f;}
        System.Collections.IEnumerator Pulse(){for(var t=0f;t<.35f;t+=Time.deltaTime){glow.localScale=Vector3.one*(1+Mathf.Sin(t*20)*.12f);yield return null;}glow.localScale=Vector3.one;}
    }
}
