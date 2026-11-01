using System;
using System.Collections.Generic;
using Shazdeh.Core;

namespace Shazdeh.Content
{
    [Serializable]
    public sealed class ChapterJson
    {
        public string chapter;
        public DistrictJson[] districts;
    }

    [Serializable]
    public sealed class DistrictJson
    {
        public string id;
        public string title;
        public string title_en;
        public TaskJson[] tasks;
        public ChestJson chest;
    }

    [Serializable]
    public sealed class TaskJson
    {
        public string key;
        public string title;
        public string title_en;
        public string build_asset;
        public long potion_cost;
    }

    [Serializable]
    public sealed class ChestJson
    {
        public long coins;
        public long potions;
    }

    /// <summary>A buildable task in the meta layer. Offline this is content; online it becomes a row.</summary>
    public sealed class TaskDefinition
    {
        public string Key;
        public string Title;
        public string TitleEn;
        public string BuildAsset;
        public long PotionCost;

        public TaskCost ToCost() => new TaskCost(Key, PotionCost);
    }

    public sealed class DistrictDefinition
    {
        public string Id;
        public string Title;
        public string TitleEn;
        public readonly List<TaskDefinition> Tasks = new List<TaskDefinition>();
        public RewardBundle Chest;

        public List<TaskCost> Costs()
        {
            var costs = new List<TaskCost>();
            for (int i = 0; i < Tasks.Count; i++) costs.Add(Tasks[i].ToCost());
            return costs;
        }

        public long TotalPotionCost()
        {
            long total = 0;
            for (int i = 0; i < Tasks.Count; i++) total += Tasks[i].PotionCost;
            return total;
        }
    }

    public sealed class ChapterMeta
    {
        public string Chapter = "ch01";
        public readonly List<DistrictDefinition> Districts = new List<DistrictDefinition>();

        public DistrictDefinition Find(string id)
        {
            for (int i = 0; i < Districts.Count; i++)
                if (Districts[i].Id == id) return Districts[i];
            return null;
        }
    }
}
