using System.Collections.Generic;
using System.IO;
using NUnit.Framework;
using Shazdeh.Content;
using Shazdeh.Core;
using Shazdeh.Game;

namespace Shazdeh.Core.Tests
{
    public sealed class SaveCodecTests
    {
        static List<string> Errors() => new List<string>();

        [Test]
        public void ANewSaveIsValidAndStartsAtLevelOne()
        {
            var clock = new ManualClock();
            var save = SaveCodec.NewSave(clock);

            Assert.AreEqual(SaveData.CurrentVersion, save.version);
            Assert.AreEqual(1, save.levelNumber);
            Assert.AreEqual(Lives.DefaultMax, save.lives);
            Assert.AreEqual(Lives.DefaultMax, save.maxLives);
            Assert.AreEqual(clock.UtcNowUnix, save.createdAtUnix);
            Assert.IsFalse(string.IsNullOrEmpty(save.playerId));
            Assert.AreEqual(0, save.coins);
            Assert.AreEqual(0, save.potions);
        }

        [Test]
        public void RoundTripKeepsEverythingThePlayerEarned()
        {
            var clock = new ManualClock();
            var save = SaveCodec.NewSave(clock);
            save.coins = 1234;
            save.potions = 56;
            save.levelNumber = 7;
            save.lives = 2;
            save.livesUpdatedAtUnix = clock.UtcNowUnix - 120;
            save.musicOn = false;
            save.completedTasks.Add("ch01-d1-t1");
            save.claimedChests.Add("ch01-d1");

            var record = save.GetOrCreateLevel(3);
            record.plays = 4;
            record.cleared = true;
            record.bestMovesLeft = 9;
            record.firstClearedAtUnix = clock.UtcNowUnix;
            record.lastReplayHash = "c0d2f1a263e84ebf";

            var errors = Errors();
            var loaded = SaveCodec.Decode(SaveCodec.Encode(save), clock, errors);

            Assert.AreEqual(0, errors.Count, string.Join("; ", errors.ToArray()));
            Assert.AreEqual(1234, loaded.coins);
            Assert.AreEqual(56, loaded.potions);
            Assert.AreEqual(7, loaded.levelNumber);
            Assert.AreEqual(2, loaded.lives);
            Assert.IsFalse(loaded.musicOn);
            Assert.IsTrue(loaded.IsTaskComplete("ch01-d1-t1"));
            Assert.IsTrue(loaded.IsChestClaimed("ch01-d1"));

            var loadedRecord = loaded.FindLevel(3);
            Assert.IsNotNull(loadedRecord);
            Assert.AreEqual(4, loadedRecord.plays);
            Assert.IsTrue(loadedRecord.cleared);
            Assert.AreEqual(9, loadedRecord.bestMovesLeft);
            Assert.AreEqual("c0d2f1a263e84ebf", loadedRecord.lastReplayHash);
        }

        [Test]
        public void ACorruptFileBecomesAFreshSaveInsteadOfACrash()
        {
            var clock = new ManualClock();
            var errors = Errors();

            var save = SaveCodec.Decode("{ this is not a save", clock, errors);

            Assert.IsNotNull(save);
            Assert.AreEqual(1, save.levelNumber);
            Assert.AreEqual(1, errors.Count);
            StringAssert.Contains("corrupt save", errors[0]);
        }

        [Test]
        public void AV0FileIsMigratedNotDiscarded()
        {
            var clock = new ManualClock();
            var errors = Errors();

            var save = SaveCodec.Decode("{\"version\":0,\"coins\":40,\"potions\":90}", clock, errors);

            Assert.AreEqual(SaveData.CurrentVersion, save.version);
            Assert.AreEqual(40, save.coins);
            Assert.AreEqual(90, save.potions);
            StringAssert.Contains("migrated", string.Join("; ", errors.ToArray()));
        }

        [Test]
        public void AFileFromANewerBuildKeepsItsData()
        {
            var clock = new ManualClock();
            var errors = Errors();

            var save = SaveCodec.Decode("{\"version\":99,\"coins\":10,\"potions\":77,\"levelNumber\":12}", clock, errors);

            Assert.AreEqual(99, save.version, "we do not downgrade a newer save on disk");
            Assert.AreEqual(77, save.potions);
            Assert.AreEqual(12, save.levelNumber);
            StringAssert.Contains("newer build", string.Join("; ", errors.ToArray()));
        }

        [Test]
        public void ImpossibleNumbersAreClampedOnLoad()
        {
            var clock = new ManualClock();
            var errors = Errors();

            var save = SaveCodec.Decode(
                "{\"version\":1,\"coins\":-5,\"potions\":-1,\"lives\":-3,\"maxLives\":0,\"levelNumber\":-4," +
                "\"livesUpdatedAtUnix\":0,\"levels\":null,\"completedTasks\":null,\"claimedChests\":null}",
                clock, errors);

            Assert.AreEqual(0, save.coins);
            Assert.AreEqual(0, save.potions);
            Assert.AreEqual(0, save.lives);
            Assert.AreEqual(Lives.DefaultMax, save.maxLives);
            Assert.AreEqual(1, save.levelNumber);
            Assert.AreEqual(clock.UtcNowUnix, save.livesUpdatedAtUnix);
            Assert.IsNotNull(save.levels);
            Assert.IsNotNull(save.completedTasks);
            Assert.IsNotNull(save.claimedChests);
        }

        [Test]
        public void ABalanceOverTheCeilingIsPulledBackToIt()
        {
            var clock = new ManualClock();
            var save = SaveCodec.Decode(
                "{\"version\":1,\"coins\":9999999999999}", clock, Errors());

            Assert.AreEqual(Wallet.MaxBalance, save.coins);
        }

        [Test]
        public void MissingListsInAnOldFileAreRepaired()
        {
            var clock = new ManualClock();
            var save = SaveCodec.Decode("{\"version\":1,\"potions\":5}", clock, Errors());

            Assert.AreEqual(5, save.potions);
            Assert.AreEqual(Lives.DefaultMax, save.lives);
            Assert.AreEqual(1, save.levelNumber);
            Assert.AreEqual(0, save.levels.Count);
        }
    }

    public sealed class FileSaveStoreTests
    {
        string _dir;
        ManualClock _clock;

        [SetUp]
        public void SetUp()
        {
            _dir = Path.Combine(Path.GetTempPath(), "shazdeh-tests-" + System.Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_dir);
            _clock = new ManualClock();
        }

        [TearDown]
        public void TearDown()
        {
            if (Directory.Exists(_dir)) Directory.Delete(_dir, true);
        }

        FileSaveStore Store() => new FileSaveStore(_clock, _dir);

        [Test]
        public void AnEmptyFolderStartsANewSave()
        {
            var errors = new List<string>();
            var save = Store().Load(errors);

            Assert.IsNotNull(save);
            Assert.AreEqual(1, save.levelNumber);
            Assert.AreEqual(1, errors.Count);
            StringAssert.Contains("no save found", errors[0]);
        }

        [Test]
        public void SaveThenLoadKeepsTheNumbers()
        {
            var store = Store();
            var save = SaveCodec.NewSave(_clock);
            save.potions = 42;
            save.coins = 7;
            save.levelNumber = 4;
            store.Save(save);

            var errors = new List<string>();
            var loaded = store.Load(errors);

            Assert.AreEqual(0, errors.Count, string.Join("; ", errors.ToArray()));
            Assert.AreEqual(42, loaded.potions);
            Assert.AreEqual(7, loaded.coins);
            Assert.AreEqual(4, loaded.levelNumber);
        }

        [Test]
        public void NoTemporaryFileIsLeftBehind()
        {
            var store = Store();
            store.Save(SaveCodec.NewSave(_clock));

            var files = Directory.GetFiles(_dir);
            Assert.AreEqual(1, files.Length);
            Assert.AreEqual("shazdeh-save.json", Path.GetFileName(files[0]));
        }

        [Test]
        public void TheSecondSaveKeepsTheFirstAsBackup()
        {
            var store = Store();
            var save = SaveCodec.NewSave(_clock);
            save.potions = 10;
            store.Save(save);

            save.potions = 20;
            store.Save(save);

            Assert.IsTrue(File.Exists(Path.Combine(_dir, "shazdeh-save.json.bak")));
            Assert.AreEqual(20, store.Load(new List<string>()).potions);
        }

        [Test]
        public void ACorruptFileFallsBackToTheBackup()
        {
            var store = Store();
            var save = SaveCodec.NewSave(_clock);
            save.potions = 10;
            store.Save(save);
            save.potions = 20;
            store.Save(save); // backup now holds potions = 10

            File.WriteAllText(Path.Combine(_dir, "shazdeh-save.json"), "}}} broken");

            var errors = new List<string>();
            var loaded = store.Load(errors);

            Assert.AreEqual(10, loaded.potions, "the backup is the last known good state");
            StringAssert.Contains("recovered from backup save", string.Join("; ", errors.ToArray()));
        }

        [Test]
        public void BothFilesCorruptStillGivesAPlayableSave()
        {
            var store = Store();
            store.Save(SaveCodec.NewSave(_clock));
            File.WriteAllText(Path.Combine(_dir, "shazdeh-save.json"), "nope");
            File.WriteAllText(Path.Combine(_dir, "shazdeh-save.json.bak"), "also nope");

            var errors = new List<string>();
            var loaded = store.Load(errors);

            Assert.IsNotNull(loaded);
            Assert.AreEqual(1, loaded.levelNumber);
            Assert.GreaterOrEqual(errors.Count, 2, "both failures are reported");
        }

        [Test]
        public void TheFileOnDiskIsReadableText()
        {
            var store = Store();
            var save = SaveCodec.NewSave(_clock);
            save.potions = 3;
            store.Save(save);

            string text = File.ReadAllText(Path.Combine(_dir, "shazdeh-save.json"));
            StringAssert.Contains("\"potions\": 3", text);
            StringAssert.Contains("playerId", text);
        }
    }

    public sealed class DistrictParserTests
    {
        [Test]
        public void TheShippedChapterParsesWithoutErrors()
        {
            var errors = new List<string>();
            var meta = LevelSource.LoadChapterMeta("ch01", errors);

            Assert.IsNotNull(meta, string.Join("; ", errors.ToArray()));
            Assert.AreEqual(0, errors.Count, string.Join("; ", errors.ToArray()));
            Assert.AreEqual("ch01", meta.Chapter);
            Assert.AreEqual(3, meta.Districts.Count);
        }

        [Test]
        public void EveryDistrictHasTasksAChestAndTheExpectedPrice()
        {
            var meta = LevelSource.LoadChapterMeta("ch01", new List<string>());
            Assert.IsNotNull(meta);

            long[] expectedTotals = { 130, 215, 340 };
            for (int d = 0; d < meta.Districts.Count; d++)
            {
                var district = meta.Districts[d];
                Assert.IsFalse(string.IsNullOrEmpty(district.Id), "district " + d + " needs an id");
                Assert.IsFalse(string.IsNullOrEmpty(district.Title), "district " + d + " needs a Persian title");
                Assert.AreEqual(4, district.Tasks.Count, district.Id);
                Assert.AreEqual(expectedTotals[d], district.TotalPotionCost(), district.Id);
                Assert.IsFalse(district.Chest.IsEmpty, district.Id + " needs a chest");

                for (int t = 0; t < district.Tasks.Count; t++)
                {
                    var task = district.Tasks[t];
                    Assert.IsTrue(task.Key.StartsWith(district.Id + "-t"), "task keys are namespaced by district");
                    Assert.IsFalse(string.IsNullOrEmpty(task.BuildAsset), task.Key + " needs a build asset");
                }
            }
        }

        [Test]
        public void TaskKeysAreUniqueAcrossTheChapter()
        {
            var meta = LevelSource.LoadChapterMeta("ch01", new List<string>());
            var seen = new HashSet<string>();
            for (int d = 0; d < meta.Districts.Count; d++)
            for (int t = 0; t < meta.Districts[d].Tasks.Count; t++)
                Assert.IsTrue(seen.Add(meta.Districts[d].Tasks[t].Key), "duplicate task key " + meta.Districts[d].Tasks[t].Key);
        }

        [Test]
        public void BrokenJsonIsReportedNotThrown()
        {
            var errors = new List<string>();
            var meta = DistrictParser.Parse("{\"districts\": [", errors);

            Assert.IsNull(meta);
            Assert.AreEqual(1, errors.Count);
            StringAssert.Contains("invalid chapter meta json", errors[0]);
        }

        [Test]
        public void AMissingDistrictsArrayIsReported()
        {
            var errors = new List<string>();
            var meta = DistrictParser.Parse("{\"chapter\":\"ch01\"}", errors);

            Assert.IsNull(meta);
            Assert.AreEqual(1, errors.Count);
            StringAssert.Contains("no districts", errors[0]);
        }

        [Test]
        public void TheValidatorCatchesCheapDuplicateAndEmptyContent()
        {
            const string json = @"{
              ""chapter"": ""ch01"",
              ""districts"": [
                { ""id"": ""d1"", ""title"": ""x"", ""tasks"": [
                    { ""key"": ""d1-t1"", ""build_asset"": ""a"", ""potion_cost"": 0 },
                    { ""key"": ""d1-t1"", ""build_asset"": ""b"", ""potion_cost"": 20 } ],
                  ""chest"": { ""coins"": 0, ""potions"": 0 } },
                { ""id"": ""d1"", ""title"": ""y"", ""tasks"": [], ""chest"": { ""coins"": -5, ""potions"": 0 } } ] }";

            var errors = new List<string>();
            var meta = DistrictParser.Parse(json, errors);
            Assert.IsNotNull(meta);
            errors.AddRange(DistrictParser.Validate(meta));

            var joined = string.Join("; ", errors.ToArray());
            StringAssert.Contains("must cost more than 0", joined);
            StringAssert.Contains("duplicate task key", joined);
            StringAssert.Contains("duplicate district id", joined);
            StringAssert.Contains("no tasks", joined);
            StringAssert.Contains("negative chest reward", joined);
        }

        [Test]
        public void ATaskOverFiveHundredPotionsIsRejected()
        {
            const string json = @"{
              ""chapter"": ""ch01"",
              ""districts"": [
                { ""id"": ""d1"", ""title"": ""x"", ""tasks"": [
                    { ""key"": ""d1-t1"", ""build_asset"": ""a"", ""potion_cost"": 900 } ],
                  ""chest"": { ""coins"": 10, ""potions"": 10 } } ] }";

            var meta = DistrictParser.Parse(json, new List<string>());
            var errors = DistrictParser.Validate(meta);

            StringAssert.Contains("costs more than a district should", string.Join("; ", errors.ToArray()));
        }
    }
}
