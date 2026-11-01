using System.Collections.Generic;
using NUnit.Framework;

namespace Shazdeh.Core.Tests
{
    public sealed class LevelRunTests
    {
        static LevelDefinition MakeLevel(int moveLimit, PieceKind goalPiece, int target)
        {
            var level = new LevelDefinition
            {
                Id = "run-test", Number = 1, Width = 9, Height = 9, MoveLimit = moveLimit,
                Type = "normal", RewardPotions = 12, RewardCoins = 20
            };
            level.Pieces.Add(PieceKind.Firouzeh);
            level.Pieces.Add(PieceKind.Lajvard);
            level.Pieces.Add(PieceKind.Aqiq);
            level.Pieces.Add(PieceKind.Zomorrod);
            level.Pieces.Add(PieceKind.Morvarid);
            level.Goals.Add(new GoalDefinition(GoalKind.ClearPieces, goalPiece, target));
            return level;
        }

        [Test]
        public void OpeningBoardIsStableAndSettled()
        {
            var level = MakeLevel(20, PieceKind.Aqiq, 20);
            for (ulong seed = 1; seed <= 20; seed++)
            {
                var run = new LevelRun(level, seed);
                Assert.AreEqual(0, MatchFinder.FindRuns(run.Board).Count, "seed " + seed);
                Assert.IsTrue(MatchFinder.HasPossibleMove(run.Board), "seed " + seed + ": a player must have a move");
                MoveResolverTests.AssertBoardIsFull(run.Board);
                Assert.AreEqual(20, run.MovesLeft);
                Assert.AreEqual(LevelStatus.Playing, run.Status);
            }
        }

        [Test]
        public void AcceptedSwapConsumesAMove_RejectedSwapDoesNot()
        {
            var level = MakeLevel(20, PieceKind.Aqiq, 60);
            var run = new LevelRun(level, 4242);

            int x1, y1, x2, y2;
            Assert.IsTrue(MoveResolverTests.TryFindSwap(run.Board, out x1, out y1, out x2, out y2));
            var accepted = run.TrySwap(x1, y1, x2, y2);
            Assert.IsTrue(accepted.Accepted);
            Assert.AreEqual(19, run.MovesLeft);
            Assert.AreEqual(1, run.MovesUsed);

            var rejected = run.TrySwap(0, 0, 0, 0);
            Assert.IsFalse(rejected.Accepted);
            Assert.AreEqual(19, run.MovesLeft);
            Assert.AreEqual(1, run.MovesUsed);
        }

        [Test]
        public void BoosterDoesNotConsumeAMove()
        {
            var level = MakeLevel(20, PieceKind.Aqiq, 60);
            var run = new LevelRun(level, 99);

            var result = run.UseBooster(BoosterKind.Mallet, new CellPos(4, 4));

            Assert.IsTrue(result.Accepted);
            Assert.AreEqual(20, run.MovesLeft);
            Assert.AreEqual(1, run.BoostersUsed.Count);
        }

        [Test]
        public void SameSeedAndSameMoves_ProduceTheSameHash()
        {
            var level = MakeLevel(30, PieceKind.Aqiq, 200);

            // record a move sequence on a probe run first
            var probe = new LevelRun(level, 2026);
            var moves = new List<int[]>();
            for (int i = 0; i < 8; i++)
            {
                int x1, y1, x2, y2;
                if (!MoveResolverTests.TryFindSwap(probe.Board, out x1, out y1, out x2, out y2)) break;
                moves.Add(new[] { x1, y1, x2, y2 });
                probe.TrySwap(x1, y1, x2, y2);
            }

            Assert.GreaterOrEqual(moves.Count, 3, "the probe should find a few legal swaps");

            var first = new LevelRun(level, 2026);
            var second = new LevelRun(level, 2026);
            for (int i = 0; i < moves.Count; i++)
            {
                var m = moves[i];
                first.TrySwap(m[0], m[1], m[2], m[3]);
                second.TrySwap(m[0], m[1], m[2], m[3]);
            }

            Assert.AreEqual(first.StateHash(), second.StateHash());
            Assert.AreEqual(first.MovesLeft, second.MovesLeft);
            Assert.AreEqual(first.Goals.Progress(0), second.Goals.Progress(0));
        }

        [Test]
        public void DifferentSeeds_ProduceDifferentBoards()
        {
            var level = MakeLevel(20, PieceKind.Aqiq, 20);
            var a = new LevelRun(level, 5);
            var b = new LevelRun(level, 6);

            Assert.AreNotEqual(StateHash.Compute(a.Board), StateHash.Compute(b.Board));
        }

        [Test]
        public void ReachingAllGoals_WinsAndPaysTheReward()
        {
            var level = MakeLevel(60, PieceKind.Aqiq, 3);
            var run = new LevelRun(level, 777);

            for (int i = 0; i < 120 && run.Status == LevelStatus.Playing; i++)
            {
                int x1, y1, x2, y2;
                if (!MoveResolverTests.TryFindSwap(run.Board, out x1, out y1, out x2, out y2)) break;
                run.TrySwap(x1, y1, x2, y2);
            }

            Assert.AreEqual(LevelStatus.Won, run.Status);
            Assert.AreEqual(level.RewardPotions, run.PotionsEarned);
            Assert.AreEqual(level.RewardCoins, run.CoinsEarned);
        }

        [Test]
        public void RunningOutOfMoves_LosesWithoutAPayout()
        {
            var level = MakeLevel(3, PieceKind.Aqiq, 200);
            var run = new LevelRun(level, 31337);

            for (int i = 0; i < 40 && run.Status == LevelStatus.Playing; i++)
            {
                int x1, y1, x2, y2;
                if (!MoveResolverTests.TryFindSwap(run.Board, out x1, out y1, out x2, out y2)) break;
                run.TrySwap(x1, y1, x2, y2);
            }

            Assert.AreEqual(LevelStatus.Lost, run.Status);
            Assert.AreEqual(0, run.MovesLeft);
            Assert.AreEqual(0, run.PotionsEarned);
        }

        [Test]
        public void NoPlayAfterTheLevelEnds()
        {
            var level = MakeLevel(1, PieceKind.Aqiq, 200);
            var run = new LevelRun(level, 1);

            int x1, y1, x2, y2;
            if (MoveResolverTests.TryFindSwap(run.Board, out x1, out y1, out x2, out y2))
                run.TrySwap(x1, y1, x2, y2);

            Assert.AreEqual(LevelStatus.Lost, run.Status);
            ulong frozen = run.StateHash();

            var after = run.TrySwap(0, 0, 0, 1);
            Assert.IsFalse(after.Accepted);
            Assert.AreEqual(frozen, run.StateHash());
        }
    }
}
