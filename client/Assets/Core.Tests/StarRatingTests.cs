using NUnit.Framework;

namespace Shazdeh.Core.Tests
{
    public sealed class StarRatingTests
    {
        static LevelDefinition MakeLevel(int moveLimit, int target)
        {
            var level = new LevelDefinition
            {
                Id = "stars-test", Number = 1, Width = 9, Height = 9, MoveLimit = moveLimit,
                Type = "normal", RewardPotions = 10, RewardCoins = 10
            };
            level.Pieces.Add(PieceKind.Firouzeh);
            level.Pieces.Add(PieceKind.Lajvard);
            level.Pieces.Add(PieceKind.Aqiq);
            level.Pieces.Add(PieceKind.Zomorrod);
            level.Pieces.Add(PieceKind.Morvarid);
            level.Goals.Add(new GoalDefinition(GoalKind.ClearPieces, PieceKind.Firouzeh, target));
            return level;
        }

        [Test]
        public void ThresholdsAreTheQuarterAndTheHalf_RoundedUp()
        {
            StarRating.TwoStarAt(10, out int second, out int third);
            Assert.AreEqual(3, second, "25% of 10 is 2.5, which a player reaches at 3");
            Assert.AreEqual(5, third);

            StarRating.TwoStarAt(16, out second, out third);
            Assert.AreEqual(4, second);
            Assert.AreEqual(8, third);

            // A level so short that both thresholds round up to the same move still pays three stars
            // for a perfect clear rather than two.
            StarRating.TwoStarAt(2, out second, out third);
            Assert.AreEqual(1, second);
            Assert.AreEqual(1, third);
        }

        [Test]
        public void OneStarForAClearAndTwoMoreForMovesLeftOver()
        {
            Assert.AreEqual(1, StarRating.FromMoves(10, 0), "cleared with the last move");
            Assert.AreEqual(1, StarRating.FromMoves(10, 2));
            Assert.AreEqual(2, StarRating.FromMoves(10, 3));
            Assert.AreEqual(2, StarRating.FromMoves(10, 4));
            Assert.AreEqual(3, StarRating.FromMoves(10, 5));
            Assert.AreEqual(3, StarRating.FromMoves(10, 10), "an untouched budget");
        }

        [Test]
        public void StarsNeverLeaveTheRange_WhateverTheInputs()
        {
            for (int limit = 0; limit <= 40; limit++)
            {
                for (int left = -3; left <= limit + 3; left++)
                {
                    int stars = StarRating.FromMoves(limit, left);
                    Assert.GreaterOrEqual(stars, StarRating.Min, "limit " + limit + " left " + left);
                    Assert.LessOrEqual(stars, StarRating.Max, "limit " + limit + " left " + left);
                }
            }
        }

        [Test]
        public void MoreMovesLeftNeverMeansFewerStars()
        {
            for (int limit = 1; limit <= 40; limit++)
            {
                int previous = 0;
                for (int left = 0; left <= limit; left++)
                {
                    int stars = StarRating.FromMoves(limit, left);
                    Assert.GreaterOrEqual(stars, previous, "limit " + limit + " left " + left);
                    previous = stars;
                }
                Assert.AreEqual(StarRating.Max, previous, "limit " + limit + " must be reachable");
            }
        }

        [Test]
        public void APlayedRunIsWorthNothing_UntilItIsWon()
        {
            var run = new LevelRun(MakeLevel(60, 3), 777UL);
            Assert.AreEqual(LevelStatus.Playing, run.Status);

            int x1, y1, x2, y2;
            if (MoveResolverTests.TryFindSwap(run.Board, out x1, out y1, out x2, out y2))
                run.TrySwap(x1, y1, x2, y2);

            Assert.AreEqual(0, StarRating.FromRun(run), "a run still in progress is worth zero stars");
            Assert.AreEqual(0, StarRating.FromRun(null));
        }

        [Test]
        public void AWonRunReportsTheStarsItsBudgetEarned()
        {
            var level = MakeLevel(60, 3);
            var run = new LevelRun(level, 777);

            for (int i = 0; i < 120 && run.Status == LevelStatus.Playing; i++)
            {
                int x1, y1, x2, y2;
                if (!MoveResolverTests.TryFindSwap(run.Board, out x1, out y1, out x2, out y2)) break;
                run.TrySwap(x1, y1, x2, y2);
            }

            Assert.AreEqual(LevelStatus.Won, run.Status);
            Assert.GreaterOrEqual(run.MovesLeft, 30, "three pieces in a 60-move level is a generous clear");
            Assert.AreEqual(StarRating.Max, StarRating.FromRun(run));
            Assert.AreEqual(StarRating.FromMoves(level.MoveLimit, run.MovesLeft), StarRating.FromRun(run));
        }

        [Test]
        public void ARecordReportsItsBestStars_AndAnUnclearedLevelReportsNone()
        {
            var level = MakeLevel(12, 4);
            var record = new LevelRecord { number = 1 };

            Assert.AreEqual(0, record.Stars(level.MoveLimit), "never cleared");
            Assert.AreEqual(0, StarRating.FromRecord(record, level.MoveLimit));

            record.cleared = true;
            record.bestMovesLeft = 2;
            Assert.AreEqual(1, record.Stars(level.MoveLimit));

            StarRating.TwoStarAt(level.MoveLimit, out int second, out int third);
            record.bestMovesLeft = second;
            Assert.AreEqual(2, record.Stars(level.MoveLimit), "the second star at the quarter mark");

            record.bestMovesLeft = third;
            Assert.AreEqual(3, record.Stars(level.MoveLimit), "the third star at the half mark");
        }

        [Test]
        public void DescribeUsesPersianNumerals()
        {
            Assert.AreEqual("۳ ستاره", StarRating.Describe(3));
            Assert.AreEqual("۰ ستاره", StarRating.Describe(0));
            Assert.AreEqual("۳ ستاره", StarRating.Describe(9), "clamped, never '۹ ستاره'");
        }
    }
}
