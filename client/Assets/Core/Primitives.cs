using System;

namespace Shazdeh.Core
{
    /// <summary>The five stones. Order is stable: it is part of the RNG contract and of the
    /// colour-blind emblem mapping, so never reorder these values.</summary>
    public enum PieceKind : byte
    {
        None = 0,
        Firouzeh = 1,   // round turquoise cabochon
        Lajvard = 2,    // eight-point lapis star
        Aqiq = 3,       // carnelian shield
        Zomorrod = 4,   // emerald octagon
        Morvarid = 5    // pearl drop
    }

    public enum PowerUpKind : byte
    {
        None = 0,
        RocketVertical = 1,    // clears its column (made by a horizontal match of four)
        RocketHorizontal = 2,  // clears its row (made by a vertical match of four)
        Spinner = 3,           // clears a cell and its neighbours
        Dynamite = 4,          // clears a small square
        ElectroBall = 5,       // clears one piece kind
        SuperElectroBall = 6   // clears every piece
    }

    public enum ObstacleKind : byte
    {
        None = 0,
        Crate = 1,
        Frost = 2,
        Ivy = 3,
        Vial = 4,
        Samovar = 5,
        FlowerPot = 6,
        Chain = 7,
        Seal = 8
    }

    public enum GoalKind : byte
    {
        ClearPieces = 0,
        ClearObstacle = 1
    }

    public enum GravityDirection : byte
    {
        Down = 0,
        Up = 1
    }

    public enum LevelStatus : byte
    {
        Playing = 0,
        Won = 1,
        Lost = 2
    }

    public enum BoosterKind : byte
    {
        Mallet = 0,    // one tile
        Ram = 1,       // a row
        Auger = 2,     // a column
        Whirlwind = 3, // shuffle
        Falcon = 4     // three small blasts
    }

    public enum MoveKind : byte
    {
        Rejected = 0,
        Swap = 1,
        Booster = 2
    }

    /// <summary>A grid coordinate. Struct so it can be a dictionary key without allocating.</summary>
    public readonly struct CellPos : IEquatable<CellPos>
    {
        public readonly int X;
        public readonly int Y;

        public CellPos(int x, int y)
        {
            X = x;
            Y = y;
        }

        public bool Equals(CellPos other) => X == other.X && Y == other.Y;

        public override bool Equals(object obj) => obj is CellPos other && Equals(other);

        public override int GetHashCode() => (X * 397) ^ Y;

        public override string ToString() => "(" + X + "," + Y + ")";

        public static bool operator ==(CellPos a, CellPos b) => a.Equals(b);

        public static bool operator !=(CellPos a, CellPos b) => !a.Equals(b);
    }

    /// <summary>One square of the board. A cell may hold a piece, a power-up on that piece,
    /// and an obstacle layer underneath it.</summary>
    public sealed class Cell
    {
        public PieceKind Piece;
        public PowerUpKind PowerUp;
        public ObstacleKind Obstacle;
        public int ObstacleLayers;

        /// <summary>Blocked cells never hold a piece and are never refilled.</summary>
        public bool Blocked;

        public bool HasPiece => Piece != PieceKind.None;

        public bool HasObstacle => Obstacle != ObstacleKind.None && ObstacleLayers > 0;

        public void ClearPiece()
        {
            Piece = PieceKind.None;
            PowerUp = PowerUpKind.None;
        }

        public void SetObstacle(ObstacleKind kind, int layers)
        {
            Obstacle = kind;
            ObstacleLayers = kind == ObstacleKind.None ? 0 : Math.Max(1, layers);
        }

        public Cell Copy() => new Cell
        {
            Piece = Piece,
            PowerUp = PowerUp,
            Obstacle = Obstacle,
            ObstacleLayers = ObstacleLayers,
            Blocked = Blocked
        };
    }
}
