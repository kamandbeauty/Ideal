using System.Collections.Generic;

namespace Shazdeh.Core
{
    /// <summary>
    /// One play of one level: the board, the goals, the moves left and the outcome.
    /// The API server replays the recorded moves through this same class before it grants a reward,
    /// so a modified client cannot invent a win.
    /// </summary>
    public sealed class LevelRun
    {
        public LevelDefinition Level { get; }

        public Board Board { get; }

        public GoalTracker Goals { get; }

        public ulong Seed { get; }

        public DeterministicRandom Random { get; }

        public int MovesLeft { get; private set; }

        public int MovesUsed { get; private set; }

        public int PotionsEarned { get; private set; }

        public int CoinsEarned { get; private set; }

        public LevelStatus Status { get; private set; }

        /// <summary>Power-ups the player spent this level (in-game boosters are inventory, not moves).</summary>
        public readonly List<BoosterKind> BoostersUsed = new List<BoosterKind>();

        readonly MoveResolver _resolver;

        public LevelRun(LevelDefinition level, ulong seed)
        {
            Level = level;
            Seed = seed;
            MovesLeft = level.MoveLimit;
            Status = LevelStatus.Playing;

            Board = BoardFactory.Create(level, seed);

            // A separate stream for in-level effects keeps the board layout reproducible even if a
            // power-up consumes a different number of random numbers than it used to.
            Random = new DeterministicRandom(seed ^ 0x51ED270BUL);
            Goals = new GoalTracker(level.Goals);
            _resolver = new MoveResolver(level, Board, Random, Goals);

            if (!MatchFinder.HasPossibleMove(Board)) BoardFactory.Reshuffle(Board, level.Pieces, Random);
        }

        public MoveResult TrySwap(int fromX, int fromY, int toX, int toY)
        {
            if (Status != LevelStatus.Playing)
                return MoveResult.Rejected(MoveKind.Swap, "level already finished");
            if (MovesLeft <= 0)
                return MoveResult.Rejected(MoveKind.Swap, "no moves left");

            var result = _resolver.Swap(new CellPos(fromX, fromY), new CellPos(toX, toY));
            if (!result.Accepted) return result;

            MovesLeft--;
            MovesUsed++;
            Evaluate();
            return result;
        }

        public MoveResult UseBooster(BoosterKind kind, int x, int y)
        {
            if (Status != LevelStatus.Playing)
                return MoveResult.Rejected(MoveKind.Booster, "level already finished");

            var result = _resolver.UseBooster(kind, new CellPos(x, y));
            if (!result.Accepted) return result;

            BoostersUsed.Add(kind);
            Evaluate();
            return result;
        }

        /// <summary>
        /// Takes the last use of this booster back out of the record. The board accepts any in-bounds
        /// target, so a booster fired at a cell with nothing to clear comes back as "accepted" with no
        /// events; the caller refunds it, and this keeps <see cref="BoostersUsed"/> — and the replay hash
        /// a server would validate — from claiming a booster that did nothing.
        /// </summary>
        public void RevertLastBooster(BoosterKind kind)
        {
            for (int i = BoostersUsed.Count - 1; i >= 0; i--)
            {
                if (BoostersUsed[i] != kind) continue;
                BoostersUsed.RemoveAt(i);
                return;
            }
        }

        void Evaluate()
        {
            if (Status != LevelStatus.Playing) return;

            if (Goals.AllComplete)
            {
                Status = LevelStatus.Won;
                PotionsEarned = Level.RewardPotions;
                CoinsEarned = Level.RewardCoins;
                return;
            }

            if (MovesLeft <= 0)
            {
                Status = LevelStatus.Lost;
                PotionsEarned = 0;
                CoinsEarned = 0;
            }
        }

        /// <summary>A short fingerprint of the whole run, used for replay validation and tests.</summary>
        public ulong StateHash() => StateHash.Compute(this);

        public string GoalSummary()
        {
            var parts = new List<string>();
            for (int i = 0; i < Goals.Count; i++)
                parts.Add(Goals.Progress(i) + "/" + Goals.Target(i));
            return string.Join(" ", parts.ToArray());
        }
    }
}
