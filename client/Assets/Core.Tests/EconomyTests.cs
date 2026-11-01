using System.Collections.Generic;
using NUnit.Framework;

namespace Shazdeh.Core.Tests
{
    public sealed class WalletTests
    {
        static SaveData Save()
        {
            var data = new SaveData { potions = 100, coins = 50 };
            return data;
        }

        [Test]
        public void SpendingMoreThanYouHaveIsRefusedAndChangesNothing()
        {
            var data = Save();
            var wallet = new Wallet(data);

            Assert.IsFalse(wallet.TrySpendPotions(101));
            Assert.AreEqual(100, wallet.Potions);
            Assert.IsFalse(wallet.TrySpendCoins(51));
            Assert.AreEqual(50, wallet.Coins);
        }

        [Test]
        public void SpendingExactlyTheBalanceWorks()
        {
            var wallet = new Wallet(Save());

            Assert.IsTrue(wallet.TrySpendPotions(100));
            Assert.AreEqual(0, wallet.Potions);
            Assert.IsTrue(wallet.CanAffordPotions(0));
        }

        [Test]
        public void NegativeAmountsAreRefused()
        {
            var wallet = new Wallet(Save());

            Assert.IsFalse(wallet.TrySpendPotions(-5));
            Assert.IsFalse(wallet.TrySpendCoins(-1));
            Assert.AreEqual(100, wallet.Potions);
            Assert.AreEqual(50, wallet.Coins);
        }

        [Test]
        public void GrantingClampsAtTheCeiling()
        {
            var data = Save();
            data.potions = Wallet.MaxBalance - 1;
            var wallet = new Wallet(data);

            wallet.Grant(0, 1000);

            Assert.AreEqual(Wallet.MaxBalance, wallet.Potions);
        }

        [Test]
        public void GrantingPositiveAmountsAddsUp()
        {
            var wallet = new Wallet(Save());
            wallet.Grant(new RewardBundle(25, 75));

            Assert.AreEqual(75, wallet.Coins);
            Assert.AreEqual(175, wallet.Potions);
        }

        [Test]
        public void GrantIgnoresNonPositiveValues()
        {
            var wallet = new Wallet(Save());
            wallet.Grant(-100, -100);

            Assert.AreEqual(100, wallet.Potions);
            Assert.AreEqual(50, wallet.Coins);
        }
    }

    public sealed class LivesTests
    {
        static SaveData FreshSave(ManualClock clock)
        {
            return new SaveData
            {
                lives = Lives.DefaultMax,
                maxLives = Lives.DefaultMax,
                livesUpdatedAtUnix = clock.UtcNowUnix
            };
        }

        [Test]
        public void AFullTankReportsFull()
        {
            var clock = new ManualClock();
            var lives = new Lives(FreshSave(clock), clock);

            Assert.AreEqual(5, lives.Current);
            Assert.IsTrue(lives.IsFull);
            Assert.AreEqual(0, lives.NextRefillInSeconds);
        }

        [Test]
        public void SpendingALifeStartsTheCountdown()
        {
            var clock = new ManualClock();
            var lives = new Lives(FreshSave(clock), clock);

            Assert.IsTrue(lives.TrySpend());
            Assert.AreEqual(4, lives.Current);
            Assert.IsFalse(lives.IsFull);
            Assert.AreEqual(1800, lives.NextRefillInSeconds);
        }

        [Test]
        public void OneLifeComesBackAfterThirtyMinutes()
        {
            var clock = new ManualClock();
            var lives = new Lives(FreshSave(clock), clock);
            lives.TrySpend();

            clock.Advance(1799);
            Assert.AreEqual(4, lives.Current);

            clock.Advance(1);
            Assert.AreEqual(5, lives.Current);
            Assert.IsTrue(lives.IsFull);
        }

        [Test]
        public void OfflineForTwoDaysRestoresEverythingButNotMore()
        {
            var clock = new ManualClock();
            var lives = new Lives(FreshSave(clock), clock);
            lives.TrySpend();
            lives.TrySpend();

            clock.Advance(2 * 24 * 60 * 60);

            Assert.AreEqual(5, lives.Current);
        }

        [Test]
        public void PartialRefillKeepsTheRemainder()
        {
            var clock = new ManualClock();
            var lives = new Lives(FreshSave(clock), clock);
            for (int i = 0; i < 5; i++) lives.TrySpend();
            Assert.AreEqual(0, lives.Current);

            clock.Advance(75 * 60); // two refills and a bit

            Assert.AreEqual(2, lives.Current);
            Assert.AreEqual(900, lives.NextRefillInSeconds);
        }

        [Test]
        public void SpendingWithNoLivesIsRefused()
        {
            var clock = new ManualClock();
            var data = FreshSave(clock);
            var lives = new Lives(data, clock);
            for (int i = 0; i < 5; i++) lives.TrySpend();

            Assert.IsFalse(lives.TrySpend());
            Assert.AreEqual(0, lives.Current);
        }

        [Test]
        public void GrantNeverExceedsTheCap()
        {
            var clock = new ManualClock();
            var lives = new Lives(FreshSave(clock), clock);
            lives.TrySpend();

            lives.Grant(10);

            Assert.AreEqual(5, lives.Current);
        }

        [Test]
        public void ClocksGoingBackwardsDoNotDuplicateLives()
        {
            var clock = new ManualClock();
            var lives = new Lives(FreshSave(clock), clock);
            lives.TrySpend();

            clock.Advance(-5000);

            Assert.AreEqual(4, lives.Current);
        }
    }

    public sealed class ProgressionTests
    {
        static LevelDefinition Level(int number, long coins, long potions, int goalTarget)
        {
            var level = new LevelDefinition
            {
                Id = "test-" + number, Number = number, Width = 9, Height = 9, MoveLimit = 40,
                Type = "normal", RewardCoins = coins, RewardPotions = potions
            };
            level.Pieces.Add(PieceKind.Firouzeh);
            level.Pieces.Add(PieceKind.Lajvard);
            level.Pieces.Add(PieceKind.Aqiq);
            level.Pieces.Add(PieceKind.Zomorrod);
            level.Goals.Add(new GoalDefinition(GoalKind.ClearPieces, PieceKind.Aqiq, goalTarget));
            return level;
        }

        static LevelRun WonRun(LevelDefinition definition, ulong seed)
        {
            // A goal of 1 piece is met by the first legal swap in almost every case; loop defensively.
            var run = new LevelRun(definition, seed);
            for (int i = 0; i < 200 && run.Status == LevelStatus.Playing; i++)
            {
                int x1, y1, x2, y2;
                if (!MoveResolverTests.TryFindSwap(run.Board, out x1, out y1, out x2, out y2)) break;
                run.TrySwap(x1, y1, x2, y2);
            }
            return run;
        }

        [Test]
        public void FirstClearPaysOnceAndUnlocksTheNextLevel()
        {
            var clock = new ManualClock();
            var save = new SaveData { livesUpdatedAtUnix = clock.UtcNowUnix };
            var wallet = new Wallet(save);
            var progression = new Progression(save, clock);

            var run = WonRun(Level(1, 20, 12, 1), 4321);
            Assert.AreEqual(LevelStatus.Won, run.Status, "the fixture run must actually win");

            RewardBundle reward;
            Assert.IsTrue(progression.RecordLevelResult(run, wallet, out reward));
            Assert.AreEqual(12, reward.Potions);
            Assert.AreEqual(20, reward.Coins);
            Assert.AreEqual(2, progression.HighestUnlockedLevel);
            Assert.AreEqual(1, save.FindLevel(1).plays);

            var second = WonRun(Level(1, 20, 12, 1), 4321);
            Assert.IsFalse(progression.RecordLevelResult(second, wallet, out reward));
            Assert.IsTrue(reward.IsEmpty, "a replay must not pay again");
            Assert.AreEqual(12, wallet.Potions);
            Assert.AreEqual(2, save.FindLevel(1).plays);
        }

        [Test]
        public void ALostRunPaysNothingAndUnlocksNothing()
        {
            var clock = new ManualClock();
            var save = new SaveData { livesUpdatedAtUnix = clock.UtcNowUnix };
            var wallet = new Wallet(save);
            var progression = new Progression(save, clock);

            var definition = Level(1, 20, 12, 200);
            definition.MoveLimit = 5;
            var run = new LevelRun(definition, 99);
            for (int i = 0; i < 20 && run.Status == LevelStatus.Playing; i++)
            {
                int x1, y1, x2, y2;
                if (!MoveResolverTests.TryFindSwap(run.Board, out x1, out y1, out x2, out y2)) break;
                run.TrySwap(x1, y1, x2, y2);
            }

            RewardBundle reward;
            Assert.IsFalse(progression.RecordLevelResult(run, wallet, out reward));
            Assert.AreEqual(0, wallet.Potions);
            Assert.AreEqual(1, progression.HighestUnlockedLevel);
            Assert.AreEqual(1, save.FindLevel(1).plays);
        }

        [Test]
        public void TaskIsChargedOnceAndOnlyOnce()
        {
            var clock = new ManualClock();
            var save = new SaveData { potions = 100, livesUpdatedAtUnix = clock.UtcNowUnix };
            var wallet = new Wallet(save);
            var progression = new Progression(save, clock);

            Assert.IsTrue(progression.TryCompleteTask("d1-t1", 30, wallet));
            Assert.AreEqual(70, wallet.Potions);
            Assert.IsTrue(progression.IsTaskComplete("d1-t1"));

            Assert.IsFalse(progression.TryCompleteTask("d1-t1", 30, wallet));
            Assert.AreEqual(70, wallet.Potions, "a second tap must not charge again");
        }

        [Test]
        public void AnUnaffordableTaskChangesNothing()
        {
            var clock = new ManualClock();
            var save = new SaveData { potions = 10, livesUpdatedAtUnix = clock.UtcNowUnix };
            var wallet = new Wallet(save);
            var progression = new Progression(save, clock);

            Assert.IsFalse(progression.TryCompleteTask("d1-t1", 30, wallet));
            Assert.AreEqual(10, wallet.Potions);
            Assert.IsFalse(progression.IsTaskComplete("d1-t1"));
        }

        [Test]
        public void DoItBuildsEverythingOrNothing()
        {
            var clock = new ManualClock();
            var save = new SaveData { potions = 100, livesUpdatedAtUnix = clock.UtcNowUnix };
            var wallet = new Wallet(save);
            var progression = new Progression(save, clock);

            var tasks = new List<TaskCost>
            {
                new TaskCost("a", 30), new TaskCost("b", 30), new TaskCost("c", 30)
            };

            int completed;
            long spent;

            Assert.IsFalse(progression.TryCompleteTasks(tasks, wallet, out completed, out spent),
                "70 potions cannot buy 90 worth of tasks");
            Assert.AreEqual(100, wallet.Potions, "a failed bulk build must not partially charge");

            save.potions = 200;
            Assert.IsTrue(progression.TryCompleteTasks(tasks, wallet, out completed, out spent));
            Assert.AreEqual(3, completed);
            Assert.AreEqual(90, spent);
            Assert.AreEqual(110, wallet.Potions);
            Assert.IsTrue(progression.IsDistrictComplete(tasks));
        }

        [Test]
        public void ChestNeedsEveryTaskAndPaysOnce()
        {
            var clock = new ManualClock();
            var save = new SaveData { potions = 500, livesUpdatedAtUnix = clock.UtcNowUnix };
            var wallet = new Wallet(save);
            var progression = new Progression(save, clock);

            var tasks = new List<TaskCost> { new TaskCost("a", 10), new TaskCost("b", 10) };
            progression.TryCompleteTask("a", 10, wallet);

            Assert.IsFalse(progression.IsDistrictComplete(tasks));
            Assert.IsFalse(progression.TryClaimChest("d1", new RewardBundle(100, 20), tasks, wallet),
                "a half-built district has no chest yet");

            progression.TryCompleteTask("b", 10, wallet);
            Assert.IsTrue(progression.IsDistrictComplete(tasks));
            Assert.IsTrue(progression.TryClaimChest("d1", new RewardBundle(100, 20), tasks, wallet));

            long coins = wallet.Coins;
            Assert.IsFalse(progression.TryClaimChest("d1", new RewardBundle(100, 20), tasks, wallet));
            Assert.AreEqual(coins, wallet.Coins, "a chest pays once");
        }

        [Test]
        public void TheReplayHashIsStoredOnTheLevelRecord()
        {
            var clock = new ManualClock();
            var save = new SaveData { livesUpdatedAtUnix = clock.UtcNowUnix };
            var progression = new Progression(save, clock);
            var run = WonRun(Level(3, 5, 5, 1), 555);

            RewardBundle ignored;
            progression.RecordLevelResult(run, new Wallet(save), out ignored);

            var record = save.FindLevel(3);
            Assert.IsNotNull(record);
            Assert.AreEqual(run.StateHash().ToString("x16"), record.lastReplayHash);
        }
    }
}
