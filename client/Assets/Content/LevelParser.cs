using System.Collections.Generic;
using Newtonsoft.Json;
using Shazdeh.Core;

namespace Shazdeh.Content
{
    /// <summary>JSON → LevelDefinition. Never throws on bad content: errors come back in a list.</summary>
    public static class LevelParser
    {
        public static LevelDefinition Parse(string json, List<string> errors)
        {
            if (errors == null) errors = new List<string>();

            if (string.IsNullOrEmpty(json))
            {
                errors.Add("level json is empty");
                return null;
            }

            LevelJson dto;
            try
            {
                dto = JsonConvert.DeserializeObject<LevelJson>(json);
            }
            catch (JsonException ex)
            {
                errors.Add("invalid json: " + ex.Message);
                return null;
            }

            if (dto == null)
            {
                errors.Add("level json deserialized to null");
                return null;
            }

            return Convert(dto, errors);
        }

        static LevelDefinition Convert(LevelJson dto, List<string> errors)
        {
            var level = new LevelDefinition
            {
                Id = dto.id,
                Number = dto.number,
                Chapter = string.IsNullOrEmpty(dto.chapter) ? "ch01" : dto.chapter,
                Width = dto.width,
                Height = dto.height,
                MoveLimit = dto.move_limit,
                StageCount = dto.stages < 1 ? 1 : dto.stages,
                RewardPotions = dto.reward_potions,
                RewardCoins = dto.reward_coins
            };

            string type;
            if (Names.TryLevelType(dto.type, out type)) level.Type = type;
            else errors.Add("level " + dto.number + ": unknown type '" + dto.type + "'");

            if (!string.IsNullOrEmpty(dto.gravity) && dto.gravity.Trim().ToLowerInvariant() == "up")
                level.Gravity = GravityDirection.Up;

            if (dto.pieces != null)
            {
                for (int i = 0; i < dto.pieces.Length; i++)
                {
                    PieceKind kind;
                    if (Names.TryPiece(dto.pieces[i], out kind)) level.Pieces.Add(kind);
                    else errors.Add("level " + dto.number + ": unknown piece '" + dto.pieces[i] + "'");
                }
            }

            if (dto.goals != null)
            {
                for (int i = 0; i < dto.goals.Length; i++)
                {
                    var g = dto.goals[i];
                    if (g == null) continue;

                    GoalKind kind;
                    if (!Names.TryGoalKind(g.kind, out kind))
                    {
                        errors.Add("level " + dto.number + ": unknown goal kind '" + g.kind + "'");
                        continue;
                    }

                    if (kind == GoalKind.ClearPieces)
                    {
                        PieceKind piece;
                        if (!Names.TryPiece(g.piece, out piece))
                        {
                            errors.Add("level " + dto.number + ": goal piece '" + g.piece + "'");
                            continue;
                        }
                        level.Goals.Add(new GoalDefinition(kind, piece, g.target));
                    }
                    else
                    {
                        ObstacleKind obstacle;
                        if (!Names.TryObstacle(g.obstacle, out obstacle))
                        {
                            errors.Add("level " + dto.number + ": goal obstacle '" + g.obstacle + "'");
                            continue;
                        }
                        level.Goals.Add(new GoalDefinition(kind, obstacle, g.target));
                    }
                }
            }

            if (dto.obstacles != null)
            {
                for (int i = 0; i < dto.obstacles.Length; i++)
                {
                    var o = dto.obstacles[i];
                    if (o == null) continue;

                    ObstacleKind kind;
                    if (!Names.TryObstacle(o.kind, out kind))
                    {
                        errors.Add("level " + dto.number + ": unknown obstacle '" + o.kind + "'");
                        continue;
                    }
                    level.Obstacles.Add(new ObstacleSpec(o.x, o.y, kind, o.layers < 1 ? 1 : o.layers));
                }
            }

            if (dto.blocked != null)
            {
                for (int i = 0; i < dto.blocked.Length; i++)
                {
                    var parsed = ParsePosition(dto.blocked[i]);
                    if (parsed == null) errors.Add("level " + dto.number + ": bad blocked cell '" + dto.blocked[i] + "'");
                    else level.Blocked.Add(parsed.Value);
                }
            }

            return level;
        }

        /// <summary>"x,y" → CellPos. Null when the text is not two integers.</summary>
        public static CellPos? ParsePosition(string text)
        {
            if (string.IsNullOrEmpty(text)) return null;
            var parts = text.Split(',');
            if (parts.Length != 2) return null;

            int x;
            int y;
            if (!int.TryParse(parts[0].Trim(), out x)) return null;
            if (!int.TryParse(parts[1].Trim(), out y)) return null;
            return new CellPos(x, y);
        }
    }
}
