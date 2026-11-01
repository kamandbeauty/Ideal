using System.Collections.Generic;
using NUnit.Framework;

namespace Shazdeh.Core.Tests
{
    public sealed class MoveResolverTests
    {
        /// <summary>Bottom-up diagonal filler: no runs anywhere, five kinds, 5x5.</summary>
        static Board Filler()
        {
            return Board.FromAscii(
                "AZMFL",
                "ZM FLA".Replace(" ", ""),
                "M FLAZ".Replace(" ", ""),
                "FLAZM",
                "LAZMF");
        }

        static LevelDefinition MakeLevel(int moveLimit, GoalKind kind, PieceKind piece, int target)
        {
            var level = new LevelDefinition
            {
                Id = "test-level", Number = 1, Width = 5, Height = 5, MoveLimit = moveLimit, Type = "normal"
            };
            level.Pieces.Add(PieceKind.Firouzeh);
            level.Pieces.Add(PieceKind.Lajvard);
            level.Pieces.Add(PieceKind.Aqiq);
            level.Pieces.Add(PieceKind.Zomorrod);
            level.Pieces.Add(PieceKind.Morvarid);
            level.Goals.Add(new GoalDefinition(kind, piece, target));
            return level;
        }

        [Test]
        public void FillerBoardIsStable()
        {
            Assert.AreEqual(0, MatchFinder.FindRuns(Filler()).Count, "the test fixture itself must not have matches");
        }

        [Test]
        public void SwapThatMakesAThree_IsAcceptedAndSettles()
        {
            // row y=1 is A F A _ _ ; swapping (1,1) with (1,0) (=A) makes A A A
            var board = Board.FromAscii(
                "AZMFL",
                "ZM FLA".Replace(" ", ""),
                "M FLAZ".Replace(" ", ""),
                "AFAZM",
                "LAZMF");

            var level = MakeLevel(20, GoalKind.ClearPieces, PieceKind.Aqiq, 40);
            var goals = new GoalTracker(level.Goals);
            var resolver = new MoveResolver(level, board, new DeterministicRandom(123), goals);

            var result = resolver.Swap(new CellPos(1, 1), new CellPos(1, 0));

            Assert.IsTrue(result.Accepted, "expected the swap to be accepted");
            Assert.GreaterOrEqual(result.PiecesCleared, 3);
            Assert.GreaterOrEqual(goals.Progress(0), 3);
            Assert.AreEqual(0, MatchFinder.FindRuns(board).Count, "board must settle with no matches");
            AssertBoardIsFull(board);
        }

        [Test]
        public void SwapWithNoMatch_IsRejectedAndLeavesTheBoardUntouched()
        {
            var board = Filler();
            var level = MakeLevel(20, GoalKind.ClearPieces, PieceKind.Aqiq, 40);
            var resolver = new MoveResolver(level, board, new DeterministicRandom(9), new GoalTracker(level.Goals));
            ulong before = StateHash.Compute(board);

            var result = resolver.Swap(new CellPos(1, 1), new CellPos(1, 0));

            Assert.IsFalse(result.Accepted);
            Assert.AreEqual(StateHash.Compute(board), before);
        }

        [Test]
        public void NonAdjacentSwap_IsRejected()
        {
            var board = Filler();
            var level = MakeLevel(20, GoalKind.ClearPieces, PieceKind.Aqiq, 40);
            var resolver = new MoveResolver(level, board, new DeterministicRandom(9), new GoalTracker(level.Goals));

            var result = resolver.Swap(new CellPos(0, 0), new CellPos(0, 2));

            Assert.IsFalse(result.Accepted);
            Assert.AreEqual("not adjacent", result.RejectReason);
        }

        [Test]
        public void OutOfBoundsSwap_IsRejected()
        {
            var board = Filler();
            var level = MakeLevel(20, GoalKind.ClearPieces, PieceKind.Aqiq, 40);
            var resolver = new MoveResolver(level, board, new DeterministicRandom(9), new GoalTracker(level.Goals));

            Assert.IsFalse(resolver.Swap(new CellPos(-1, 0), new CellPos(0, 0)).Accepted);
            Assert.IsFalse(resolver.Swap(new CellPos(0, 0), new CellPos(9, 9)).Accepted);
        }

        [Test]
        public void ClearingAPieceOnAnObstacle_DamagesIt()
        {
            var board = Board.FromAscii(
                "AZMFL",
                "ZM FLA".Replace(" ", ""),
                "M FLAZ".Replace(" ", ""),
                "AFAZM",
                "LAZMF");
            board.At(0, 1).SetObstacle(ObstacleKind.Crate, 1);

            var level = MakeLevel(20, GoalKind.ClearObstacle, PieceKind.None, 1);
            level.Goals.Clear();
            level.Goals.Add(new GoalDefinition(GoalKind.ClearObstacle, ObstacleKind.Crate, 1));

            var goals = new GoalTracker(level.Goals);
            var resolver = new MoveResolver(level, board, new DeterministicRandom(123), goals);
            var result = resolver.Swap(new CellPos(1, 1), new CellPos(1, 0));

            bool hit = false;
            for (int i = 0; i < result.Events.Count; i++)
            {
                var ev = result.Events[i] as ObstacleHitEvent;
                if (ev != null && ev.Position == new CellPos(0, 1)) hit = true;
            }

            Assert.IsTrue(result.Accepted);
            Assert.IsTrue(hit, "expected an obstacle hit on the cleared crate cell");
            Assert.IsFalse(board.At(0, 1).HasObstacle);
            Assert.AreEqual(1, result.ObstaclesDestroyed);
        }

        [Test]
        public void TwoLayerObstacle_NeedsTwoHits()
        {
            var board = Filler();
            board.At(1, 1).SetObstacle(ObstacleKind.Frost, 2);
            var level = MakeLevel(20, GoalKind.ClearObstacle, PieceKind.None, 1);
            level.Goals.Clear();
            level.Goals.Add(new GoalDefinition(GoalKind.ClearObstacle, ObstacleKind.Frost, 2));

            var resolver = new MoveResolver(level, board, new DeterministicRandom(5), new GoalTracker(level.Goals));
            resolver.UseBooster(BoosterKind.Mallet, new CellPos(1, 1));

            Assert.IsTrue(board.At(1, 1).HasObstacle);
            Assert.AreEqual(1, board.At(1, 1).ObstacleLayers);

            resolver.UseBooster(BoosterKind.Mallet, new CellPos(1, 1));

            Assert.IsFalse(board.At(1, 1).HasObstacle);
        }

        [Test]
        public void FourInARow_CreatesARocket()
        {
            // row y=1 is A F A A _ ; swapping (1,1) with (1,0) makes A A A A
            var board = Board.FromAscii(
                "AZMFL",
                "ZM FLA".Replace(" ", ""),
                "M FLAZ".Replace(" ", ""),
                "AFAA M".Replace(" ", ""),
                "LAZMF");

            var level = MakeLevel(20, GoalKind.ClearPieces, PieceKind.Aqiq, 40);
            var resolver = new MoveResolver(level, board, new DeterministicRandom(77), new GoalTracker(level.Goals));

            var result = resolver.Swap(new CellPos(1, 1), new CellPos(1, 0));

            Assert.IsTrue(result.Accepted);
            bool createdRocket = false;
            for (int i = 0; i < result.Events.Count; i++)
            {
                var ev = result.Events[i] as PowerUpCreatedEvent;
                if (ev != null && (ev.Kind == PowerUpKind.RocketVertical || ev.Kind == PowerUpKind.RocketHorizontal))
                    createdRocket = true;
            }
            Assert.IsTrue(createdRocket, "a run of four must create a rocket");
        }

        [Test]
        public void BoosterClearsWithoutNeedingAMatch()
        {
            var board = Filler();
            var level = MakeLevel(20, GoalKind.ClearPieces, PieceKind.Aqiq, 40);
            var resolver = new MoveResolver(level, board, new DeterministicRandom(3), new GoalTracker(level.Goals));

            var result = resolver.UseBooster(BoosterKind.Mallet, new CellPos(2, 2));

            Assert.IsTrue(result.Accepted);
            Assert.GreaterOrEqual(result.PiecesCleared, 1);
            AssertBoardIsFull(board);
        }

        [Test]
        public void WhirlwindShufflesWithoutClearing()
        {
            var board = Filler();
            var level = MakeLevel(20, GoalKind.ClearPieces, PieceKind.Aqiq, 40);
            var resolver = new MoveResolver(level, board, new DeterministicRandom(3), new GoalTracker(level.Goals));

            var result = resolver.UseBooster(BoosterKind.Whirlwind, new CellPos(2, 2));

            Assert.IsTrue(result.Accepted);
            Assert.AreEqual(0, result.PiecesCleared);
            AssertBoardIsFull(board);
            Assert.AreEqual(0, MatchFinder.FindRuns(board).Count);
        }

        [Test]
        public void RandomBoard_RandomSwaps_KeepTheInvariants()
        {
            var level = MakeLevel(999, GoalKind.ClearPieces, PieceKind.Aqiq, 5000);
            level.Width = 9;
            level.Height = 9;

            for (ulong seed = 1; seed <= 40; seed++)
            {
                var board = BoardFactory.Create(level, seed);
                var goals = new GoalTracker(level.Goals);
                var rng = new DeterministicRandom(seed * 7919UL);
                var resolver = new MoveResolver(level, board, rng, goals);

                Assert.AreEqual(0, MatchFinder.FindRuns(board).Count, "seed " + seed + ": opening board must be stable");
                AssertBoardIsFull(board);

                for (int move = 0; move < 60; move++)
                {
                    int x1, y1, x2, y2;
                    if (!TryFindSwap(board, out x1, out y1, out x2, out y2)) break;

                    var result = resolver.Swap(new CellPos(x1, y1), new CellPos(x2, y2));

                    Assert.IsTrue(result.Accepted, "seed " + seed + " move " + move + ": the probe found this swap");
                    Assert.Greater(result.PiecesCleared, 0, "an accepted swap clears something");
                    Assert.AreEqual(0, MatchFinder.FindRuns(board).Count, "seed " + seed + " move " + move + ": no matches may survive");
                    AssertBoardIsFull(board);
                }
            }
        }

        internal static void AssertBoardIsFull(Board board)
        {
            foreach (var pos in board.AllPositions())
            {
                var cell = board.At(pos);
                if (cell.Blocked) continue;
                Assert.IsTrue(cell.HasPiece, "cell " + pos + " is empty after a settled move");
            }
        }

        /// <summary>Finds any adjacent pair whose swap produces a match — used by tests instead of hard-coding moves.</summary>
        internal static bool TryFindSwap(Board board, out int x1, out int y1, out int x2, out int y2)
        {
            int[] dx = { 1, 0 };
            int[] dy = { 0, 1 };

            for (int y = 0; y < board.Height; y++)
            {
                for (int x = 0; x < board.Width; x++)
                {
                    for (int d = 0; d < dx.Length; d++)
                    {
                        int nx = x + dx[d];
                        int ny = y + dy[d];
                        var a = board.At(x, y);
                        var b = board.At(nx, ny);
                        if (a == null || b == null || !a.HasPiece || !b.HasPiece) continue;

                        MatchFinder.SwapPieces(a, b);
                        bool ok = MatchFinder.HasMatch(board) ||
                                  (a.PowerUp != PowerUpKind.None && b.PowerUp != PowerUpKind.None);
                        MatchFinder.SwapPieces(a, b);

                        if (ok)
                        {
                            x1 = x;
                            y1 = y;
                            x2 = nx;
                            y2 = ny;
                            return true;
                        }
                    }
                }
            }

            x1 = y1 = x2 = y2 = -1;
            return false;
        }
    }
}
