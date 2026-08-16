using System.Collections.Generic;
using UnityEngine;

namespace RubyRun3D.Combat
{
    public sealed class ProjectileSystem : MonoBehaviour
    {
        readonly Queue<Projectile> available = new();
        readonly HashSet<Projectile> active = new();
        Material material;

        public void Initialize(int warmCount = 50)
        {
            material = Core.StylizedFactory.Material(new Color(1f,.75f,.15f), .2f, .65f);
            for (var i=0;i<warmCount;i++) available.Enqueue(Create());
        }

        public void Fire(Vector3 origin, Damageable target, float damage, Color color)
        {
            if (!target || !target.IsAlive) return;
            var projectile = available.Count > 0 ? available.Dequeue() : Create();
            active.Add(projectile);
            projectile.gameObject.SetActive(true);
            projectile.Launch(origin, target, damage, color, Release);
        }

        Projectile Create()
        {
            var go = Core.StylizedFactory.Part("PooledProjectile", transform, Core.StylizedFactory.Sphere(),
                Vector3.zero, new Vector3(.08f,.08f,.24f), Color.yellow);
            var projectile = go.AddComponent<Projectile>();
            go.SetActive(false);
            return projectile;
        }

        void Release(Projectile projectile)
        {
            if (!active.Remove(projectile)) return;
            projectile.gameObject.SetActive(false);
            available.Enqueue(projectile);
        }
    }

    public sealed class Projectile : MonoBehaviour
    {
        Damageable target;
        float damage;
        float age;
        System.Action<Projectile> release;

        public void Launch(Vector3 origin, Damageable destination, float amount, Color color, System.Action<Projectile> callback)
        {
            transform.position = origin; target = destination; damage = amount; release = callback; age = 0;
            GetComponent<MeshRenderer>().sharedMaterial = Core.StylizedFactory.Material(color, .1f, .7f);
        }

        void Update()
        {
            age += Time.deltaTime;
            if (!target || !target.IsAlive || age > 2f) { release?.Invoke(this); return; }
            var destination = target.transform.position + Vector3.up * .8f;
            transform.position = Vector3.MoveTowards(transform.position, destination, 22f * Time.deltaTime);
            transform.LookAt(destination);
            if ((transform.position-destination).sqrMagnitude < .08f)
            {
                target.ApplyDamage(damage);
                VfxBurst.Spawn(destination, new Color(1f,.6f,.15f), 5);
                release?.Invoke(this);
            }
        }
    }

    public static class VfxBurst
    {
        public static void Spawn(Vector3 position, Color color, int count)
        {
            var root = new GameObject("ImpactVFX"); root.transform.position = position;
            for (var i=0;i<count;i++)
            {
                var piece = Core.StylizedFactory.Part("Spark", root.transform, Core.StylizedFactory.Sphere(), Vector3.zero,
                    Vector3.one*.055f, color);
                var body = piece.AddComponent<Rigidbody>(); body.useGravity = true; body.mass = .02f;
                body.linearVelocity = Random.onUnitSphere * Random.Range(1.5f,3.2f);
            }
            Object.Destroy(root, .55f);
        }
    }
}
