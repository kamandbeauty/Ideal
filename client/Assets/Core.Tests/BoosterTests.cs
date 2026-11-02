using System.Collections.Generic;
using NUnit.Framework;
using Shazdeh.Content;
using Shazdeh.Core;

namespace Shazdeh.Core.Tests
{
    /// <summary>
    /// The booster bag: five counts, two rules. Never below zero, never above the ceiling — and the coins
    /// for a purchase leave the wallet only when the boosters arrive.
    /// </summary>
    public sealed class BoosterTests
    {
        static SaveData Fresh() => SaveCodec.NewSave(new ManualClock());

        static void EachKind(System.Action<BoosterKind> action)
        {
            for (int i = 0; i < BoosterCatalog.Slots; i++) action((BoosterKind)i);
        }

        [Test]
        public void AFreshSaveStartsWithOneOfEach()
        {
            var bag = new BoosterBag(Fresh());

            EachKind(kind => Assert.AreEqual(BoosterCatalog.StartOwned, bag.Count(kind), kind.ToString()));

            Assert.AreEqual(BoosterCatalog.Slots * BoosterCatalog.StartOwned, bag.Total);
        }

        [Test]
        public void UsingABoosterTakesExactlyOneAndStopsAtZero()
        {
            var bag = new BoosterBag(Fresh());

            Assert.IsTrue(bag.TryConsume(BoosterKind.Mallet));
            Assert.AreEqual(BoosterCatalog.StartOwned - 1, bag.Count(BoosterKind.Mallet));

            Assert.IsFalse(bag.TryConsume(BoosterKind.Mallet), "the second use must fail: none left");
            Assert.AreEqual(0, bag.Count(BoosterKind.Mallet), "a failed use must not go negative");
            Assert.IsFalse(bag.Has(BoosterKind.Mallet));
        }

        [Test]
        public void ARefundPutsTheBoosterBackExactly()
        {
            var bag = new BoosterBag(Fresh());
            int before = bag.Count(BoosterKind.Falcon);

            Assert.IsTrue(bag.TryConsume(BoosterKind.Falcon));
            bag.Grant(BoosterKind.Falcon, 1);

            Assert.AreEqual(before, bag.Count(BoosterKind.Falcon));
        }

        [Test]
        public void TheCountStopsAtTheCeiling()
        {
            var bag = new BoosterBag(Fresh());

            bag.Grant(BoosterKind.Ram, 99);

            Assert.AreEqual(BoosterCatalog.MaxOwned, bag.Count(BoosterKind.Ram));
        }

        [Test]
        public void BuyingSpendsCoinsAndRefusesWhenThePurseIsShort()
        {
            var save = Fresh();
            save.coins = (long)BoosterCatalog.Price(BoosterKind.Auger) * 2;
            var wallet = new Wallet(save);
            var bag = new BoosterBag(save);
            int before = bag.Count(BoosterKind.Auger);

            Assert.IsTrue(bag.Buy(BoosterKind.Auger, wallet));
            Assert.AreEqual(before + 1, bag.Count(BoosterKind.Auger));
            Assert.AreEqual((long)BoosterCatalog.Price(BoosterKind.Auger), wallet.Coins);

            save.coins = (long)BoosterCatalog.Price(BoosterKind.Auger) - 1;
            int afterOne = bag.Count(BoosterKind.Auger);

            Assert.IsFalse(bag.Buy(BoosterKind.Auger, wallet), "no coins, no booster");
            Assert.AreEqual(afterOne, bag.Count(BoosterKind.Auger), "a refused sale changes nothing");
            Assert.AreEqual((long)BoosterCatalog.Price(BoosterKind.Auger) - 1, wallet.Coins);
        }

        [Test]
        public void BuyingStopsAtTheCeilingAndChargesOnlyForWhatFits()
        {
            var save = Fresh();
            save.coins = 100000;
            var wallet = new Wallet(save);
            var bag = new BoosterBag(save);

            bag.Grant(BoosterKind.Whirlwind, BoosterCatalog.MaxOwned);
            Assert.AreEqual(BoosterCatalog.MaxOwned, bag.Count(BoosterKind.Whirlwind));

            long coins = wallet.Coins;
            Assert.IsFalse(bag.Buy(BoosterKind.Whirlwind, wallet, 3), "no room, so nothing to sell");
            Assert.AreEqual(coins, wallet.Coins, "a refused sale must not touch the purse");

            bag.TryConsume(BoosterKind.Whirlwind);
            bag.TryConsume(BoosterKind.Whirlwind);

            Assert.IsTrue(bag.Buy(BoosterKind.Whirlwind, wallet, 5), "only two fit, and two is a sale");
            Assert.AreEqual(BoosterCatalog.MaxOwned, bag.Count(BoosterKind.Whirlwind));
            Assert.AreEqual(coins - (long)BoosterCatalog.Price(BoosterKind.Whirlwind) * 2, wallet.Coins,
                "the player pays for the two that fit, not for the three that did not");
        }

        [Test]
        public void EveryKindHasAPriceAndAName()
        {
            EachKind(kind =>
            {
                Assert.Greater(BoosterCatalog.Price(kind), 0, kind + " must cost something");
                Assert.IsFalse(string.IsNullOrEmpty(BoosterCatalog.Name(kind)), kind + " must have a name");
            });
        }

        [Test]
        public void AV1SaveIsGivenTheStarterBoostersOnLoad()
        {
            var clock = new ManualClock();
            var errors = new List<string>();

            var save = SaveCodec.Decode("{\"version\":1,\"coins\":40,\"potions\":90}", clock, errors);

            Assert.AreEqual(SaveData.CurrentVersion, save.version);
            Assert.AreEqual(BoosterCatalog.Slots, save.boosters.Count, "a migrated save has all five slots");
            EachKind(kind => Assert.AreEqual(BoosterCatalog.StartOwned, new BoosterBag(save).Count(kind)));

            StringAssert.Contains("v1 to v2", string.Join("; ", errors.ToArray()));
        }

        [Test]
        public void AShortOrMissingListIsRepairedInsteadOfThrowing()
        {
            var clock = new ManualClock();

            var missing = SaveCodec.Decode("{\"version\":2,\"boosters\":null}", clock, new List<string>());
            Assert.AreEqual(BoosterCatalog.Slots, missing.boosters.Count);

            var shortList = SaveCodec.Decode("{\"version\":2,\"boosters\":[3]}", clock, new List<string>());
            Assert.AreEqual(BoosterCatalog.Slots, shortList.boosters.Count);
            Assert.AreEqual(3, shortList.boosters[0], "what the player had is kept");
        }

        [Test]
        public void ABagRepairsAnOutOfRangeCountOnConstruction()
        {
            var save = Fresh();
            save.boosters = new List<int> { -4, 99, 2, 2, 2 };

            var bag = new BoosterBag(save);

            Assert.AreEqual(0, bag.Count(BoosterKind.Mallet));
            Assert.AreEqual(BoosterCatalog.MaxOwned, bag.Count(BoosterKind.Ram));
            Assert.AreEqual(2, bag.Count(BoosterKind.Auger));
        }
    }
}
