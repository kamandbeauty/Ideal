using System.Collections.Generic;
using NUnit.Framework;

namespace Shazdeh.Core.Tests
{
    /// <summary>
    /// The RNG is the contract that lets the server reproduce a client's board. These are golden
    /// vectors: if they ever change, every stored replay in production becomes unverifiable.
    /// </summary>
    public sealed class DeterministicRandomTests
    {
        [Test]
        public void Seed42_FirstSixDraws_MatchGoldenVector()
        {
            var rng = new DeterministicRandom(42);

            ulong[] expected =
            {
                6255019084209693600UL,
                14430073426741505498UL,
                14575455857230217846UL,
                17414512882241728735UL,
                14100574548354140678UL,
                15416679289703091875UL
            };

            for (int i = 0; i < expected.Length; i++)
                Assert.AreEqual(expected[i], rng.NextULong(), "draw " + i);
        }

        [Test]
        public void Seed42_StateAfterSixDraws_IsStable()
        {
            var rng = new DeterministicRandom(42);
            for (int i = 0; i < 6; i++) rng.NextULong();
            Assert.AreEqual("c0d2f1a263e84ebf", rng.StateHex());
        }

        [Test]
        public void Next_StaysInsideRange()
        {
            var rng = new DeterministicRandom(7);
            for (int i = 0; i < 5000; i++)
            {
                int value = rng.Next(100);
                Assert.GreaterOrEqual(value, 0);
                Assert.Less(value, 100);
            }
        }

        [Test]
        public void Next_WithZeroOrNegativeMax_ReturnsZero()
        {
            var rng = new DeterministicRandom(1);
            Assert.AreEqual(0, rng.Next(0));
            Assert.AreEqual(0, rng.Next(-5));
        }

        [Test]
        public void SeedZero_FallsBackToAUsableState()
        {
            var a = new DeterministicRandom(0);
            var b = new DeterministicRandom(0);
            Assert.AreEqual(a.NextULong(), b.NextULong());
            Assert.AreNotEqual(0UL, a.State);
        }

        [Test]
        public void Shuffle_IsDeterministicForTheSameSeed()
        {
            var first = new List<int> { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
            var second = new List<int> { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

            new DeterministicRandom(1234).Shuffle(first);
            new DeterministicRandom(1234).Shuffle(second);

            Assert.AreEqual(first, second);
            Assert.AreNotEqual(new List<int> { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, first);
        }

        [Test]
        public void Shuffle_KeepsEveryElement()
        {
            var items = new List<int>();
            for (int i = 0; i < 50; i++) items.Add(i);

            new DeterministicRandom(99).Shuffle(items);

            items.Sort();
            for (int i = 0; i < 50; i++) Assert.AreEqual(i, items[i]);
        }
    }
}
