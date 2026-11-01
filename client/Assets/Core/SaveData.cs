using System;
using System.Collections.Generic;

namespace Shazdeh.Core
{
    /// <summary>
    /// The whole local save. Plain fields only: no behaviour lives here, so the JSON stays readable,
    /// diffable and migratable. Anything that changes it does so through Wallet / Lives / Progression.
    /// </summary>
    [Serializable]
    public sealed class SaveData
    {
        /// <summary>Bumped whenever the shape changes; SaveCodec migrates older files.</summary>
        public const int CurrentVersion = 1;

        public int version = CurrentVersion;
        public string playerId = "";
        public long createdAtUnix;
        public long updatedAtUnix;

        public long coins;
        public long potions;

        public int lives = 5;
        public int maxLives = 5;
        public long livesUpdatedAtUnix;

        /// <summary>Highest level the player may start. 1 = fresh save.</summary>
        public int levelNumber = 1;

        public List<LevelRecord> levels = new List<LevelRecord>();
        public List<string> completedTasks = new List<string>();
        public List<string> claimedChests = new List<string>();

        public bool musicOn = true;
        public bool sfxOn = true;
        public bool hapticsOn = true;
        public bool pushOn = true;

        public LevelRecord FindLevel(int number)
        {
            for (int i = 0; i < levels.Count; i++)
                if (levels[i] != null && levels[i].number == number) return levels[i];
            return null;
        }

        public LevelRecord GetOrCreateLevel(int number)
        {
            var record = FindLevel(number);
            if (record != null) return record;

            record = new LevelRecord { number = number };
            levels.Add(record);
            return record;
        }

        public bool IsTaskComplete(string key) => completedTasks.Contains(key);

        public bool IsChestClaimed(string key) => claimedChests.Contains(key);
    }

    [Serializable]
    public sealed class LevelRecord
    {
        public int number;
        public int plays;
        public int bestMovesLeft;
        public bool cleared;
        public long firstClearedAtUnix;
        public string lastReplayHash = "";

        /// <summary>
        /// Stars for this level, derived rather than stored: the same rule the server applies to the
        /// replay, and the reason adding stars to the game did not need a save migration.
        /// </summary>
        public int Stars(int moveLimit) => StarRating.FromRecord(this, moveLimit);
    }

    /// <summary>What a chest or a level pays out. Small struct so it cannot be half-applied.</summary>
    public struct RewardBundle
    {
        public long Coins;
        public long Potions;

        public RewardBundle(long coins, long potions)
        {
            Coins = coins;
            Potions = potions;
        }

        public static RewardBundle None => new RewardBundle(0, 0);

        public bool IsEmpty => Coins == 0 && Potions == 0;
    }
}
