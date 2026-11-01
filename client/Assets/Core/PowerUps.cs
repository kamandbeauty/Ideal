using System.Collections.Generic;

namespace Shazdeh.Core
{
    /// <summary>
    /// Blast shapes and combinations, in one place, so the view, the server replay and the tests all
    /// agree on what a Rocket does. Values marked "tunable" are ours — the original's exact numbers
    /// are not public and we do not copy its tuning.
    /// </summary>
    public static class PowerUps
    {
        /// <summary>Tunable: Dynamite clears a 3x3 square.</summary>
        public const int DynamiteRadius = 1;

        /// <summary>Tunable: Spinner clears a random target and the eight cells around it.</summary>
        public const int SpinnerRadius = 1;

        /// <summary>Hard cap so a pathological board can never loop forever.</summary>
        public const int MaxTargets = 400;

        /// <summary>Cells a single power-up affects when it goes off at <paramref name="origin"/>.</summary>
        public static void CollectTargets(Board board, CellPos origin, PowerUpKind kind,
            DeterministicRandom rng, List<CellPos> into)
        {
            if (into == null) return;
            switch (kind)
            {
                case PowerUpKind.RocketVertical:
                    AddColumn(board, origin.X, into);
                    break;
                case PowerUpKind.RocketHorizontal:
                    AddRow(board, origin.Y, into);
                    break;
                case PowerUpKind.Dynamite:
                    AddSquare(board, origin, DynamiteRadius, into);
                    break;
                case PowerUpKind.Spinner:
                {
                    var target = rng != null ? PickSpinnerTarget(board, rng) : origin;
                    AddSquare(board, target, SpinnerRadius, into);
                    break;
                }
                case PowerUpKind.ElectroBall:
                    AddKind(board, MostCommonKind(board), into);
                    break;
                case PowerUpKind.SuperElectroBall:
                    AddAllPieces(board, into);
                    break;
            }
        }

        public static CellPos PickSpinnerTarget(Board board, DeterministicRandom rng)
        {
            var occupied = new List<CellPos>();
            foreach (var p in board.AllPositions())
            {
                var cell = board.At(p);
                if (cell != null && cell.HasPiece) occupied.Add(p);
            }
            if (occupied.Count == 0) return new CellPos(0, 0);
            if (rng == null) return occupied[0];
            return occupied[rng.Next(occupied.Count)];
        }

        /// <summary>
        /// Swapping two power-ups into each other. Every pair has an explicit rule; anything not listed
        /// falls back to the union of both blasts, which is never wrong, only plainer.
        /// </summary>
        public static void CollectComboTargets(Board board, CellPos origin, PowerUpKind a, PowerUpKind b,
            DeterministicRandom rng, List<CellPos> into)
        {
            if (into == null) return;

            if (a == PowerUpKind.SuperElectroBall || b == PowerUpKind.SuperElectroBall)
            {
                AddAllPieces(board, into);
                return;
            }

            bool electroA = a == PowerUpKind.ElectroBall;
            bool electroB = b == PowerUpKind.ElectroBall;
            if (electroA && electroB)
            {
                AddAllPieces(board, into);
                return;
            }

            if (electroA || electroB)
            {
                // Electro Ball + anything: clear every piece of the most common colour (deterministic,
                // and the same rule a single Electro Ball follows).
                AddKind(board, MostCommonKind(board), into);
                return;
            }

            bool rocketA = a == PowerUpKind.RocketVertical || a == PowerUpKind.RocketHorizontal;
            bool rocketB = b == PowerUpKind.RocketVertical || b == PowerUpKind.RocketHorizontal;
            bool dynA = a == PowerUpKind.Dynamite;
            bool dynB = b == PowerUpKind.Dynamite;
            bool spinA = a == PowerUpKind.Spinner;
            bool spinB = b == PowerUpKind.Spinner;

            if (rocketA && rocketB)
            {
                AddRow(board, origin.Y, into);
                AddColumn(board, origin.X, into);
                return;
            }

            if (dynA && dynB)
            {
                AddSquare(board, origin, 2, into);
                return;
            }

            if ((rocketA && dynB) || (dynA && rocketB))
            {
                AddRow(board, origin.Y, into);
                AddRow(board, origin.Y - 1, into);
                AddRow(board, origin.Y + 1, into);
                AddColumn(board, origin.X, into);
                AddColumn(board, origin.X - 1, into);
                AddColumn(board, origin.X + 1, into);
                return;
            }

            if (spinA || spinB)
            {
                var target = PickSpinnerTarget(board, rng);
                AddRow(board, target.Y, into);
                AddColumn(board, target.X, into);
                return;
            }

            CollectTargets(board, origin, a, rng, into);
            CollectTargets(board, origin, b, rng, into);
        }

        /// <summary>The colour most present on the board; ties go to the lowest enum value.</summary>
        public static PieceKind MostCommonKind(Board board)
        {
            var counts = new int[6];
            foreach (var p in board.AllPositions())
            {
                var cell = board.At(p);
                if (cell == null || !cell.HasPiece) continue;
                counts[(int)cell.Piece]++;
            }

            int best = 0;
            for (int i = 1; i < counts.Length; i++)
                if (counts[i] > counts[best]) best = i;

            return (PieceKind)best;
        }

        public static void AddRow(Board board, int y, List<CellPos> into)
        {
            if (y < 0 || y >= board.Height) return;
            for (int x = 0; x < board.Width; x++) AddUnique(into, new CellPos(x, y));
        }

        public static void AddColumn(Board board, int x, List<CellPos> into)
        {
            if (x < 0 || x >= board.Width) return;
            for (int y = 0; y < board.Height; y++) AddUnique(into, new CellPos(x, y));
        }

        public static void AddSquare(Board board, CellPos origin, int radius, List<CellPos> into)
        {
            for (int y = origin.Y - radius; y <= origin.Y + radius; y++)
            for (int x = origin.X - radius; x <= origin.X + radius; x++)
                if (board.InBounds(x, y)) AddUnique(into, new CellPos(x, y));
        }

        public static void AddKind(Board board, PieceKind kind, List<CellPos> into)
        {
            if (kind == PieceKind.None) return;
            foreach (var p in board.AllPositions())
            {
                var cell = board.At(p);
                if (cell != null && cell.HasPiece && cell.Piece == kind) AddUnique(into, p);
            }
        }

        public static void AddAllPieces(Board board, List<CellPos> into)
        {
            foreach (var p in board.AllPositions())
            {
                var cell = board.At(p);
                if (cell != null && cell.HasPiece) AddUnique(into, p);
            }
        }

        static void AddUnique(List<CellPos> into, CellPos pos)
        {
            if (into.Count >= MaxTargets) return;
            if (!into.Contains(pos)) into.Add(pos);
        }
    }
}
