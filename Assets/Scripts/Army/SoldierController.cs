using RubyRun3D.Combat;
using RubyRun3D.Enemies;
using UnityEngine;

namespace RubyRun3D.Army
{
    public sealed class SoldierController : MonoBehaviour
    {
        Transform leader;
        Vector3 formationOffset;
        ProjectileSystem projectiles;
        float damage;
        float cooldown;
        float phase;

        public void Initialize(Transform follow, Vector3 offset, ProjectileSystem projectileSystem, float shotDamage, int index)
        {
            leader = follow; formationOffset = offset; projectiles = projectileSystem; damage = shotDamage;
            phase = index * .17f; gameObject.SetActive(true);
        }

        public void SetOffset(Vector3 offset) => formationOffset = offset;
        public void SetDamage(float value) => damage = value;

        void Update()
        {
            if (!leader) return;
            var delayed = leader.position + leader.rotation * formationOffset;
            delayed.y = 0;
            transform.position = Vector3.Lerp(transform.position, delayed, 1f - Mathf.Exp(-7f * Time.deltaTime));
            transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.identity, Time.deltaTime * 8f);
            cooldown -= Time.deltaTime;
            var target = EnemyController.FindClosest(transform.position, 18f);
            if (target && cooldown <= 0)
            {
                transform.rotation = Quaternion.LookRotation((target.transform.position-transform.position).normalized);
                projectiles.Fire(transform.position + Vector3.up*.9f + Vector3.forward*.35f, target.Damageable, damage,
                    new Color(.35f,.8f,1f));
                cooldown = .62f + phase % .15f;
            }
        }
    }
}
