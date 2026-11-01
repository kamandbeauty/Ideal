using System.Collections.Generic;
using NUnit.Framework;

namespace Shazdeh.Core.Tests
{
    public sealed class MatchFinderTests
    {
        [Test]
        public void FindsHorizontalRunOfThree()
        {
            var board = Board.FromAscii("FFF");
            var runs = MatchFinder.FindRuns(board);

            Assert.AreEqual(1, runs.Count);
            Assert.AreEqual(3, runs[0].Length);
            Assert.IsTrue(runs[0].Horizontal);
            Assert.AreEqual(PieceKind.Firouzeh, runs[0].Piece);
        }

        [Test]
        public void FindsVerticalRunOfThree()
        {
            var board = Board.FromAscii("F", "F", "F");
            var runs = MatchFinder.FindRuns(board);

            Assert.AreEqual(1, runs.Count);
            Assert.AreEqual(3, runs[0].Length);
            Assert.IsFalse(runs[0].Horizontal);
        }

        [Test]
        public void TwoInARowIsNotAMatch()
        {
            Assert.AreEqual(0, MatchFinder.FindRuns(Board.FromAscii("FFL")).Count);
        }

        [Test]
        public void RunOfFive_IsOneRun()
        {
            var runs = MatchFinder.FindRuns(Board.FromAscii("FFFFF"));
            Assert.AreEqual(1, runs.Count);
            Assert.AreEqual(5, runs[0].Length);
        }

        [Test]
        public void EmptyCellsBreakRuns()
        {
            var runs = MatchFinder.FindRuns(Board.FromAscii("FF.FF"));
            Assert.AreEqual(0, runs.Count);
        }

        [Test]
        public void DiagonalPattern_HasNoRuns()
        {
            // the classic filler: every row and column cycles five kinds, nothing can line up
            var board = Board.FromAscii(
                "FLAZM",
                "LAZMF",
                "AZMFL",
                "ZM FLA".Replace(" ", ""),
                "M FLAZ".Replace(" ", ""));

            Assert.AreEqual(0, MatchFinder.FindRuns(board).Count);
        }

        [Test]
        public void BuildClusters_MergesCrossingRuns()
        {
            var runs = new List<MatchRun>
            {
                new MatchRun { Start = new CellPos(0, 1), Length = 3, Horizontal = true, Piece = PieceKind.Aqiq },
                new MatchRun { Start = new CellPos(1, 0), Length = 3, Horizontal = false, Piece = PieceKind.Aqiq }
            };

            var clusters = MatchFinder.BuildClusters(runs);

            Assert.AreEqual(1, clusters.Count);
            Assert.IsTrue(clusters[0].HasHorizontal);
            Assert.IsTrue(clusters[0].HasVertical);
            Assert.AreEqual(5, clusters[0].Cells.Count);
        }

        [Test]
        public void BuildClusters_KeepsSeparateRunsApart()
        {
            var runs = new List<MatchRun>
            {
                new MatchRun { Start = new CellPos(0, 0), Length = 3, Horizontal = true, Piece = PieceKind.Aqiq },
                new MatchRun { Start = new CellPos(0, 4), Length = 3, Horizontal = true, Piece = PieceKind.Aqiq }
            };

            Assert.AreEqual(2, MatchFinder.BuildClusters(runs).Count);
        }

        [Test]
        public void FindsUniformSquare()
        {
            var board = Board.FromAscii("LAZ", "FFM", "FFA");
            var squares = MatchFinder.FindSquares(board);

            Assert.AreEqual(1, squares.Count);
            Assert.AreEqual(new CellPos(0, 0), squares[0]);
        }

        [Test]
        public void NoSquareWhenOneCornerDiffers()
        {
            var board = Board.FromAscii("LAZ", "FFM", "FFA");
            board.At(1, 0).Piece = PieceKind.Lajvard;

            Assert.AreEqual(0, MatchFinder.FindSquares(board).Count);
        }

        [Test]
        public void HasPossibleMove_TrueWhenASwapMakesAThree()
        {
            var board = Board.FromAscii(
                "AAZ",
                "ZMF",
                "AFZ");

            Assert.IsTrue(MatchFinder.HasPossibleMove(board));
        }

        [Test]
        public void HasPossibleMove_FalseOnAStaleBoard()
        {
            // a 3x3 board where no single swap lines three up
            var board = Board.FromAscii(
                "FLA",
                "LAF",
                "AFM");

            Assert.IsFalse(MatchFinder.HasPossibleMove(board));
        }

        [Test]
        public void PowerUpFor_ThreeIsNothing()
        {
            var cluster = new MatchCluster();
            cluster.Add(new MatchRun { Start = new CellPos(0, 0), Length = 3, Horizontal = true, Piece = PieceKind.Aqiq });

            Assert.AreEqual(PowerUpKind.None, MatchFinder.PowerUpFor(cluster));
        }

        [Test]
        public void PowerUpFor_HorizontalFourMakesAVerticalRocket()
        {
            var cluster = new MatchCluster();
            cluster.Add(new MatchRun { Start = new CellPos(0, 0), Length = 4, Horizontal = true, Piece = PieceKind.Aqiq });

            Assert.AreEqual(PowerUpKind.RocketVertical, MatchFinder.PowerUpFor(cluster));
        }

        [Test]
        public void PowerUpFor_VerticalFourMakesAHorizontalRocket()
        {
            var cluster = new MatchCluster();
            cluster.Add(new MatchRun { Start = new CellPos(0, 0), Length = 4, Horizontal = false, Piece = PieceKind.Aqiq });

            Assert.AreEqual(PowerUpKind.RocketHorizontal, MatchFinder.PowerUpFor(cluster));
        }

        [Test]
        public void PowerUpFor_FiveInLineMakesAnElectroBall()
        {
            var cluster = new MatchCluster();
            cluster.Add(new MatchRun { Start = new CellPos(0, 0), Length = 5, Horizontal = true, Piece = PieceKind.Zomorrod });

            Assert.AreEqual(PowerUpKind.ElectroBall, MatchFinder.PowerUpFor(cluster));
        }

        [Test]
        public void PowerUpFor_CrossingRunsMakeDynamite()
        {
            var cluster = new MatchCluster();
            cluster.Add(new MatchRun { Start = new CellPos(0, 1), Length = 3, Horizontal = true, Piece = PieceKind.Aqiq });
            cluster.Add(new MatchRun { Start = new CellPos(1, 0), Length = 3, Horizontal = false, Piece = PieceKind.Aqiq });

            Assert.AreEqual(PowerUpKind.Dynamite, MatchFinder.PowerUpFor(cluster));
        }

        [Test]
        public void PowerUpFor_SquareMakesSpinner()
        {
            var cluster = new MatchCluster { HasSquare = true };
            Assert.AreEqual(PowerUpKind.Spinner, MatchFinder.PowerUpFor(cluster));
        }

        [Test]
        public void ChooseSpawnCell_PrefersTheCellThePlayerMovedInto()
        {
            var cluster = new MatchCluster();
            cluster.Add(new MatchRun { Start = new CellPos(0, 0), Length = 4, Horizontal = true, Piece = PieceKind.Aqiq });

            var preferred = new CellPos(3, 0);
            Assert.AreEqual(preferred, MatchFinder.ChooseSpawnCell(cluster, preferred, true));
        }

        [Test]
        public void ChooseSpawnCell_FallsBackToTheMiddleOfTheRun()
        {
            var cluster = new MatchCluster();
            cluster.Add(new MatchRun { Start = new CellPos(0, 0), Length = 5, Horizontal = true, Piece = PieceKind.Aqiq });

            Assert.AreEqual(new CellPos(2, 0), MatchFinder.ChooseSpawnCell(cluster, new CellPos(8, 8), true));
        }
    }
}
