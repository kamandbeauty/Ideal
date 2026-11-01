using System.Collections.Generic;

namespace Shazdeh.Core
{
    /// <summary>A straight run of three or more equal pieces.</summary>
    public struct MatchRun
    {
        public CellPos Start;
        public int Length;
        public bool Horizontal;
        public PieceKind Piece;

        public CellPos CellAt(int index)
        {
            return Horizontal
                ? new CellPos(Start.X + index, Start.Y)
                : new CellPos(Start.X, Start.Y + index);
        }
    }

    /// <summary>Runs that touch each other, resolved together. One cluster makes at most one power-up.</summary>
    public sealed class MatchCluster
    {
        public readonly List<MatchRun> Runs = new List<MatchRun>();
        public readonly List<CellPos> Cells = new List<CellPos>();
        public int MaxLength;
        public bool HasHorizontal;
        public bool HasVertical;
        public bool HasSquare;

        public void Add(MatchRun run)
        {
            Runs.Add(run);
            if (run.Horizontal) HasHorizontal = true; else HasVertical = true;
            if (run.Length > MaxLength) MaxLength = run.Length;
            for (int i = 0; i < run.Length; i++)
            {
                var p = run.CellAt(i);
                if (!Cells.Contains(p)) Cells.Add(p);
            }
        }

        public bool Contains(CellPos p) => Cells.Contains(p);
    }

    public static class MatchFinder
    {
        /// <summary>All horizontal and vertical runs of 3+, scanned bottom-up then left-right.</summary>
        public static List<MatchRun> FindRuns(Board board)
        {
            var runs = new List<MatchRun>();

            for (int y = 0; y < board.Height; y++)
            {
                int x = 0;
                while (x < board.Width)
                {
                    var cell = board.At(x, y);
                    PieceKind kind = cell != null && cell.HasPiece ? cell.Piece : PieceKind.None;
                    if (kind == PieceKind.None)
                    {
                        x++;
                        continue;
                    }

                    int end = x + 1;
                    while (end < board.Width)
                    {
                        var next = board.At(end, y);
                        if (next == null || !next.HasPiece || next.Piece != kind) break;
                        end++;
                    }

                    int length = end - x;
                    if (length >= 3)
                        runs.Add(new MatchRun
                        {
                            Start = new CellPos(x, y), Length = length, Horizontal = true, Piece = kind
                        });
                    x = end;
                }
            }

            for (int x = 0; x < board.Width; x++)
            {
                int y = 0;
                while (y < board.Height)
                {
                    var cell = board.At(x, y);
                    PieceKind kind = cell != null && cell.HasPiece ? cell.Piece : PieceKind.None;
                    if (kind == PieceKind.None)
                    {
                        y++;
                        continue;
                    }

                    int end = y + 1;
                    while (end < board.Height)
                    {
                        var next = board.At(x, end);
                        if (next == null || !next.HasPiece || next.Piece != kind) break;
                        end++;
                    }

                    int length = end - y;
                    if (length >= 3)
                        runs.Add(new MatchRun
                        {
                            Start = new CellPos(x, y), Length = length, Horizontal = false, Piece = kind
                        });
                    y = end;
                }
            }

            return runs;
        }

        public static bool HasMatch(Board board) => FindRuns(board).Count > 0;

        /// <summary>2x2 blocks of one piece kind. Four in a square makes a Spinner.</summary>
        public static List<CellPos> FindSquares(Board board)
        {
            var squares = new List<CellPos>();
            for (int y = 0; y < board.Height - 1; y++)
            {
                for (int x = 0; x < board.Width - 1; x++)
                {
                    var a = board.At(x, y);
                    var b = board.At(x + 1, y);
                    var c = board.At(x, y + 1);
                    var d = board.At(x + 1, y + 1);
                    if (a == null || b == null || c == null || d == null) continue;
                    if (!a.HasPiece || !b.HasPiece || !c.HasPiece || !d.HasPiece) continue;
                    if (a.Piece != b.Piece || a.Piece != c.Piece || a.Piece != d.Piece) continue;
                    squares.Add(new CellPos(x, y));
                }
            }
            return squares;
        }

        /// <summary>Groups runs that share a cell; a run crossing another is one shape (L / T).</summary>
        public static List<MatchCluster> BuildClusters(List<MatchRun> runs)
        {
            var clusters = new List<MatchCluster>();
            for (int i = 0; i < runs.Count; i++)
            {
                MatchCluster target = null;
                for (int c = 0; c < clusters.Count; c++)
                {
                    for (int j = 0; j < runs[i].Length; j++)
                    {
                        if (clusters[c].Contains(runs[i].CellAt(j)))
                        {
                            target = clusters[c];
                            break;
                        }
                    }
                    if (target != null) break;
                }

                if (target == null)
                {
                    target = new MatchCluster();
                    clusters.Add(target);
                }
                target.Add(runs[i]);
            }
            return clusters;
        }

        /// <summary>What the cluster earns: L/T → Dynamite, 5 line → Electro Ball, square → Spinner, 4 → Rocket.</summary>
        public static PowerUpKind PowerUpFor(MatchCluster cluster)
        {
            if (cluster.HasHorizontal && cluster.HasVertical) return PowerUpKind.Dynamite;
            if (cluster.HasSquare) return PowerUpKind.Spinner;
            if (cluster.MaxLength >= 5) return PowerUpKind.ElectroBall;
            if (cluster.MaxLength == 4)
            {
                for (int i = 0; i < cluster.Runs.Count; i++)
                    if (cluster.Runs[i].Length == 4)
                        return cluster.Runs[i].Horizontal ? PowerUpKind.RocketVertical : PowerUpKind.RocketHorizontal;
            }
            return PowerUpKind.None;
        }

        /// <summary>The cell the power-up appears on: the cell the player moved into, else the middle of the longest run.</summary>
        public static CellPos ChooseSpawnCell(MatchCluster cluster, CellPos preferred, bool hasPreferred)
        {
            if (hasPreferred && cluster.Contains(preferred)) return preferred;

            MatchRun longest = cluster.Runs[0];
            for (int i = 1; i < cluster.Runs.Count; i++)
                if (cluster.Runs[i].Length > longest.Length) longest = cluster.Runs[i];

            return longest.CellAt(longest.Length / 2);
        }

        /// <summary>Is there any legal swap left? False means the board must be reshuffled.</summary>
        public static bool HasPossibleMove(Board board)
        {
            for (int y = 0; y < board.Height; y++)
            {
                for (int x = 0; x < board.Width; x++)
                {
                    var cell = board.At(x, y);
                    if (cell == null || !cell.HasPiece) continue;
                    if (cell.PowerUp != PowerUpKind.None) return true; // a power-up can always be swapped

                    if (x + 1 < board.Width && SwapCreatesMatch(board, x, y, x + 1, y)) return true;
                    if (y + 1 < board.Height && SwapCreatesMatch(board, x, y, x, y + 1)) return true;
                }
            }
            return false;
        }

        static bool SwapCreatesMatch(Board board, int ax, int ay, int bx, int by)
        {
            var a = board.At(ax, ay);
            var b = board.At(bx, by);
            if (a == null || b == null || !a.HasPiece || !b.HasPiece) return false;
            if (a.Piece == b.Piece) return false;

            SwapPieces(a, b);
            bool match = HasMatch(board);
            SwapPieces(a, b);
            return match;
        }

        internal static void SwapPieces(Cell a, Cell b)
        {
            PieceKind p = a.Piece;
            PowerUpKind u = a.PowerUp;
            a.Piece = b.Piece;
            a.PowerUp = b.PowerUp;
            b.Piece = p;
            b.PowerUp = u;
        }
    }
}
