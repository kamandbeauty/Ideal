using System.Collections.Generic;

namespace Shazdeh.Core
{
    /// <summary>
    /// What happened during a move, in the order it happened. The view animates this list; it never
    /// inspects the board to guess what changed, and the server can store it for replays.
    /// </summary>
    public abstract class BoardEvent
    {
    }

    public sealed class PieceClearedEvent : BoardEvent
    {
        public CellPos Position;
        public PieceKind Piece;
        public PowerUpKind PowerUp;
    }

    public sealed class PowerUpCreatedEvent : BoardEvent
    {
        public CellPos Position;
        public PowerUpKind Kind;
        public PieceKind Piece;
    }

    public sealed class PowerUpTriggeredEvent : BoardEvent
    {
        public CellPos Position;
        public PowerUpKind Kind;
    }

    public sealed class ObstacleHitEvent : BoardEvent
    {
        public CellPos Position;
        public ObstacleKind Kind;
        public int LayersLeft;
        public bool Destroyed;
    }

    public sealed class GoalProgressEvent : BoardEvent
    {
        public int Index;
        public int Progress;
        public int Target;
        public bool Complete;
    }

    public sealed class CascadeEvent : BoardEvent
    {
        public int Index;
    }

    public sealed class BoardReshuffledEvent : BoardEvent
    {
    }

    public sealed class MoveRejectedEvent : BoardEvent
    {
        public string Reason;
    }

    public sealed class MoveResult
    {
        public MoveKind Kind = MoveKind.Rejected;
        public bool Accepted;
        public string RejectReason;

        public readonly List<BoardEvent> Events = new List<BoardEvent>();

        public int PiecesCleared;
        public int PowerUpsCreated;
        public int Cascades;
        public int ObstaclesDestroyed;

        public static MoveResult Rejected(MoveKind kind, string reason)
        {
            var result = new MoveResult { Kind = kind, Accepted = false, RejectReason = reason };
            result.Events.Add(new MoveRejectedEvent { Reason = reason });
            return result;
        }
    }
}
