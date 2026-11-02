using System;
using System.Collections.Generic;
using Newtonsoft.Json;
using Shazdeh.Core;

namespace Shazdeh.Content
{
    /// <summary>
    /// Save file ↔ JSON. Two rules: a corrupt file never crashes the game (you get a fresh save plus an
    /// error list), and an older file is migrated forward instead of thrown away.
    /// </summary>
    public static class SaveCodec
    {
        public static SaveData NewSave(IClock clock)
        {
            long now = clock != null ? clock.UtcNowUnix : 0L;
            return new SaveData
            {
                version = SaveData.CurrentVersion,
                playerId = Guid.NewGuid().ToString("N"),
                createdAtUnix = now,
                updatedAtUnix = now,
                lives = Lives.DefaultMax,
                maxLives = Lives.DefaultMax,
                livesUpdatedAtUnix = now,
                levelNumber = 1,
                boosters = StarterBoosters()
            };
        }

        /// <summary>One of each, in enum order: the fresh-save grant, and the v1→v2 migration.</summary>
        static List<int> StarterBoosters()
        {
            var boosters = new List<int>(BoosterCatalog.Slots);
            for (int i = 0; i < BoosterCatalog.Slots; i++) boosters.Add(BoosterCatalog.StartOwned);
            return boosters;
        }

        public static string Encode(SaveData data, bool pretty = true)
        {
            if (data == null) throw new ArgumentNullException("data");
            return JsonConvert.SerializeObject(data, pretty ? Formatting.Indented : Formatting.None);
        }

        /// <summary>
        /// Returns a usable save in every case: the real one, a migrated one, or a new one. Never null.
        /// </summary>
        public static SaveData Decode(string json, IClock clock, List<string> errors)
        {
            if (errors == null) errors = new List<string>();

            if (string.IsNullOrEmpty(json))
            {
                errors.Add("save is empty");
                return NewSave(clock);
            }

            SaveData data;
            try
            {
                data = JsonConvert.DeserializeObject<SaveData>(json);
            }
            catch (JsonException ex)
            {
                errors.Add("corrupt save: " + ex.Message);
                return NewSave(clock);
            }

            if (data == null)
            {
                errors.Add("save deserialized to null");
                return NewSave(clock);
            }

            Migrate(data, clock, errors);
            Sanitize(data, clock);
            return data;
        }

        static void Migrate(SaveData data, IClock clock, List<string> errors)
        {
            if (data.version > SaveData.CurrentVersion)
            {
                // A save from a newer build: keep what we understand rather than wiping it.
                errors.Add("save comes from a newer build (v" + data.version + "), reading it as best we can");
                return;
            }

            // v0 is "whatever the M0 prototype left behind": no version field at all.
            if (data.version < 1)
            {
                data.version = 1;
                errors.Add("migrated save from v0 to v1");
            }

            // v2 added boosters. An older save gets the starter set — the same one a new player gets —
            // rather than five zeros, because a player who has been playing for a month should not have
            // to pay for the ability to try a booster for the first time.
            if (data.version < 2)
            {
                data.version = 2;
                data.boosters = StarterBoosters();
                errors.Add("migrated save from v1 to v2: boosters added");
            }

            data.version = SaveData.CurrentVersion;
        }

        static void Sanitize(SaveData data, IClock clock)
        {
            long now = clock != null ? clock.UtcNowUnix : 0L;

            if (string.IsNullOrEmpty(data.playerId)) data.playerId = Guid.NewGuid().ToString("N");
            if (data.levels == null) data.levels = new List<LevelRecord>();
            if (data.completedTasks == null) data.completedTasks = new List<string>();
            if (data.claimedChests == null) data.claimedChests = new List<string>();
            if (data.boosters == null) data.boosters = new List<int>(BoosterCatalog.Slots);

            while (data.boosters.Count < BoosterCatalog.Slots) data.boosters.Add(BoosterCatalog.StartOwned);

            if (data.coins < 0) data.coins = 0;
            if (data.potions < 0) data.potions = 0;
            if (data.coins > Wallet.MaxBalance) data.coins = Wallet.MaxBalance;
            if (data.potions > Wallet.MaxBalance) data.potions = Wallet.MaxBalance;

            if (data.maxLives < 1) data.maxLives = Lives.DefaultMax;
            if (data.lives < 0) data.lives = 0;
            if (data.lives > data.maxLives) data.lives = data.maxLives;
            if (data.livesUpdatedAtUnix <= 0) data.livesUpdatedAtUnix = now;

            if (data.levelNumber < 1) data.levelNumber = 1;
            if (data.createdAtUnix <= 0) data.createdAtUnix = now;
            if (data.updatedAtUnix <= 0) data.updatedAtUnix = now;

            for (int i = data.levels.Count - 1; i >= 0; i--)
                if (data.levels[i] == null) data.levels.RemoveAt(i);
        }
    }
}
