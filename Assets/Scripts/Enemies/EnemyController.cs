using System.Collections.Generic;
using RubyRun3D.Army;
using RubyRun3D.Combat;
using RubyRun3D.Data;
using UnityEngine;

namespace RubyRun3D.Enemies
{
    public sealed class EnemyController : MonoBehaviour
    {
        static readonly List<EnemyController> Active = new();
        public Damageable Damageable { get; private set; }
        EnemyArchetype archetype;
        Transform player;
        ArmyManager army;
        float damage;
        float moveSpeed;
        float range;
        float cooldown;
        bool engaged;
        public static int AliveCount => Active.Count;

        public void Initialize(EnemyArchetype type, Transform target, ArmyManager playerArmy, float healthScale = 1)
        {
            archetype=type;player=target;army=playerArmy;
            damage=type switch {EnemyArchetype.Heavy=>3,EnemyArchetype.Ranged=>2,EnemyArchetype.Boss=>8,_=>1};
            moveSpeed=type switch {EnemyArchetype.Heavy=>1.5f,EnemyArchetype.Boss=>1.1f,_=>2.4f};
            range=type==EnemyArchetype.Ranged?8f:type==EnemyArchetype.Boss?3.5f:1.8f;
            var health=(type switch {EnemyArchetype.Heavy=>65,EnemyArchetype.Ranged=>38,EnemyArchetype.Boss=>850,_=>28})*healthScale;
            Damageable=gameObject.AddComponent<Damageable>();Damageable.Initialize(health);Damageable.Died+=OnDeath;
            Active.Add(this);
        }

        public static EnemyController FindClosest(Vector3 origin,float maxRange)
        {
            EnemyController best=null;var bestDistance=maxRange*maxRange;
            for(var i=Active.Count-1;i>=0;i--)
            {
                var enemy=Active[i];if(!enemy||!enemy.Damageable.IsAlive){Active.RemoveAt(i);continue;}
                var distance=(enemy.transform.position-origin).sqrMagnitude;
                if(distance<bestDistance){bestDistance=distance;best=enemy;}
            }
            return best;
        }

        void Update()
        {
            if(!player||!Damageable.IsAlive)return;
            var distance=Vector3.Distance(transform.position,player.position);
            engaged|=distance<20;
            if(!engaged)return;
            if(distance>range) transform.position=Vector3.MoveTowards(transform.position,player.position,moveSpeed*Time.deltaTime);
            else if((cooldown-=Time.deltaTime)<=0)
            {
                army.LoseSoldiers(Mathf.CeilToInt(damage));
                VfxBurst.Spawn(player.position+Vector3.up*.8f,new Color(1f,.2f,.1f),archetype==EnemyArchetype.Boss?12:4);
                cooldown=archetype==EnemyArchetype.Boss?1.4f:1.1f;
            }
            var direction=player.position-transform.position;direction.y=0;
            if(direction.sqrMagnitude>.1f)transform.rotation=Quaternion.Slerp(transform.rotation,Quaternion.LookRotation(direction),Time.deltaTime*5f);
        }

        void OnDestroy() => Active.Remove(this);

        void OnDeath(Damageable _)
        {
            Active.Remove(this);enabled=false;
            foreach(var renderer in GetComponentsInChildren<Renderer>()) renderer.material.color=Color.Lerp(renderer.material.color,Color.gray,.7f);
            transform.rotation=Quaternion.Euler(75,0,Random.Range(-20,20));
            VfxBurst.Spawn(transform.position+Vector3.up,new Color(.8f,.25f,.15f),8);
            Destroy(gameObject,1.2f);
        }
    }
}
