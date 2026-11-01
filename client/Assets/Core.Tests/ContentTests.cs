using System.Collections.Generic;
using NUnit.Framework;
using Shazdeh.Content;
using UnityEngine;

namespace Shazdeh.Core.Tests
{
    /// <summary>
    /// Content is code: every shipped level must parse, validate and load, or the build is broken.
    /// These tests read the same Resources the game reads, so a file that the editor can see but the
    /// player cannot is caught here.
    /// </summary>
    public sealed class ContentTests
    {
        const string Folder = "levels/ch01";
        const int LevelCount = 10;

        static List<LevelDefinition> LoadAll()
        {
            var levels = new List<LevelDefinition>();
            for (int n = 1; n <= LevelCount; n++)
            {
                string path = Folder + "/level-" + n.ToString("000");
                var asset = Resources.Load<TextAsset>(path);
                Assert.IsNotNull(asset, "missing level asset: " + path);

                var errors = new List<string>();
                var level = LevelParser.Parse(asset.text, errors);

                Assert.AreEqual(0, errors.Count, "parse errors in " + path + ": " + string.Join(", ", errors.ToArray()));
                Assert.IsNotNull(level, "parser returned null for " + path);
                levels.Add(level);
            }
            return levels;
        }

        [Test]
        public void AllChapterOneLevelsParseAndValidate()
        {
            var levels = LoadAll();
            Assert.AreEqual(LevelCount, levels.Count);

            for (int i = 0; i < levels.Count; i++)
            {
                var errors = LevelValidator.Validate(levels[i]);
                Assert.AreEqual(0, errors.Count,
                    levels[i].Id + " has validation errors: " + string.Join(", ", errors.ToArray()));
            }

            var catalogErrors = LevelValidator.ValidateCatalog(levels);
            Assert.AreEqual(0, catalogErrors.Count, string.Join(", ", catalogErrors.ToArray()));
        }

        [Test]
        public void EveryLevelBuildsAPlayableBoard()
        {
            var levels = LoadAll();
            for (int i = 0; i < levels.Count; i++)
            {
                var level = levels[i];
                for (ulong seed = 1; seed <= 5; seed++)
                {
                    var board = BoardFactory.Create(level, seed);
                    Assert.AreEqual(0, MatchFinder.FindRuns(board).Count,
                        level.Id + " seed " + seed + ": opening board already has matches");
                    Assert.IsTrue(MatchFinder.HasPossibleMove(board),
                        level.Id + " seed " + seed + ": opening board has no legal move");

                    var run = new LevelRun(level, seed);
                    Assert.AreEqual(LevelStatus.Playing, run.Status);

                    // a handful of legal moves must not throw or corrupt the board
                    for (int move = 0; move < 10; move++)
                    {
                        int x1, y1, x2, y2;
                        if (!MoveResolverTests.TryFindSwap(run.Board, out x1, out y1, out x2, out y2)) break;
                        run.TrySwap(x1, y1, x2, y2);
                        Assert.AreEqual(0, MatchFinder.FindRuns(run.Board).Count,
                            level.Id + ": matches survived a settled move");
                    }
                }
            }
        }

        [Test]
        public void GoalTargetsMatchTheObstaclesOnTheBoard()
        {
            var levels = LoadAll();
            for (int i = 0; i < levels.Count; i++)
            {
                var level = levels[i];
                for (int g = 0; g < level.Goals.Count; g++)
                {
                    var goal = level.Goals[g];
                    if (goal.Kind != GoalKind.ClearObstacle) continue;

                    int layers = 0;
                    for (int o = 0; o < level.Obstacles.Count; o++)
                        if (level.Obstacles[o].Kind == goal.Obstacle) layers += level.Obstacles[o].Layers;

                    Assert.AreEqual(layers, goal.Target,
                        level.Id + ": goal " + g + " wants " + goal.Target + " " + goal.Obstacle +
                        " hits but the board only has " + layers + " layers");
                }
            }
        }

        [Test]
        public void BadJsonComesBackAsErrorsNotAnException()
        {
            var errors = new List<string>();
            var level = LevelParser.Parse("{ this is not json", errors);

            Assert.IsNull(level);
            Assert.Greater(errors.Count, 0);
        }

        [Test]
        public void UnknownNamesAreReported()
        {
            const string json = @"{
                ""id"": ""bad-001"", ""number"": 1, ""type"": ""normal"",
                ""width"": 9, ""height"": 9, ""move_limit"": 20,
                ""pieces"": [""firouzeh"", ""lajvard"", ""aqiq"", ""zomorrod"", ""turquoise""],
                ""goals"": [{ ""kind"": ""clear_pieces"", ""piece"": ""aqiq"", ""target"": 3 }]
            }";

            var errors = new List<string>();
            var level = LevelParser.Parse(json, errors);

            Assert.IsNotNull(level);
            Assert.Greater(errors.Count, 0);
            Assert.IsTrue(errors[0].Contains("turquoise"));
        }

        [Test]
        public void ValidatorRejectsAGoalThatCannotBeMet()
        {
            var level = new LevelDefinition
            {
                Id = "bad-002", Number = 2, Width = 9, Height = 9, MoveLimit = 3, Type = "normal",
                RewardPotions = 1, RewardCoins = 1
            };
            level.Pieces.Add(PieceKind.Firouzeh);
            level.Pieces.Add(PieceKind.Lajvard);
            level.Pieces.Add(PieceKind.Aqiq);
            level.Pieces.Add(PieceKind.Zomorrod);
            level.Goals.Add(new GoalDefinition(GoalKind.ClearPieces, PieceKind.Aqiq, 200));

            var errors = LevelValidator.Validate(level);

            Assert.Greater(errors.Count, 0);
        }
    }
}
