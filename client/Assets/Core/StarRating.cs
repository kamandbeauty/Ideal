using System;

namespace Shazdeh.Core
{
    /// <summary>
    /// How many stars a cleared level is worth, and nothing else.
    ///
    /// The rule is deliberately arithmetic: clearing is one star, and the remaining two come from how
    /// much of the move budget was still unspent (a quarter, then a half). That means a star is not a
    /// value we have to store — it is a function of <see cref="LevelRecord.bestMovesLeft"/>, so a save
    /// written by an older build still reports the right count, and the server can recompute a
    /// client's claim from the replay it already validates.
    ///
    /// The thresholds are exact fractions rounded up, computed in integers. A level with 10 moves pays
    /// its second star at 3 left and its third at 5; no floating point is involved, so the same
    /// numbers come out on every device.
    /// </summary>
    public static class StarRating
    {
        public const int Max = 3;
        public const int Min = 1;

        /// <summary>Moves left, as a percentage of the level's budget, that earns the second star.</summary>
        public const int SecondAtPercent = 25;

        /// <summary>Moves left, as a percentage of the budget, that earns the third star.</summary>
        public const int ThirdAtPercent = 50;

        /// <summary>Stars for a finished attempt. A loss is worth nothing.</summary>
        public static int FromRun(LevelRun run)
        {
            if (run == null || run.Level == null) return 0;
            if (run.Status != LevelStatus.Won) return 0;
            return FromMoves(run.Level.MoveLimit, run.MovesLeft);
        }

        /// <summary>
        /// Stars for a cleared level, from its move budget and the moves that were left over. The
        /// caller is stating that the level was cleared: a run that ends with no moves left is still
        /// one star, because it was still cleared.
        /// </summary>
        public static int FromMoves(int moveLimit, int movesLeft)
        {
            if (movesLeft < 0) movesLeft = 0;
            if (moveLimit <= 0) return Min;

            int stars = Min;
            TwoStarAt(moveLimit, out int second, out int third);
            if (movesLeft >= second) stars++;
            if (movesLeft >= third) stars++;
            return stars;
        }

        /// <summary>The best a record has ever scored, or 0 when it has never been cleared.</summary>
        public static int FromRecord(LevelRecord record, int moveLimit)
        {
            if (record == null || !record.cleared) return 0;
            return FromMoves(moveLimit, record.bestMovesLeft);
        }

        /// <summary>Moves left needed for two stars, and for three. Rounded up, never below one.</summary>
        public static void TwoStarAt(int moveLimit, out int second, out int third)
        {
            if (moveLimit <= 0)
            {
                second = 0;
                third = 0;
                return;
            }

            second = Math.Max(1, (int)(((long)moveLimit * SecondAtPercent + 99) / 100));
            third = Math.Max(second, (int)(((long)moveLimit * ThirdAtPercent + 99) / 100));
        }

        /// <summary>
        /// "۳ ستاره" and friends, for a label that has to say what the current attempt is worth.
        /// Persian numerals, one word, no plural rule to get wrong.
        /// </summary>
        public static string Describe(int stars)
        {
            if (stars < 0) stars = 0;
            if (stars > Max) stars = Max;
            return Text.PersianText.Number(stars) + " ستاره";
        }
    }
}
