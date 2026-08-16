using System;
using UnityEngine;

namespace RubyRun3D.Combat
{
    public sealed class Damageable : MonoBehaviour
    {
        public float MaxHealth { get; private set; }
        public float Health { get; private set; }
        public bool IsAlive => Health > 0;
        public event Action<Damageable> Died;
        public event Action<float, float> HealthChanged;

        public void Initialize(float health)
        {
            MaxHealth = Health = Mathf.Max(1, health);
            HealthChanged?.Invoke(Health, MaxHealth);
        }

        public void ApplyDamage(float amount)
        {
            if (!IsAlive) return;
            Health = Mathf.Max(0, Health - Mathf.Max(0, amount));
            HealthChanged?.Invoke(Health, MaxHealth);
            if (Health <= 0) Died?.Invoke(this);
        }
    }
}
