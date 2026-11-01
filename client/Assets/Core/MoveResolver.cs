using System;
using System.Collections.Generic;

namespace Shazdeh.Core
{
    /// <summary>
    /// One swap or one booster, resolved to a settled board plus the event log the view animates.
    /// Everything here is deterministic: same board + same call + same RNG state = same result.
    /// </summary>
    public sealed class MoveResolver
    {
        struct Spawn
        {
            public CellPos Position;
            public PowerUpKind Kind;
            public PieceKind Piece;
        }

        const int MaxCascades = 64;
        const int MaxTriggerChain = 64;

        readonly LevelDefinition _level;
        readonly Board _board;
        readonly DeterministicRandom _rng;
        readonly GoalTracker _goals;

        public MoveResolver(LevelDefinition level, Board board, DeterministicRandom rng, GoalTracker goals)
        {
            _level = level;
            _board = board;
            _rng = rng;
            _goals = goals;
        }

        public MoveResult Swap(CellPos from, CellPos to)
        {
            if (!_board.InBounds(from) || !_board.InBounds(to))
                return MoveResult.Rejected(MoveKind.Swap, "out of bounds");

            int distance = Math.Abs(from.X - to.X) + Math.Abs(from.Y - to.Y);
            if (distance != 1) return MoveResult.Rejected(MoveKind.Swap, "not adjacent");

            var a = _board.At(from);
            var b = _board.At(to);
            if (a == null || b == null || !a.HasPiece || !b.HasPiece)
                return MoveResult.Rejected(MoveKind.Swap, "empty cell");

            var powerA = a.PowerUp;
            var powerB = b.PowerUp;
            bool bothPowerUps = powerA != PowerUpKind.None && powerB != PowerUpKind.None;

            MatchFinder.SwapPieces(a, b);

            if (!bothPowerUps)
            {
                bool line = MatchFinder.HasMatch(_board);
                bool square = MatchFinder.FindSquares(_board).Count > 0;
                if (!line && !square)
                {
                    MatchFinder.SwapPieces(a, b);
                    return MoveResult.Rejected(MoveKind.Swap, "no match");
                }
            }

            var result = new MoveResult { Kind = MoveKind.Swap, Accepted = true };

            if (bothPowerUps)
            {
                var targets = new List<CellPos>();
                PowerUps.CollectComboTargets(_board, to, powerA, powerB, _rng, targets);
                result.Events.Add(new PowerUpTriggeredEvent { Position = to, Kind = powerA });
                result.Events.Add(new PowerUpTriggeredEvent { Position = to, Kind = powerB });

                var dest = _board.At(to);
                if (dest != null) dest.PowerUp = PowerUpKind.None;
                AddUnique(targets, to);
                ExpandTriggers(targets, result);
                ApplyClears(targets, result);
                FallAndRefill();
            }

            ResolveCascades(result, to, true);
            Settle(result);
            return result;
        }

        public MoveResult UseBooster(BoosterKind kind, CellPos target)
        {
            if (!_board.InBounds(target))
                return MoveResult.Rejected(MoveKind.Booster, "out of bounds");

            var result = new MoveResult { Kind = MoveKind.Booster, Accepted = true };
            var cells = new List<CellPos>();

            switch (kind)
            {
                case BoosterKind.Mallet:
                    AddUnique(cells, target);
                    break;
                case BoosterKind.Ram:
                    PowerUps.AddRow(_board, target.Y, cells);
                    break;
                case BoosterKind.Auger:
                    PowerUps.AddColumn(_board, target.X, cells);
                    break;
                case BoosterKind.Whirlwind:
                    BoardFactory.Reshuffle(_board, _level.Pieces, _rng);
                    result.Events.Add(new BoardReshuffledEvent());
                    Settle(result);
                    return result;
                case BoosterKind.Falcon:
                    for (int i = 0; i < 3; i++)
                    {
                        var splash = PowerUps.PickSpinnerTarget(_board, _rng);
                        PowerUps.AddSquare(_board, splash, 1, cells);
                    }
                    break;
            }

            ExpandTriggers(cells, result);
            ApplyClears(cells, result);
            FallAndRefill();
            ResolveCascades(result, target, false);
            Settle(result);
            return result;
        }

        void ResolveCascades(MoveResult result, CellPos preferred, bool hasPreferred)
        {
            int cascade = 0;
            while (cascade < MaxCascades)
            {
                var runs = MatchFinder.FindRuns(_board);
                var squares = MatchFinder.FindSquares(_board);
                if (runs.Count == 0 && squares.Count == 0) break;

                cascade++;
                result.Cascades = cascade;
                result.Events.Add(new CascadeEvent { Index = cascade });

                var clearSet = new List<CellPos>();
                var spawns = new List<Spawn>();

                var clusters = MatchFinder.BuildClusters(runs);
                for (int i = 0; i < clusters.Count; i++)
                {
                    var cluster = clusters[i];
                    for (int c = 0; c < cluster.Cells.Count; c++) AddUnique(clearSet, cluster.Cells[c]);

                    var kind = MatchFinder.PowerUpFor(cluster);
                    if (kind == PowerUpKind.None) continue;

                    var spawnPos = MatchFinder.ChooseSpawnCell(cluster, preferred, hasPreferred && cascade == 1);
                    var spawnCell = _board.At(spawnPos);
                    spawns.Add(new Spawn
                    {
                        Position = spawnPos,
                        Kind = kind,
                        Piece = spawnCell != null ? spawnCell.Piece : cluster.Runs[0].Piece
                    });
                }

                for (int i = 0; i < squares.Count; i++)
                {
                    var origin = squares[i];
                    var block = new[]
                    {
                        origin, new CellPos(origin.X + 1, origin.Y),
                        new CellPos(origin.X, origin.Y + 1), new CellPos(origin.X + 1, origin.Y + 1)
                    };

                    bool covered = false;
                    for (int c = 0; c < block.Length; c++)
                        if (clearSet.Contains(block[c])) { covered = true; break; }
                    if (covered) continue;

                    for (int c = 0; c < block.Length; c++) AddUnique(clearSet, block[c]);

                    bool usePreferred = hasPreferred && cascade == 1;
                    var spawnPos = origin;
                    if (usePreferred)
                        for (int c = 0; c < block.Length; c++)
                            if (block[c] == preferred) { spawnPos = preferred; break; }

                    var spawnCell = _board.At(spawnPos);
                    spawns.Add(new Spawn
                    {
                        Position = spawnPos,
                        Kind = PowerUpKind.Spinner,
                        Piece = spawnCell != null ? spawnCell.Piece : PieceKind.None
                    });
                }

                ExpandTriggers(clearSet, result);

                // the cells a power-up spawns on are not cleared: the piece becomes the power-up
                for (int i = 0; i < spawns.Count; i++) clearSet.Remove(spawns[i].Position);

                ApplyClears(clearSet, result);
                SpawnPowerUps(spawns, result);
                FallAndRefill();

                hasPreferred = false;
            }
        }

        void SpawnPowerUps(List<Spawn> spawns, MoveResult result)
        {
            for (int i = 0; i < spawns.Count; i++)
            {
                var spawn = spawns[i];
                var cell = _board.At(spawn.Position);
                if (cell == null || cell.Blocked) continue;

                if (!cell.HasPiece) cell.Piece = spawn.Piece;
                cell.PowerUp = spawn.Kind;

                result.PowerUpsCreated++;
                result.Events.Add(new PowerUpCreatedEvent
                {
                    Position = spawn.Position, Kind = spawn.Kind, Piece = cell.Piece
                });
            }
        }

        /// <summary>Power-ups caught in a blast go off too, and can set off each other.</summary>
        void ExpandTriggers(List<CellPos> clearSet, MoveResult result)
        {
            var queue = new List<CellPos>();
            for (int i = 0; i < clearSet.Count; i++)
            {
                var cell = _board.At(clearSet[i]);
                if (cell != null && cell.PowerUp != PowerUpKind.None && cell.HasPiece) queue.Add(clearSet[i]);
            }

            int guard = 0;
            while (queue.Count > 0 && guard++ < MaxTriggerChain)
            {
                var pos = queue[0];
                queue.RemoveAt(0);

                var cell = _board.At(pos);
                if (cell == null || cell.PowerUp == PowerUpKind.None) continue;

                var kind = cell.PowerUp;
                cell.PowerUp = PowerUpKind.None;
                result.Events.Add(new PowerUpTriggeredEvent { Position = pos, Kind = kind });

                var targets = new List<CellPos>();
                PowerUps.CollectTargets(_board, pos, kind, _rng, targets);
                for (int i = 0; i < targets.Count; i++)
                {
                    var p = targets[i];
                    if (clearSet.Contains(p)) continue;
                    AddUnique(clearSet, p);
                    var other = _board.At(p);
                    if (other != null && other.PowerUp != PowerUpKind.None) queue.Add(p);
                }
            }
        }

        void ApplyClears(List<CellPos> cells, MoveResult result)
        {
            cells.Sort(CompareBottomUp);

            for (int i = 0; i < cells.Count; i++)
            {
                var pos = cells[i];
                var cell = _board.At(pos);
                if (cell == null || cell.Blocked) continue;

                if (cell.HasPiece)
                {
                    var piece = cell.Piece;
                    result.Events.Add(new PieceClearedEvent
                    {
                        Position = pos, Piece = piece, PowerUp = cell.PowerUp
                    });
                    result.PiecesCleared++;

                    var changed = new List<int>();
                    _goals.RecordPieceCleared(piece, changed);
                    EmitGoalProgress(changed, result);

                    cell.ClearPiece();
                    if (cell.HasObstacle) DamageObstacle(pos, cell, result);
                }
                else if (cell.HasObstacle)
                {
                    DamageObstacle(pos, cell, result);
                }
            }
        }

        void DamageObstacle(CellPos pos, Cell cell, MoveResult result)
        {
            var kind = cell.Obstacle;
            cell.ObstacleLayers--;

            bool destroyed = cell.ObstacleLayers <= 0;
            result.Events.Add(new ObstacleHitEvent
            {
                Position = pos, Kind = kind, LayersLeft = cell.ObstacleLayers, Destroyed = destroyed
            });

            var changed = new List<int>();
            _goals.RecordObstacleLayer(kind, changed);
            EmitGoalProgress(changed, result);

            if (destroyed)
            {
                cell.SetObstacle(ObstacleKind.None, 0);
                result.ObstaclesDestroyed++;
            }
        }

        void EmitGoalProgress(List<int> changed, MoveResult result)
        {
            for (int i = 0; i < changed.Count; i++)
            {
                int index = changed[i];
                int progress = _goals.Progress(index);
                int target = _goals.Target(index);
                result.Events.Add(new GoalProgressEvent
                {
                    Index = index, Progress = progress, Target = target, Complete = progress >= target
                });
            }
        }

        void ApplyGravity()
        {
            bool down = _level.Gravity == GravityDirection.Down;

            for (int x = 0; x < _board.Width; x++)
            {
                int write = down ? 0 : _board.Height - 1;
                int step = down ? 1 : -1;

                for (int i = 0; i < _board.Height; i++)
                {
                    int y = down ? i : _board.Height - 1 - i;
                    var cell = _board.At(x, y);
                    if (cell == null || !cell.HasPiece || cell.Blocked) continue;

                    // skip write targets that can never hold a piece
                    while (write >= 0 && write < _board.Height)
                    {
                        var probe = _board.At(x, write);
                        if (probe != null && !probe.Blocked) break;
                        write += step;
                    }
                    if (write < 0 || write >= _board.Height) break;

                    if (write != y)
                    {
                        var target = _board.At(x, write);
                        target.Piece = cell.Piece;
                        target.PowerUp = cell.PowerUp;
                        cell.ClearPiece();
                    }
                    write += step;
                }
            }
        }

        void Refill()
        {
            var kinds = _level.Pieces;
            if (kinds == null || kinds.Count == 0) return;

            foreach (var pos in _board.AllPositions())
            {
                var cell = _board.At(pos);
                if (cell == null || cell.Blocked || cell.HasPiece) continue;
                cell.Piece = kinds[_rng.Next(kinds.Count)];
                cell.PowerUp = PowerUpKind.None;
            }
        }

        void FallAndRefill()
        {
            ApplyGravity();
            Refill();
        }

        /// <summary>No legal swap left → reshuffle, never a dead end for the player.</summary>
        void Settle(MoveResult result)
        {
            if (MatchFinder.HasPossibleMove(_board)) return;
            BoardFactory.Reshuffle(_board, _level.Pieces, _rng);
            result.Events.Add(new BoardReshuffledEvent());
        }

        static void AddUnique(List<CellPos> list, CellPos pos)
        {
            if (list.Count >= PowerUps.MaxTargets) return;
            if (!list.Contains(pos)) list.Add(pos);
        }

        static int CompareBottomUp(CellPos a, CellPos b)
        {
            if (a.Y != b.Y) return a.Y.CompareTo(b.Y);
            return a.X.CompareTo(b.X);
        }
    }
}
