using System.Collections.Generic;

namespace Shazdeh.Core
{
    public static class BoardFactory
    {
        /// <summary>
        /// Builds the opening board for a level: no pre-existing matches (nothing to auto-clear on the
        /// first frame), obstacles as a layer under the pieces, blocked cells empty.
        /// Deterministic in (level, seed) so the server can reproduce it.
        /// </summary>
        public static Board Create(LevelDefinition level, ulong seed)
        {
            var rng = new DeterministicRandom(seed);
            var board = new Board(level.Width, level.Height);

            for (int i = 0; i < level.Blocked.Count; i++)
            {
                var cell = board.At(level.Blocked[i]);
                if (cell != null) cell.Blocked = true;
            }

            var kinds = new List<PieceKind>(level.Pieces);
            for (int y = 0; y < board.Height; y++)
            {
                for (int x = 0; x < board.Width; x++)
                {
                    var cell = board.At(x, y);
                    if (cell == null || cell.Blocked) continue;

                    cell.Piece = PickWithoutMatch(board, x, y, kinds, rng);
                }
            }

            for (int i = 0; i < level.Obstacles.Count; i++)
            {
                var spec = level.Obstacles[i];
                var cell = board.At(spec.X, spec.Y);
                if (cell == null || cell.Blocked) continue;
                cell.SetObstacle(spec.Kind, spec.Layers);
            }

            return board;
        }

        static PieceKind PickWithoutMatch(Board board, int x, int y, List<PieceKind> kinds, DeterministicRandom rng)
        {
            if (kinds.Count == 0) return PieceKind.Firouzeh;

            int start = rng.Next(kinds.Count);
            for (int attempt = 0; attempt < kinds.Count; attempt++)
            {
                var candidate = kinds[(start + attempt) % kinds.Count];
                if (!WouldMatch(board, x, y, candidate)) return candidate;
            }
            return kinds[start];
        }

        static bool WouldMatch(Board board, int x, int y, PieceKind candidate)
        {
            // two equal pieces to the left, or two below (the fill order is bottom-up, left-right)
            var left1 = board.At(x - 1, y);
            var left2 = board.At(x - 2, y);
            if (left1 != null && left2 != null && left1.HasPiece && left2.HasPiece &&
                left1.Piece == candidate && left2.Piece == candidate) return true;

            var down1 = board.At(x, y - 1);
            var down2 = board.At(x, y - 2);
            if (down1 != null && down2 != null && down1.HasPiece && down2.HasPiece &&
                down1.Piece == candidate && down2.Piece == candidate) return true;

            return false;
        }

        /// <summary>Deterministic reshuffle of every piece, used when no swap creates a match.</summary>
        public static void Reshuffle(Board board, List<PieceKind> kinds, DeterministicRandom rng)
        {
            var pieces = new List<PieceKind>();
            foreach (var p in board.AllPositions())
            {
                var cell = board.At(p);
                if (cell == null || !cell.HasPiece) continue;
                pieces.Add(cell.Piece);
            }

            for (int attempt = 0; attempt < 24; attempt++)
            {
                rng.Shuffle(pieces);
                int index = 0;
                foreach (var p in board.AllPositions())
                {
                    var cell = board.At(p);
                    if (cell == null || !cell.HasPiece) continue;
                    cell.Piece = pieces[index++];
                }

                if (MatchFinder.FindRuns(board).Count == 0 && MatchFinder.HasPossibleMove(board)) return;
            }

            // Last resort: rebuild the values from the kinds list, which cannot produce a dead board
            // often enough to matter, and is still deterministic.
            foreach (var p in board.AllPositions())
            {
                var cell = board.At(p);
                if (cell == null || !cell.HasPiece) continue;
                cell.Piece = kinds.Count > 0 ? kinds[rng.Next(kinds.Count)] : PieceKind.Firouzeh;
            }
        }
    }
}
