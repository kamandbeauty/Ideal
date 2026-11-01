using System.Collections.Generic;

namespace Shazdeh.Core
{
    /// <summary>
    /// What "progress" means offline: which levels are unlocked, which tasks are built, which chests
    /// were opened, and what the player earned. Every mutation is idempotent where it matters —
    /// a level pays its first-clear reward once, a task is charged once, a chest is claimed once.
    /// </summary>
    public sealed class Progression
    {
        readonly SaveData _data;
        readonly IClock _clock;

        public Progression(SaveData data, IClock clock)
        {
            _data = data;
            _clock = clock;
            if (_data.levelNumber < 1) _data.levelNumber = 1;
        }

        public int HighestUnlockedLevel => _data.levelNumber;

        public bool IsUnlocked(int levelNumber) => levelNumber >= 1 && levelNumber <= _data.levelNumber;

        /// <summary>
        /// Writes the outcome of a finished run. Returns true when this was the first clear of the
        /// level — only then does the level pay potions and unlock the next one.
        /// </summary>
        public bool RecordLevelResult(LevelRun run, Wallet wallet, out RewardBundle reward)
        {
            reward = RewardBundle.None;
            if (run == null || run.Level == null) return false;

            var record = _data.GetOrCreateLevel(run.Level.Number);
            record.plays++;
            record.lastReplayHash = run.StateHash().ToString("x16");

            if (run.Status != LevelStatus.Won)
            {
                _data.updatedAtUnix = _clock.UtcNowUnix;
                return false;
            }

            int movesLeft = run.MovesLeft;
            if (movesLeft > record.bestMovesLeft) record.bestMovesLeft = movesLeft;

            bool firstClear = !record.cleared;
            if (firstClear)
            {
                record.cleared = true;
                record.firstClearedAtUnix = _clock.UtcNowUnix;

                reward = new RewardBundle(run.Level.RewardCoins, run.Level.RewardPotions);
                if (wallet != null) wallet.Grant(reward);

                if (run.Level.Number >= _data.levelNumber)
                    _data.levelNumber = run.Level.Number + 1;
            }

            _data.updatedAtUnix = _clock.UtcNowUnix;
            return firstClear;
        }

        public bool IsTaskComplete(string key) => _data.IsTaskComplete(key);

        /// <summary>Pays for one task. No double charge, no partial builds.</summary>
        public bool TryCompleteTask(string key, long potionCost, Wallet wallet)
        {
            if (string.IsNullOrEmpty(key)) return false;
            if (_data.IsTaskComplete(key)) return false;
            if (wallet == null) return false;
            if (!wallet.TrySpendPotions(potionCost)) return false;

            _data.completedTasks.Add(key);
            _data.updatedAtUnix = _clock.UtcNowUnix;
            return true;
        }

        /// <summary>The "Do it" button: build every remaining task in a district, or none of them.</summary>
        public bool TryCompleteTasks(IList<TaskCost> tasks, Wallet wallet, out int completed, out long spent)
        {
            completed = 0;
            spent = 0;
            if (tasks == null || wallet == null) return false;

            long total = 0;
            for (int i = 0; i < tasks.Count; i++)
            {
                if (tasks[i] == null) continue;
                if (_data.IsTaskComplete(tasks[i].Key)) continue;
                total += tasks[i].PotionCost;
            }

            if (total <= 0) return false;
            if (!wallet.TrySpendPotions(total)) return false;

            for (int i = 0; i < tasks.Count; i++)
            {
                if (tasks[i] == null) continue;
                if (_data.IsTaskComplete(tasks[i].Key)) continue;
                _data.completedTasks.Add(tasks[i].Key);
                completed++;
            }

            spent = total;
            _data.updatedAtUnix = _clock.UtcNowUnix;
            return completed > 0;
        }

        public bool IsChestClaimed(string districtId) => _data.IsChestClaimed(districtId);

        /// <summary>
        /// Opens the district chest. The district must be fully built first: chests are earned by
        /// finishing tasks, never bought, so the rule lives here and not only in the UI.
        /// </summary>
        public bool TryClaimChest(string districtId, RewardBundle reward, IList<TaskCost> tasks, Wallet wallet)
        {
            if (string.IsNullOrEmpty(districtId)) return false;
            if (_data.IsChestClaimed(districtId)) return false;
            if (!IsDistrictComplete(tasks)) return false;
            if (reward.IsEmpty) return false;
            if (wallet == null) return false;

            _data.claimedChests.Add(districtId);
            wallet.Grant(reward);
            _data.updatedAtUnix = _clock.UtcNowUnix;
            return true;
        }

        /// <summary>True when every task of the district is built. Chests are earned, never bought.</summary>
        public bool IsDistrictComplete(IList<TaskCost> tasks)
        {
            if (tasks == null || tasks.Count == 0) return false;
            for (int i = 0; i < tasks.Count; i++)
            {
                if (tasks[i] == null) continue;
                if (!_data.IsTaskComplete(tasks[i].Key)) return false;
            }
            return true;
        }
    }

    /// <summary>The only thing progression needs to know about a task: its key and its price.</summary>
    public sealed class TaskCost
    {
        public string Key;
        public long PotionCost;

        public TaskCost(string key, long potionCost)
        {
            Key = key;
            PotionCost = potionCost;
        }
    }
}
