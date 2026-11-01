using System.Collections.Generic;
using Shazdeh.Core;

namespace Shazdeh.Content
{
    /// <summary>
    /// The rules content must obey before it can ship. Runs in the editor (menu) and in tests, so a
    /// designer cannot push a level the engine will choke on.
    /// </summary>
    public static class LevelValidator
    {
        public const int MinGoalTarget = 1;
        public const int MaxGoalTarget = 200;
        public const int MinMoveLimit = 5;
        public const int MaxMoveLimit = 100;
        public const int MaxGoals = 3;
        public const int MaxObstacleLayers = 4;

        public static List<string> Validate(LevelDefinition level)
        {
            var errors = new List<string>();
            if (level == null)
            {
                errors.Add("level is null");
                return errors;
            }

            string tag = string.IsNullOrEmpty(level.Id) ? "level " + level.Number : level.Id;

            if (string.IsNullOrEmpty(level.Id)) errors.Add(tag + ": id is required");
            if (level.Number < 1) errors.Add(tag + ": number must be >= 1");
            if (level.Width < LevelDefinition.MinBoardSide || level.Width > LevelDefinition.MaxBoardSide)
                errors.Add(tag + ": width must be " + LevelDefinition.MinBoardSide + ".." + LevelDefinition.MaxBoardSide);
            if (level.Height < LevelDefinition.MinBoardSide || level.Height > LevelDefinition.MaxBoardSide)
                errors.Add(tag + ": height must be " + LevelDefinition.MinBoardSide + ".." + LevelDefinition.MaxBoardSide);
            if (level.MoveLimit < MinMoveLimit || level.MoveLimit > MaxMoveLimit)
                errors.Add(tag + ": move_limit must be " + MinMoveLimit + ".." + MaxMoveLimit);

            if (level.Pieces.Count < 4 || level.Pieces.Count > 6)
                errors.Add(tag + ": needs 4..6 piece kinds, has " + level.Pieces.Count);
            var seenKinds = new HashSet<PieceKind>();
            for (int i = 0; i < level.Pieces.Count; i++)
                if (!seenKinds.Add(level.Pieces[i])) errors.Add(tag + ": duplicate piece kind " + level.Pieces[i]);

            if (level.Goals.Count == 0) errors.Add(tag + ": at least one goal is required");
            if (level.Goals.Count > MaxGoals) errors.Add(tag + ": at most " + MaxGoals + " goals");
            for (int i = 0; i < level.Goals.Count; i++)
            {
                var goal = level.Goals[i];
                if (goal.Target < MinGoalTarget || goal.Target > MaxGoalTarget)
                    errors.Add(tag + ": goal " + i + " target must be " + MinGoalTarget + ".." + MaxGoalTarget);
                if (goal.Kind == GoalKind.ClearPieces && !level.Pieces.Contains(goal.Piece))
                    errors.Add(tag + ": goal " + i + " asks for a piece the level does not use (" + goal.Piece + ")");
                if (goal.Kind == GoalKind.ClearObstacle && CountObstacles(level, goal.Obstacle) == 0)
                    errors.Add(tag + ": goal " + i + " asks for an obstacle that is not on the board (" + goal.Obstacle + ")");
            }

            var occupied = new HashSet<CellPos>();
            for (int i = 0; i < level.Obstacles.Count; i++)
            {
                var o = level.Obstacles[i];
                if (o.X < 0 || o.Y < 0 || o.X >= level.Width || o.Y >= level.Height)
                    errors.Add(tag + ": obstacle " + i + " is out of bounds (" + o.X + "," + o.Y + ")");
                else if (!occupied.Add(new CellPos(o.X, o.Y)))
                    errors.Add(tag + ": two obstacles on the same cell (" + o.X + "," + o.Y + ")");
                if (o.Layers < 1 || o.Layers > MaxObstacleLayers)
                    errors.Add(tag + ": obstacle " + i + " layers must be 1.." + MaxObstacleLayers);
            }

            var blocked = new HashSet<CellPos>();
            for (int i = 0; i < level.Blocked.Count; i++)
            {
                var p = level.Blocked[i];
                if (p.X < 0 || p.Y < 0 || p.X >= level.Width || p.Y >= level.Height)
                    errors.Add(tag + ": blocked cell out of bounds " + p);
                else if (!blocked.Add(p))
                    errors.Add(tag + ": duplicate blocked cell " + p);
                else if (occupied.Contains(p))
                    errors.Add(tag + ": blocked cell also holds an obstacle " + p);
            }

            if (level.RewardPotions < 0 || level.RewardPotions > 500)
                errors.Add(tag + ": reward_potions must be 0..500");
            if (level.RewardCoins < 0 || level.RewardCoins > 1000)
                errors.Add(tag + ": reward_coins must be 0..1000");

            // A level whose goals cannot physically be reached in its move budget is a design bug,
            // not an engine bug: a move clears roughly 3-15 pieces, so demand at least that much room.
            int totalPieceGoal = 0;
            for (int i = 0; i < level.Goals.Count; i++)
                if (level.Goals[i].Kind == GoalKind.ClearPieces) totalPieceGoal += level.Goals[i].Target;

            int roughCapacity = level.MoveLimit * 15;
            if (totalPieceGoal > roughCapacity)
                errors.Add(tag + ": goals ask for " + totalPieceGoal + " pieces but " + level.MoveLimit +
                           " moves can realistically clear about " + roughCapacity);

            return errors;
        }

        static int CountObstacles(LevelDefinition level, ObstacleKind kind)
        {
            int layers = 0;
            for (int i = 0; i < level.Obstacles.Count; i++)
                if (level.Obstacles[i].Kind == kind) layers += level.Obstacles[i].Layers;
            return layers;
        }

        /// <summary>Catalog-level rules: unique ids, unique numbers, no gaps.</summary>
        public static List<string> ValidateCatalog(IList<LevelDefinition> levels)
        {
            var errors = new List<string>();
            if (levels == null || levels.Count == 0)
            {
                errors.Add("catalog is empty");
                return errors;
            }

            var ids = new HashSet<string>();
            var numbers = new HashSet<int>();
            for (int i = 0; i < levels.Count; i++)
            {
                var level = levels[i];
                if (level == null) continue;
                if (!ids.Add(level.Id)) errors.Add("duplicate level id '" + level.Id + "'");
                if (!numbers.Add(level.Number)) errors.Add("duplicate level number " + level.Number);
            }

            for (int n = 1; n <= levels.Count; n++)
                if (!numbers.Contains(n)) errors.Add("missing level number " + n);

            return errors;
        }
    }
}
