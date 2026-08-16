using System;
using System.Collections.Generic;
using RubyRun3D.Combat;
using UnityEngine;

namespace RubyRun3D.Army
{
    public sealed class ArmyManager : MonoBehaviour
    {
        readonly List<SoldierController> active = new();
        readonly Queue<SoldierController> pool = new();
        Transform leader;
        ProjectileSystem projectiles;
        float soldierDamage = 4;
        int capacity = 80;
        float rubyCooldown;
        float rubyHealth;
        public int Count => active.Count;
        public bool RubyAlive => rubyHealth > 0;
        public event Action<int> CountChanged;

        public void Initialize(Transform ruby, ProjectileSystem projectileSystem, int initial, int maxCapacity, float damage, float leaderHealth)
        {
            leader = ruby; projectiles = projectileSystem; capacity = maxCapacity; soldierDamage = damage;
            rubyHealth = leaderHealth;
            for (var i=0;i<80;i++) pool.Enqueue(CreateSoldier());
            SetCount(initial);
        }

        public void SetCount(int requested)
        {
            var target = Mathf.Clamp(requested, 0, capacity);
            while (active.Count < target)
            {
                var soldier = pool.Count > 0 ? pool.Dequeue() : CreateSoldier();
                active.Add(soldier);
                soldier.Initialize(leader, Vector3.zero, projectiles, soldierDamage, active.Count);
            }
            while (active.Count > target)
            {
                var last = active[^1]; active.RemoveAt(active.Count-1); last.gameObject.SetActive(false); pool.Enqueue(last);
            }
            RefreshFormation(); CountChanged?.Invoke(active.Count);
        }

        public void ApplyGate(Func<int,int> operation) => SetCount(operation(Count));

        public void LoseSoldiers(int amount)
        {
            amount = Mathf.Max(1, amount);
            if (Count > 0) SetCount(Mathf.Max(0, Count - amount));
            else rubyHealth = Mathf.Max(0, rubyHealth - amount * 5f);
        }

        void RefreshFormation()
        {
            const float spacing = .72f;
            for (var i=0;i<active.Count;i++)
            {
                var row = Mathf.FloorToInt(Mathf.Sqrt(i));
                var first = row*row;
                var inRow = i-first;
                var rowCount = row*2+1;
                var x = (inRow-(rowCount-1)*.5f)*spacing;
                var z = -1.5f-row*.78f-Mathf.Abs(x)*.06f;
                active[i].SetOffset(new Vector3(x,0,z));
            }
        }

        SoldierController CreateSoldier()
        {
            var root=new GameObject("Soldier_Pooled"); root.transform.SetParent(transform);
            var visual=Core.StylizedFactory.CreateSoldier(root.transform,new Color(.16f,.48f,.78f));
            visual.AddComponent<Core.BobAnimator>();
            var lod=root.AddComponent<LODGroup>();
            lod.SetLODs(new[]{new LOD(.08f,visual.GetComponentsInChildren<Renderer>()),new LOD(.015f,Array.Empty<Renderer>())});
            lod.RecalculateBounds();
            var soldier=root.AddComponent<SoldierController>(); root.SetActive(false); return soldier;
        }

        void Update()
        {
            rubyCooldown -= Time.deltaTime;
            var target = Enemies.EnemyController.FindClosest(leader.position, 22f);
            if (target && rubyCooldown <= 0)
            {
                projectiles.Fire(leader.position+Vector3.up*1.2f+Vector3.forward*.5f,target.Damageable,
                    soldierDamage*1.8f,new Color(1f,.35f,.15f));
                rubyCooldown=.38f;
            }
        }
    }
}
