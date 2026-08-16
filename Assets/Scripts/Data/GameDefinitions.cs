using System;
using System.Collections.Generic;
using UnityEngine;

namespace RubyRun3D.Data
{
    public enum GateOperation { Add, Subtract, Multiply, Divide }
    public enum EnemyArchetype { Normal, Heavy, Ranged, Boss }
    public enum QualityProfile { Low, Medium, High }

    [CreateAssetMenu(menuName = "Ruby Run/Enemy Definition")]
    public sealed class EnemyDefinition : ScriptableObject
    {
        public string id = "normal";
        public EnemyArchetype archetype;
        [Min(1)] public float health = 25;
        [Min(0)] public float damage = 3;
        [Min(0.1f)] public float attackInterval = 1.2f;
        [Min(0.1f)] public float moveSpeed = 2.5f;
        [Min(1)] public float range = 2.2f;
        [Min(0)] public int coinReward = 2;
        public Color primaryColor = new(0.75f, 0.22f, 0.25f);
    }

    [CreateAssetMenu(menuName = "Ruby Run/Gate Definition")]
    public sealed class GateDefinition : ScriptableObject
    {
        public string id = "multiply_2";
        public GateOperation operation;
        [Min(1)] public int value = 2;
        public Color frameColor = new(0.35f, 0.35f, 1f);

        public int Apply(int current) => operation switch
        {
            GateOperation.Add => current + value,
            GateOperation.Subtract => Mathf.Max(0, current - value),
            GateOperation.Multiply => current * value,
            GateOperation.Divide => Mathf.Max(0, current / Mathf.Max(1, value)),
            _ => current
        };

        public string Label => operation switch
        {
            GateOperation.Add => $"+{value}",
            GateOperation.Subtract => $"−{value}",
            GateOperation.Multiply => $"×{value}",
            GateOperation.Divide => $"÷{value}",
            _ => value.ToString()
        };
    }

    [Serializable]
    public sealed class GatePair
    {
        public GateOperation leftOperation;
        public int leftValue;
        public GateOperation rightOperation;
        public int rightValue;
        [Min(5)] public float z;
    }

    [Serializable]
    public sealed class EnemyWave
    {
        public EnemyArchetype archetype;
        [Min(1)] public int count = 5;
        [Min(5)] public float z;
    }

    [CreateAssetMenu(menuName = "Ruby Run/Stage Definition")]
    public sealed class StageDefinition : ScriptableObject
    {
        [Min(1)] public int stageNumber = 1;
        [Min(5)] public int startingSoldiers = 10;
        [Min(30)] public float length = 150;
        [Min(0)] public int completionCoins = 100;
        public List<GatePair> gatePairs = new();
        public List<EnemyWave> waves = new();
        public bool hasBoss;
        public EnemyArchetype bossArchetype = EnemyArchetype.Boss;
    }

    [CreateAssetMenu(menuName = "Ruby Run/Upgrade Definition")]
    public sealed class UpgradeDefinition : ScriptableObject
    {
        public string id;
        public string displayName;
        public float baseValue;
        public float valuePerLevel;
        public int basePrice = 100;
        public float priceMultiplier = 1.55f;
        public int maxLevel = 20;
        public float ValueAt(int level) => baseValue + valuePerLevel * Mathf.Max(0, level - 1);
        public int PriceAt(int level) => Mathf.RoundToInt(basePrice * Mathf.Pow(priceMultiplier, Mathf.Max(0, level - 1)));
    }

    [CreateAssetMenu(menuName = "Ruby Run/Skin Definition")]
    public sealed class SkinDefinition : ScriptableObject
    {
        public string id;
        public string displayName;
        public int price;
        public Color furColor = new(0.9f, 0.28f, 0.12f);
        public Color accentColor = Color.white;
        public GameObject replacementPrefab;
    }
}
