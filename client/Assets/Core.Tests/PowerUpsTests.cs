using System.Collections.Generic;
using NUnit.Framework;

namespace Shazdeh.Core.Tests
{
    public sealed class PowerUpsTests
    {
        static List<CellPos> Targets(Board board, int x, int y, PowerUpKind kind)
        {
            var list = new List<CellPos>();
            PowerUps.CollectTargets(board, new CellPos(x, y), kind, new DeterministicRandom(1), list);
            return list;
        }

        [Test]
        public void RocketVertical_ClearsTheWholeColumn()
        {
            var board = Board.FromAscii("FLA", "LAF", "AFM");
            var targets = Targets(board, 1, 1, PowerUpKind.RocketVertical);

            Assert.AreEqual(3, targets.Count);
            foreach (var p in targets) Assert.AreEqual(1, p.X);
        }

        [Test]
        public void RocketHorizontal_ClearsTheWholeRow()
        {
            var board = Board.FromAscii("FLA", "LAF", "AFM");
            var targets = Targets(board, 1, 1, PowerUpKind.RocketHorizontal);

            Assert.AreEqual(3, targets.Count);
            foreach (var p in targets) Assert.AreEqual(1, p.Y);
        }

        [Test]
        public void Dynamite_ClearsASquareAndClipsAtTheEdge()
        {
            var board = Board.FromAscii("FLA", "LAF", "AFM");

            Assert.AreEqual(9, Targets(board, 1, 1, PowerUpKind.Dynamite).Count);
            Assert.AreEqual(4, Targets(board, 0, 0, PowerUpKind.Dynamite).Count);
        }

        [Test]
        public void ElectroBall_ClearsEveryPieceOfTheMostCommonKind()
        {
            var board = Board.FromAscii(
                "FFF",
                "FLA",
                "ZAM");
            var targets = Targets(board, 0, 0, PowerUpKind.ElectroBall);

            foreach (var p in targets) Assert.AreEqual(PieceKind.Firouzeh, board.At(p).Piece);
            Assert.AreEqual(4, targets.Count);
        }

        [Test]
        public void SuperElectroBall_ClearsEverything()
        {
            var board = Board.FromAscii("FLA", "LAF", "AFM");
            Assert.AreEqual(9, Targets(board, 1, 1, PowerUpKind.SuperElectroBall).Count);
        }

        [Test]
        public void MostCommonKind_TiesGoToTheLowestValue()
        {
            var board = Board.FromAscii("FLA", "LAF", "AFM");
            Assert.AreEqual(PieceKind.Firouzeh, PowerUps.MostCommonKind(board));
        }

        [Test]
        public void ComboTwoRockets_ClearsRowAndColumn()
        {
            var board = Board.FromAscii("FLA", "LAF", "AFM");
            var targets = new List<CellPos>();

            PowerUps.CollectComboTargets(board, new CellPos(1, 1), PowerUpKind.RocketVertical,
                PowerUpKind.RocketHorizontal, new DeterministicRandom(3), targets);

            Assert.AreEqual(5, targets.Count); // 3 + 3 - the shared cell
        }

        [Test]
        public void ComboSuperElectro_ClearsTheBoard()
        {
            var board = Board.FromAscii("FLA", "LAF", "AFM");
            var targets = new List<CellPos>();

            PowerUps.CollectComboTargets(board, new CellPos(0, 0), PowerUpKind.SuperElectroBall,
                PowerUpKind.Dynamite, new DeterministicRandom(3), targets);

            Assert.AreEqual(9, targets.Count);
        }

        [Test]
        public void ComboDynamiteRocket_ClearsThreeRowsAndThreeColumns()
        {
            var board = Board.FromAscii("FLAFLAFLA", "LAFLAFLAF", "AFMAFMAFM",
                "FLAFLAFLA", "LAFLAFLAF", "AFMAFMAFM", "FLAFLAFLA");
            var targets = new List<CellPos>();

            PowerUps.CollectComboTargets(board, new CellPos(4, 3), PowerUpKind.Dynamite,
                PowerUpKind.RocketVertical, new DeterministicRandom(3), targets);

            // 3 rows of 9 + 3 columns of 7, minus the 9 cells counted twice
            Assert.AreEqual(3 * 9 + 3 * 7 - 9, targets.Count);
        }

        [Test]
        public void CollectTargets_NeverExceedsTheCap()
        {
            var board = Board.FromAscii("FLA", "LAF", "AFM");
            var targets = new List<CellPos>();
            for (int i = 0; i < 200; i++) targets.Add(new CellPos(i, i));

            PowerUps.AddRow(board, 0, targets);

            Assert.LessOrEqual(targets.Count, PowerUps.MaxTargets);
        }
    }
}
