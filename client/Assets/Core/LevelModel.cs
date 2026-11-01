using System.Collections.Generic;

namespace Shazdeh.Core
{
    public sealed class ObstacleSpec
    {
        public int X;
        public int Y;
        public ObstacleKind Kind;
        public int Layers = 1;

        public ObstacleSpec() { }

        public ObstacleSpec(int x, int y, ObstacleKind kind, int layers)
        {
            X = x;
            Y = y;
            Kind = kind;
            Layers = layers;
        }
    }

    /// <summary>
    /// The engine's view of a level. Content (JSON) is parsed into this by Shazdeh.Content;
    /// Core never parses text, so it stays engine-free and testable.
    /// </summary>
    public sealed class LevelDefinition
    {
        public string Id = "";
        public int Number;
        public string Chapter = "ch01";
        public string Type = "normal";
        public int Width = 9;
        public int Height = 9;
        public GravityDirection Gravity = GravityDirection.Down;
        public int MoveLimit = 20;
        public int StageCount = 1;

        public readonly List<PieceKind> Pieces = new List<PieceKind>();
        public readonly List<GoalDefinition> Goals = new List<GoalDefinition>();
        public readonly List<ObstacleSpec> Obstacles = new List<ObstacleSpec>();
        public readonly List<CellPos> Blocked = new List<CellPos>();

        public int RewardPotions;
        public int RewardCoins;

        public const int MinBoardSide = 7;
        public const int MaxBoardSide = 10;

        public bool IsBoss => Type == "kingdom" || Type == "dark_kingdom";

        public bool IsHard => Type == "hard" || Type == "super_hard";

        /// <summary>Cheap structural check. Shazdeh.Content has the strict, user-facing validator.</summary>
        public bool IsStructurallyValid()
        {
            if (Width < MinBoardSide || Width > MaxBoardSide) return false;
            if (Height < MinBoardSide || Height > MaxBoardSide) return false;
            if (MoveLimit < 5 || MoveLimit > 100) return false;
            if (Pieces.Count < 4 || Pieces.Count > 6) return false;
            if (Goals.Count == 0) return false;
            for (int i = 0; i < Goals.Count; i++)
                if (Goals[i] == null || Goals[i].Target <= 0) return false;
            for (int i = 0; i < Obstacles.Count; i++)
            {
                var o = Obstacles[i];
                if (o == null) return false;
                if (o.X < 0 || o.Y < 0 || o.X >= Width || o.Y >= Height) return false;
                if (o.Kind == ObstacleKind.None || o.Layers < 1) return false;
            }
            return true;
        }

    }
}
