using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace RubyRun3D.Services
{
    [Serializable]
    public sealed class PlayerSave
    {
        public int version = 1;
        public int currentStage = 1;
        public int coins;
        public int rubyDamageLevel = 1;
        public int rubyHealthLevel = 1;
        public int armyDamageLevel = 1;
        public int armyCapacityLevel = 1;
        public string selectedSkin = "classic";
        public List<string> unlockedSkins = new() { "classic" };
        public long lastDailyClaimUtc;
        public int dailyDay;
        public long lastObservedUtc;
        public bool music = true;
        public bool sound = true;
        public bool vibration = true;
        public int quality = 1;
    }

    public sealed class SaveManager
    {
        const string FileName = "ruby_run_3d_save.json";
        public PlayerSave Data { get; private set; } = new();
        string PathName => Path.Combine(Application.persistentDataPath, FileName);

        public void Load()
        {
            try
            {
                if (!File.Exists(PathName)) { Data = new PlayerSave(); Save(); return; }
                Data = JsonUtility.FromJson<PlayerSave>(File.ReadAllText(PathName)) ?? new PlayerSave();
                Sanitize();
            }
            catch (Exception exception)
            {
                Debug.LogWarning($"Save was invalid and has been safely reset: {exception.Message}");
                Data = new PlayerSave();
                Save();
            }
        }

        public void Save()
        {
            var temporary = PathName + ".tmp";
            File.WriteAllText(temporary, JsonUtility.ToJson(Data, true));
            if (File.Exists(PathName)) File.Delete(PathName);
            File.Move(temporary, PathName);
        }

        public void ResetAll()
        {
            Data = new PlayerSave();
            Save();
        }

        void Sanitize()
        {
            Data.currentStage = Mathf.Max(1, Data.currentStage);
            Data.coins = Mathf.Max(0, Data.coins);
            Data.dailyDay = Mathf.Clamp(Data.dailyDay, 0, 6);
            Data.quality = Mathf.Clamp(Data.quality, 0, 2);
            Data.unlockedSkins ??= new List<string>();
            if (!Data.unlockedSkins.Contains("classic")) Data.unlockedSkins.Add("classic");
            if (!Data.unlockedSkins.Contains(Data.selectedSkin)) Data.selectedSkin = "classic";
        }
    }
}
