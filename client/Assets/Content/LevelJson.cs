using System;
using Shazdeh.Core;

namespace Shazdeh.Content
{
    // Field names mirror the JSON exactly (snake_case), because Newtonsoft binds by name and the
    // files are edited by humans and by tools/levels/gen_levels.py.

    [Serializable]
    public sealed class LevelJson
    {
        public string id;
        public int number;
        public string chapter;
        public string type;
        public int width = 9;
        public int height = 9;
        public string gravity = "down";
        public int move_limit = 20;
        public string[] pieces;
        public GoalJson[] goals;
        public ObstacleJson[] obstacles;
        public string[] blocked;
        public int reward_potions;
        public int reward_coins;
        public int stages = 1;
        public string notes;
    }

    [Serializable]
    public sealed class GoalJson
    {
        public string kind;
        public string piece;
        public string obstacle;
        public int target;
    }

    [Serializable]
    public sealed class ObstacleJson
    {
        public int x;
        public int y;
        public string kind;
        public int layers = 1;
    }

    /// <summary>Name ↔ enum mapping, in one place. JSON uses names, never ordinals.</summary>
    public static class Names
    {
        public static bool TryPiece(string name, out PieceKind kind)
        {
            kind = PieceKind.None;
            if (string.IsNullOrEmpty(name)) return false;
            switch (name.Trim().ToLowerInvariant())
            {
                case "firouzeh": kind = PieceKind.Firouzeh; return true;
                case "lajvard": kind = PieceKind.Lajvard; return true;
                case "aqiq": kind = PieceKind.Aqiq; return true;
                case "zomorrod": kind = PieceKind.Zomorrod; return true;
                case "morvarid": kind = PieceKind.Morvarid; return true;
                default: return false;
            }
        }

        public static string PieceName(PieceKind kind)
        {
            switch (kind)
            {
                case PieceKind.Firouzeh: return "firouzeh";
                case PieceKind.Lajvard: return "lajvard";
                case PieceKind.Aqiq: return "aqiq";
                case PieceKind.Zomorrod: return "zomorrod";
                case PieceKind.Morvarid: return "morvarid";
                default: return "none";
            }
        }

        public static bool TryObstacle(string name, out ObstacleKind kind)
        {
            kind = ObstacleKind.None;
            if (string.IsNullOrEmpty(name)) return false;
            switch (name.Trim().ToLowerInvariant())
            {
                case "crate": kind = ObstacleKind.Crate; return true;
                case "frost": kind = ObstacleKind.Frost; return true;
                case "ivy": kind = ObstacleKind.Ivy; return true;
                case "vial": kind = ObstacleKind.Vial; return true;
                case "samovar": kind = ObstacleKind.Samovar; return true;
                case "flower_pot": kind = ObstacleKind.FlowerPot; return true;
                case "chain": kind = ObstacleKind.Chain; return true;
                case "seal": kind = ObstacleKind.Seal; return true;
                default: return false;
            }
        }

        public static bool TryGoalKind(string name, out GoalKind kind)
        {
            kind = GoalKind.ClearPieces;
            if (string.IsNullOrEmpty(name)) return false;
            switch (name.Trim().ToLowerInvariant())
            {
                case "clear_pieces": kind = GoalKind.ClearPieces; return true;
                case "clear_obstacle": kind = GoalKind.ClearObstacle; return true;
                default: return false;
            }
        }

        public static bool TryLevelType(string name, out string normalized)
        {
            normalized = "normal";
            if (string.IsNullOrEmpty(name)) return false;
            switch (name.Trim().ToLowerInvariant())
            {
                case "normal": normalized = "normal"; return true;
                case "hard": normalized = "hard"; return true;
                case "super_hard": normalized = "super_hard"; return true;
                case "kingdom": normalized = "kingdom"; return true;
                case "dark_kingdom": normalized = "dark_kingdom"; return true;
                default: return false;
            }
        }
    }
}
