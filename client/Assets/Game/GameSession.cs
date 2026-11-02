using System;
using System.Collections.Generic;
using Shazdeh.Content;
using Shazdeh.Core;

namespace Shazdeh.Game
{
    /// <summary>
    /// One player's runtime state: the save, the economy on top of it, and the chapter content.
    ///
    /// Screens read this and call these methods; they never touch SaveData fields directly and never
    /// decide what a win costs. That is deliberate — the rules live in Shazdeh.Core and are tested
    /// there, this class only sequences them (load the level, gate on lives, write the outcome, save).
    ///
    /// No UnityEngine types: it is a plain object so a test could drive it one day, and so the
    /// screens stay dumb views.
    /// </summary>
    public sealed class GameSession
    {
        public const string DefaultChapter = "ch01";

        readonly ISaveStore _store;

        public GameSession(IClock clock, ISaveStore store, SaveData save, ChapterMeta meta, string chapter)
        {
            Clock = clock;
            _store = store;
            Save = save;
            Meta = meta;
            Chapter = string.IsNullOrEmpty(chapter) ? DefaultChapter : chapter;

            Wallet = new Wallet(save);
            Lives = new Lives(save, clock);
            Progression = new Progression(save, clock);
            Boosters = new BoosterBag(save);
        }

        public IClock Clock { get; }

        public SaveData Save { get; }

        public Wallet Wallet { get; }

        public Lives Lives { get; }

        public Progression Progression { get; }

        /// <summary>The five in-level boosters. The board owns the effect; this owns the count.</summary>
        public BoosterBag Boosters { get; }

        public ChapterMeta Meta { get; }

        public string Chapter { get; }

        public int LevelCount => LevelSource.DefaultLevelCount;

        /// <summary>Fires when anything a screen shows has changed. Screens re-render; they never poll.</summary>
        public event Action Changed;

        /// <summary>Loads the save (or starts one), then the chapter content. Never throws.</summary>
        public static GameSession Load(IClock clock, ISaveStore store, string chapter, List<string> errors)
        {
            if (errors == null) errors = new List<string>();

            var save = store != null ? store.Load(errors) : SaveCodec.NewSave(clock);
            if (store == null) errors.Add("no save store: progress will not survive a restart");

            var meta = LevelSource.LoadChapterMeta(chapter, errors);
            if (meta == null)
            {
                errors.Add("chapter meta missing: districts and tasks will be unavailable");
                meta = new ChapterMeta { Chapter = chapter };
            }

            return new GameSession(clock, store, save, meta, chapter);
        }

        /// <summary>Highest level the player may start right now (1 = fresh save).</summary>
        public int CurrentLevel
        {
            get
            {
                int unlocked = Progression.HighestUnlockedLevel;
                if (unlocked < 1) unlocked = 1;
                if (unlocked > LevelCount) unlocked = LevelCount;
                return unlocked;
            }
        }

        public bool IsUnlocked(int level) => Progression.IsUnlocked(level) && level >= 1 && level <= LevelCount;

        public bool IsLastLevel => CurrentLevel >= LevelCount;

        public int ClearedCount
        {
            get
            {
                int cleared = 0;
                for (int i = 0; i < Save.levels.Count; i++)
                    if (Save.levels[i] != null && Save.levels[i].cleared) cleared++;
                return cleared;
            }
        }

        // ---- playing ------------------------------------------------------------------------------

        /// <summary>Why the play button would be disabled, or null when the attempt may start.</summary>
        public string BlockedReason(int level)
        {
            if (!IsUnlocked(level)) return "مرحله هنوز باز نشده است";
            if (Lives.Current <= 0) return "جان ندارید — جان بعدی تا " + PersianTime(Lives.NextRefillInSeconds);
            return null;
        }

        /// <summary>
        /// Builds the run for a level. Returns null and sets <paramref name="error"/> when the attempt
        /// may not start, so a screen can show the reason instead of a dead board.
        /// </summary>
        public LevelRun StartAttempt(int level, out LevelDefinition definition, out string error)
        {
            definition = null;
            error = BlockedReason(level);
            if (error != null) return null;

            var levelErrors = new List<string>();
            definition = LevelSource.LoadLevel(level, Chapter, levelErrors);
            if (definition == null || levelErrors.Count > 0)
            {
                error = "بارگذاری مرحله ناموفق بود";
                for (int i = 0; i < levelErrors.Count; i++) UnityEngine.Debug.LogError("[level] " + levelErrors[i]);
                return null;
            }

            // A seed derived from the save and the level: the same player retrying a level gets the same
            // board, a different player does not, and the replay hash stays meaningful.
            ulong seed = StableSeed(Save.playerId, level, Save.FindLevel(level)?.plays ?? 0);
            return new LevelRun(definition, seed);
        }

        static ulong StableSeed(string playerId, int level, int plays)
        {
            ulong hash = 1469598103934665603UL; // FNV-1a over the player id
            if (!string.IsNullOrEmpty(playerId))
            {
                for (int i = 0; i < playerId.Length; i++)
                {
                    hash ^= playerId[i];
                    hash *= 1099511628211UL;
                }
            }
            hash ^= (ulong)level * 2654435761UL;
            hash *= 1099511628211UL;
            hash ^= (ulong)plays * 40503UL;
            return hash;
        }

        /// <summary>
        /// Writes a finished attempt: a win pays its first-clear reward and unlocks the next level, a
        /// loss costs one life. Either way the save is written before the screen changes.
        /// </summary>
        public bool FinishAttempt(LevelRun run, out RewardBundle reward, out bool firstClear)
        {
            reward = RewardBundle.None;
            firstClear = false;
            if (run == null) return false;

            if (run.Status == LevelStatus.Won)
            {
                firstClear = Progression.RecordLevelResult(run, Wallet, out reward);
            }
            else if (run.Status == LevelStatus.Lost)
            {
                Lives.TrySpend();
                Progression.RecordLevelResult(run, Wallet, out _);
            }
            else
            {
                return false; // still playing: nothing to write
            }

            SaveNow();
            return true;
        }

        // ---- boosters -----------------------------------------------------------------------------

        /// <summary>
        /// Fires a booster on the board, charging the player for it only if the board accepts the move.
        /// The refcount dance is the whole point of this method: a rejected target must not cost a
        /// booster, and a screen must not have to know that.
        /// </summary>
        public bool TryUseBooster(LevelRun run, BoosterKind kind, int x, int y, out MoveResult result)
        {
            result = null;
            if (run == null) return false;
            if (run.Status != LevelStatus.Playing) return false;
            if (!Boosters.TryConsume(kind)) return false;

            result = run.UseBooster(kind, x, y);
            if (result == null || !result.Accepted)
            {
                Boosters.Grant(kind, 1);
                result = null;
                return false;
            }

            // A booster that cleared nothing did nothing. The board takes any in-bounds target, so only
            // this layer can tell a full cell from an empty one. The whirlwind is the exception: changing
            // the board without clearing is exactly its job.
            if (kind != BoosterKind.Whirlwind && !ClearedAnything(result))
            {
                Boosters.Grant(kind, 1);
                run.RevertLastBooster(kind);
                result = null;
                return false;
            }

            SaveNow();
            return true;
        }

        static bool ClearedAnything(MoveResult result)
        {
            if (result == null || result.Events == null) return false;

            var events = result.Events;
            for (int i = 0; i < events.Count; i++)
                if (events[i] is PieceClearedEvent) return true;
            return false;
        }

        public bool BuyBooster(BoosterKind kind, int quantity = 1)
        {
            if (!Boosters.Buy(kind, Wallet, quantity)) return false;
            SaveNow();
            return true;
        }

        // ---- the meta layer -----------------------------------------------------------------------

        public bool IsTaskDone(TaskDefinition task) => Progression.IsTaskComplete(task.Key);

        public long RemainingPotions(DistrictDefinition district)
        {
            long total = 0;
            for (int i = 0; i < district.Tasks.Count; i++)
                if (!Progression.IsTaskComplete(district.Tasks[i].Key)) total += district.Tasks[i].PotionCost;
            return total;
        }

        public bool IsDistrictBuilt(DistrictDefinition district) =>
            district != null && Progression.IsDistrictComplete(district.Costs());

        public bool CanAfford(DistrictDefinition district) => Wallet.CanAffordPotions(RemainingPotions(district));

        public bool BuildTask(DistrictDefinition district, TaskDefinition task)
        {
            if (district == null || task == null) return false;
            if (!Progression.TryCompleteTask(task.Key, task.PotionCost, Wallet)) return false;
            SaveNow();
            return true;
        }

        public bool BuildDistrict(DistrictDefinition district)
        {
            if (district == null) return false;
            if (!Progression.TryCompleteTasks(district.Costs(), Wallet, out _, out _)) return false;
            SaveNow();
            return true;
        }

        public bool OpenChest(DistrictDefinition district)
        {
            if (district == null) return false;
            if (!Progression.TryClaimChest(district.Id, district.Chest, district.Costs(), Wallet)) return false;
            SaveNow();
            return true;
        }

        public bool IsChestOpen(DistrictDefinition district) => Progression.IsChestClaimed(district.Id);

        public bool IsChapterBuilt
        {
            get
            {
                if (Meta == null || Meta.Districts.Count == 0) return false;
                for (int i = 0; i < Meta.Districts.Count; i++)
                    if (!IsDistrictBuilt(Meta.Districts[i])) return false;
                return true;
            }
        }

        // ---- housekeeping -------------------------------------------------------------------------

        /// <summary>Materialises any life that came back and writes it. Cheap; safe to call per frame.</summary>
        public bool RefreshLives()
        {
            int restored = Lives.Refresh();
            if (restored <= 0) return false;
            SaveNow();
            return true;
        }

        public void SaveNow()
        {
            if (_store != null) _store.Save(Save);
            Changed?.Invoke();
        }

        static string PersianTime(int seconds) => Core.Text.PersianText.Time(seconds);
    }
}
