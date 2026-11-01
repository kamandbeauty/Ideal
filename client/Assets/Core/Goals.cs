using System.Collections.Generic;

namespace Shazdeh.Core
{
    /// <summary>One level goal. Progress is tracked here and mirrored to the server on finish.</summary>
    public sealed class GoalDefinition
    {
        public GoalKind Kind;
        public PieceKind Piece;
        public ObstacleKind Obstacle;
        public int Target;

        public GoalDefinition() { }

        public GoalDefinition(GoalKind kind, PieceKind piece, int target)
        {
            Kind = kind;
            Piece = piece;
            Target = target;
        }

        public GoalDefinition(GoalKind kind, ObstacleKind obstacle, int target)
        {
            Kind = kind;
            Obstacle = obstacle;
            Target = target;
        }

        public string Describe()
        {
            if (Kind == GoalKind.ClearPieces) return "clear " + Target + " " + Piece;
            return "clear " + Target + " " + Obstacle;
        }
    }

    public sealed class GoalTracker
    {
        readonly GoalDefinition[] _goals;
        readonly int[] _progress;

        public GoalTracker(IReadOnlyList<GoalDefinition> goals)
        {
            int count = goals == null ? 0 : goals.Count;
            _goals = new GoalDefinition[count];
            _progress = new int[count];
            for (int i = 0; i < count; i++) _goals[i] = goals[i];
        }

        public int Count => _goals.Length;

        public GoalDefinition Goal(int index) => _goals[index];

        public int Progress(int index) => _progress[index];

        public int Target(int index) => _goals[index].Target;

        public bool IsComplete(int index) => _progress[index] >= _goals[index].Target;

        public bool AllComplete
        {
            get
            {
                if (_goals.Length == 0) return false;
                for (int i = 0; i < _goals.Length; i++) if (!IsComplete(i)) return false;
                return true;
            }
        }

        public int CompletedCount
        {
            get
            {
                int n = 0;
                for (int i = 0; i < _goals.Length; i++) if (IsComplete(i)) n++;
                return n;
            }
        }

        /// <summary>Call once per cleared piece. Returns the goal indexes that changed.</summary>
        public void RecordPieceCleared(PieceKind piece, List<int> changed)
        {
            for (int i = 0; i < _goals.Length; i++)
            {
                if (_goals[i].Kind != GoalKind.ClearPieces) continue;
                if (_goals[i].Piece != piece) continue;
                if (IsComplete(i)) continue;
                _progress[i]++;
                if (changed != null) changed.Add(i);
            }
        }

        /// <summary>Call once per obstacle layer destroyed.</summary>
        public void RecordObstacleLayer(ObstacleKind obstacle, List<int> changed)
        {
            for (int i = 0; i < _goals.Length; i++)
            {
                if (_goals[i].Kind != GoalKind.ClearObstacle) continue;
                if (_goals[i].Obstacle != obstacle) continue;
                if (IsComplete(i)) continue;
                _progress[i]++;
                if (changed != null) changed.Add(i);
            }
        }

        public void Snapshot(int[] into)
        {
            for (int i = 0; i < _progress.Length && i < into.Length; i++) into[i] = _progress[i];
        }
    }
}
