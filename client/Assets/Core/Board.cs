using System.Collections.Generic;
using System.Text;

namespace Shazdeh.Core
{
    /// <summary>The playfield. Row-major storage, y = 0 is the bottom row for Down gravity and the
    /// top row for Up gravity; the view flips only the drawing, never the model.</summary>
    public sealed class Board
    {
        readonly Cell[] _cells;

        public int Width { get; }

        public int Height { get; }

        public Board(int width, int height)
        {
            Width = width < 1 ? 1 : width;
            Height = height < 1 ? 1 : height;
            _cells = new Cell[Width * Height];
            for (int i = 0; i < _cells.Length; i++) _cells[i] = new Cell();
        }

        public Cell At(int x, int y)
        {
            if (!InBounds(x, y)) return null;
            return _cells[y * Width + x];
        }

        public Cell At(CellPos p) => At(p.X, p.Y);

        public bool InBounds(int x, int y) => x >= 0 && y >= 0 && x < Width && y < Height;

        public bool InBounds(CellPos p) => InBounds(p.X, p.Y);

        public Board Clone()
        {
            var copy = new Board(Width, Height);
            for (int i = 0; i < _cells.Length; i++) copy._cells[i] = _cells[i].Copy();
            return copy;
        }

        public void CopyFrom(Board other)
        {
            for (int i = 0; i < _cells.Length && i < other._cells.Length; i++)
                _cells[i] = other._cells[i].Copy();
        }

        /// <summary>Row-major, then column: deterministic order for anything that iterates the grid.</summary>
        public IEnumerable<CellPos> AllPositions()
        {
            for (int y = 0; y < Height; y++)
            for (int x = 0; x < Width; x++)
                yield return new CellPos(x, y);
        }

        /// <summary>
        /// Debug/test rendering. Uppercase = piece, power-ups are 'v','h','s','d','e','E',
        /// '.' = empty, '#' = blocked. Obstacles are not encoded; use the accessors for those.
        /// </summary>
        public string ToAscii()
        {
            var sb = new StringBuilder((Width + 1) * Height);
            for (int y = Height - 1; y >= 0; y--)
            {
                for (int x = 0; x < Width; x++)
                {
                    var c = At(x, y);
                    sb.Append(CharFor(c));
                }
                if (y > 0) sb.Append('\n');
            }
            return sb.ToString();
        }

        static char CharFor(Cell c)
        {
            if (c == null) return '?';
            if (c.Blocked) return '#';
            switch (c.PowerUp)
            {
                case PowerUpKind.RocketVertical: return 'v';
                case PowerUpKind.RocketHorizontal: return 'h';
                case PowerUpKind.Spinner: return 's';
                case PowerUpKind.Dynamite: return 'd';
                case PowerUpKind.ElectroBall: return 'e';
                case PowerUpKind.SuperElectroBall: return 'E';
            }
            switch (c.Piece)
            {
                case PieceKind.Firouzeh: return 'F';
                case PieceKind.Lajvard: return 'L';
                case PieceKind.Aqiq: return 'A';
                case PieceKind.Zomorrod: return 'Z';
                case PieceKind.Morvarid: return 'M';
                default: return '.';
            }
        }

        /// <summary>Build a board from text, top row first (the way a test reads it on screen).</summary>
        public static Board FromAscii(params string[] rows)
        {
            if (rows == null || rows.Length == 0) return new Board(1, 1);
            int height = rows.Length;
            int width = 0;
            for (int i = 0; i < rows.Length; i++) if (rows[i].Length > width) width = rows[i].Length;

            var board = new Board(width, height);
            for (int r = 0; r < height; r++)
            {
                string line = rows[r];
                int y = height - 1 - r;
                for (int x = 0; x < width; x++)
                {
                    char ch = x < line.Length ? line[x] : '.';
                    var cell = board.At(x, y);
                    switch (ch)
                    {
                        case 'F': cell.Piece = PieceKind.Firouzeh; break;
                        case 'L': cell.Piece = PieceKind.Lajvard; break;
                        case 'A': cell.Piece = PieceKind.Aqiq; break;
                        case 'Z': cell.Piece = PieceKind.Zomorrod; break;
                        case 'M': cell.Piece = PieceKind.Morvarid; break;
                        case 'v': cell.Piece = PieceKind.Lajvard; cell.PowerUp = PowerUpKind.RocketVertical; break;
                        case 'h': cell.Piece = PieceKind.Lajvard; cell.PowerUp = PowerUpKind.RocketHorizontal; break;
                        case 's': cell.Piece = PieceKind.Lajvard; cell.PowerUp = PowerUpKind.Spinner; break;
                        case 'd': cell.Piece = PieceKind.Lajvard; cell.PowerUp = PowerUpKind.Dynamite; break;
                        case 'e': cell.Piece = PieceKind.Lajvard; cell.PowerUp = PowerUpKind.ElectroBall; break;
                        case 'E': cell.Piece = PieceKind.Lajvard; cell.PowerUp = PowerUpKind.SuperElectroBall; break;
                        case '#': cell.Blocked = true; break;
                        default: cell.ClearPiece(); break;
                    }
                }
            }
            return board;
        }

        /// <summary>Count of cells currently holding a piece — used by tests and the goal tracker.</summary>
        public int CountPieces()
        {
            int n = 0;
            for (int i = 0; i < _cells.Length; i++) if (_cells[i].HasPiece) n++;
            return n;
        }
    }
}
