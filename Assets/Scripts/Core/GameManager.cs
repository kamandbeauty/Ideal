using System;
using System.Collections.Generic;
using RubyRun3D.Army;
using RubyRun3D.Combat;
using RubyRun3D.Data;
using RubyRun3D.Player;
using RubyRun3D.Services;
using RubyRun3D.Stage;
using RubyRun3D.UI;
using UnityEngine;

namespace RubyRun3D.Core
{
    public sealed class GameManager:MonoBehaviour
    {
        SaveManager save;UpgradeManager upgrades;SkinManager skins;RewardManager rewards;AdManager ads;AudioManager audio;UIManager ui;
        GameObject world;Transform ruby;ArmyManager army;StageManager stageManager;PlayerController player;
        readonly List<StageDefinition> stages=new();

        public void Initialize()
        {
            save=new SaveManager();save.Load();upgrades=new UpgradeManager(save);skins=new SkinManager(save);rewards=new RewardManager(save);ads=new AdManager();
            PerformanceManager.Apply((QualityProfile)save.Data.quality);
            var audioSource=gameObject.AddComponent<AudioSource>();audio=new AudioManager(audioSource,save);
            ui=gameObject.AddComponent<UIManager>();ui.Initialize();CreateDefinitions();ShowMenu();
        }

        void CreateDefinitions()
        {
            for(var number=1;number<=10;number++)
            {
                var data=ScriptableObject.CreateInstance<StageDefinition>();data.stageNumber=number;data.startingSoldiers=10;
                data.length=145+number*8;data.completionCoins=100+number*25;
                data.gatePairs=new List<GatePair>{
                    new(){z=28,leftOperation=GateOperation.Multiply,leftValue=2,rightOperation=GateOperation.Subtract,rightValue=3},
                    new(){z=64,leftOperation=GateOperation.Add,leftValue=10,rightOperation=GateOperation.Subtract,rightValue=Mathf.Min(10,3+number)},
                    new(){z=102,leftOperation=number>3?GateOperation.Multiply:GateOperation.Add,leftValue=number>3?3:10,rightOperation=GateOperation.Divide,rightValue=2}};
                data.waves=new List<EnemyWave>{
                    new(){z=45,archetype=number<3?EnemyArchetype.Normal:EnemyArchetype.Ranged,count=5+number},
                    new(){z=82,archetype=number<2?EnemyArchetype.Normal:EnemyArchetype.Heavy,count=7+number},
                    new(){z=128,archetype=number%5==0?EnemyArchetype.Boss:EnemyArchetype.Heavy,count=number%5==0?1:3+number/2}};
                data.hasBoss=number%5==0;stages.Add(data);
            }
        }

        public void ShowMenu()
        {
            CleanupWorld();CreatePresentationWorld();
            ui.ShowMenu(save.Data.coins,save.Data.currentStage,StartStage,ShowUpgrades,ShowSkins,ShowSettings,ClaimDaily);
        }

        void CreatePresentationWorld()
        {
            world=new GameObject("ArmyBase_Menu");var camera=CreateLightingAndCamera(null);
            var skin=skins.Selected;var hero=new GameObject("Ruby_Menu");hero.transform.SetParent(world.transform);hero.transform.position=new Vector3(0,0,4);
            StylizedFactory.CreateRuby(hero.transform,skin.Fur,skin.Accent).AddComponent<BobAnimator>();
            for(var i=0;i<8;i++){var soldier=new GameObject("MenuSoldier");soldier.transform.SetParent(world.transform);soldier.transform.position=new Vector3((i%4-1.5f)*1.1f,0,1-i/4*1.2f);StylizedFactory.CreateSoldier(soldier.transform,new Color(.16f,.48f,.78f)).AddComponent<BobAnimator>();}
            var ground=StylizedFactory.Part("BaseGround",world.transform,StylizedFactory.Box(),new Vector3(0,-.25f,4),new Vector3(18,.4f,18),new Color(.23f,.58f,.28f));
            for(var i=0;i<10;i++)StylizedFactory.CreateProp("BaseProp",world.transform,new Vector3((i%2==0?-1:1)*UnityEngine.Random.Range(5,8),0,UnityEngine.Random.Range(-2,10)),i);
            camera.transform.position=new Vector3(0,5.8f,-8);camera.transform.LookAt(new Vector3(0,1,3));
        }

        public void StartStage()
        {
            CleanupWorld();world=new GameObject("StageWorld");
            var stage=stages[Mathf.Clamp(save.Data.currentStage-1,0,stages.Count-1)];
            ruby=new GameObject("Ruby_Player").transform;ruby.SetParent(world.transform);ruby.position=Vector3.zero;
            var skin=skins.Selected;StylizedFactory.CreateRuby(ruby,skin.Fur,skin.Accent).AddComponent<BobAnimator>();
            var rigidbody=ruby.gameObject.AddComponent<Rigidbody>();rigidbody.isKinematic=true;rigidbody.useGravity=false;
            var collider=ruby.gameObject.AddComponent<CapsuleCollider>();collider.center=new Vector3(0,1,0);collider.height=2;collider.radius=.5f;
            player=ruby.gameObject.AddComponent<PlayerController>();player.Running=true;
            var projectiles=new GameObject("ProjectilePool").AddComponent<ProjectileSystem>();projectiles.transform.SetParent(world.transform);projectiles.Initialize();
            army=new GameObject("Army").AddComponent<ArmyManager>();army.transform.SetParent(world.transform);
            army.Initialize(ruby,projectiles,stage.startingSoldiers,upgrades.ArmyCapacity,upgrades.ArmyDamage,upgrades.RubyHealth);
            stageManager=new GameObject("StageManager").AddComponent<StageManager>();stageManager.transform.SetParent(world.transform);
            stageManager.Initialize(ruby,army,player,stage);stageManager.GateFeedback+=OnGateFeedback;stageManager.Finished+=OnStageFinished;
            army.CountChanged+=count=>ui.UpdateArmy(count);
            CreateLightingAndCamera(ruby);ui.ShowHud(stage.stageNumber,save.Data.coins,army.Count);
        }

        void OnGateFeedback(string operation,int before,int after){audio.PlayPositive();ui.GateFeedback(operation,before,after);}
        void OnStageFinished(bool victory)
        {
            var stage=stages[Mathf.Clamp(save.Data.currentStage-1,0,stages.Count-1)];
            if(victory){save.Data.coins+=stage.completionCoins;save.Data.currentStage=save.Data.currentStage>=10?1:save.Data.currentStage+1;save.Save();audio.PlayPositive();}
            else{audio.PlayImpact();audio.Vibrate();}
            ui.ShowResult(victory,stage.completionCoins,army.Count,victory?StartStage:RetryStage,RetryStage,ShowMenu);
        }
        void RetryStage()=>StartStage();

        void ShowUpgrades()
        {
            var kinds=(UpgradeKind[])Enum.GetValues(typeof(UpgradeKind));var rows=new string[kinds.Length];var actions=new Action[kinds.Length];
            for(var i=0;i<kinds.Length;i++){var index=i;var kind=kinds[i];rows[i]=$"{Split(kind.ToString())}   LV.{upgrades.Level(kind)}   ◆{upgrades.Price(kind)}";actions[i]=()=>{audio.PlayClick();upgrades.Purchase(kinds[index]);ShowUpgrades();};}
            ui.ShowList($"UPGRADES   ◆{save.Data.coins}",rows,actions,ShowMenu);
        }
        void ShowSkins()
        {
            var rows=new string[skins.Skins.Count];var actions=new Action[rows.Length];
            for(var i=0;i<rows.Length;i++){var index=i;var skin=skins.Skins[i];var unlocked=save.Data.unlockedSkins.Contains(skin.Id);rows[i]=$"{skin.Name}   {(save.Data.selectedSkin==skin.Id?"EQUIPPED":unlocked?"SELECT":$"◆{skin.Price}")}";actions[i]=()=>{skins.PurchaseOrEquip(skins.Skins[index]);ShowSkins();};}
            ui.ShowList($"RUBY SKINS   ◆{save.Data.coins}",rows,actions,ShowMenu);
        }
        void ShowSettings()
        {
            var rows=new[]{$"MUSIC  {(save.Data.music?"ON":"OFF")}",$"SOUND  {(save.Data.sound?"ON":"OFF")}",$"VIBRATION  {(save.Data.vibration?"ON":"OFF")}",$"QUALITY  {(QualityProfile)save.Data.quality}","RESET LOCAL DATA"};
            Action[] actions={()=>{save.Data.music=!save.Data.music;save.Save();ShowSettings();},()=>{save.Data.sound=!save.Data.sound;save.Save();ShowSettings();},()=>{save.Data.vibration=!save.Data.vibration;save.Save();ShowSettings();},()=>{save.Data.quality=(save.Data.quality+1)%3;save.Save();PerformanceManager.Apply((QualityProfile)save.Data.quality);ShowSettings();},()=>ui.ShowConfirm("Delete coins, upgrades, skins and progress from this device?",()=>{save.ResetAll();ShowMenu();},ShowSettings)};
            ui.ShowList("SETTINGS",rows,actions,ShowMenu);
        }
        void ClaimDaily(){var reward=rewards.Claim();if(reward>0)audio.PlayPositive();ShowMenu();}
        static string Split(string value)=>System.Text.RegularExpressions.Regex.Replace(value,"([a-z])([A-Z])","$1 $2").ToUpperInvariant();

        Camera CreateLightingAndCamera(Transform target)
        {
            RenderSettings.ambientLight=new Color(.62f,.72f,.76f);RenderSettings.fog=true;RenderSettings.fogColor=new Color(.48f,.7f,.76f);RenderSettings.fogMode=FogMode.Linear;RenderSettings.fogStartDistance=48;RenderSettings.fogEndDistance=105;
            var sun=new GameObject("Sun");sun.transform.SetParent(world.transform);sun.transform.rotation=Quaternion.Euler(48,-28,0);var light=sun.AddComponent<Light>();light.type=LightType.Directional;light.color=new Color(1f,.86f,.68f);light.intensity=1.25f;light.shadows=LightShadows.Soft;
            var cameraGo=new GameObject("Main Camera");cameraGo.tag="MainCamera";cameraGo.transform.SetParent(world.transform);var camera=cameraGo.AddComponent<Camera>();camera.fieldOfView=53;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.38f,.7f,.86f);camera.farClipPlane=130;
            if(target){var follow=cameraGo.AddComponent<ThirdPersonCamera>();follow.target=target;follow.ConfigureCinemachineIfPresent();cameraGo.transform.position=target.position+follow.offset;}
            return camera;
        }
        void CleanupWorld(){if(world)Destroy(world);}
    }
}
