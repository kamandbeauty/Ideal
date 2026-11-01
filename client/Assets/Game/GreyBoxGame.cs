using System.Collections.Generic;
using System.Text;
using Shazdeh.Content;
using Shazdeh.Core;
using UnityEngine;

namespace Shazdeh.Game
{
    /// <summary>
    /// M0/M1 grey box: the real engine, the real levels, the real save, no art.
    ///
    /// Adds the offline meta loop on top of M0: potions earned by clearing levels, spent on district
    /// tasks, district chests when every task is built, lives that refill on a timestamp, and a save
    /// file that survives a restart. Every rule lives in Shazdeh.Core and is unit tested; this class
    /// only draws it and passes taps through.
    /// </summary>
    public sealed class GreyBoxGame : MonoBehaviour
    {
        const float Cell = 1f;

        [Header("Start here")]
        [Tooltip("0 = continue from the save, otherwise force this level")]
        public int startLevel;
        public string chapter = "ch01";
        public ulong seed = 20260101UL;

        // economy and save (ADR 0001: local save is the source of truth)
        IClock _clock;
        ISaveStore _store;
        SaveData _save;
        Wallet _wallet;
        Lives _lives;
        Progression _progress;
        ChapterMeta _meta;

        LevelDefinition _level;
        LevelRun _run;
        SpriteRenderer[] _tiles;
        SpriteRenderer[] _overlays;
        Sprite _square;
        Camera _camera;
        CellPos? _selected;

        readonly StringBuilder _log = new StringBuilder();
        string _status = "";
        string _reward = "";
        bool _showTasks;
        bool _rewardApplied;
        bool _lifeSpent;
        int _currentLevel = 1;

        void Awake()
        {
            _clock = new SystemClock();
            _store = new FileSaveStore(_clock);

            var errors = new List<string>();
            _save = _store.Load(errors);
            for (int i = 0; i < errors.Count; i++) Debug.LogWarning("[save] " + errors[i]);

            _wallet = new Wallet(_save);
            _lives = new Lives(_save, _clock);
            _progress = new Progression(_save, _clock);

            _meta = LevelSource.LoadChapterMeta(chapter, errors);
            for (int i = 0; i < errors.Count; i++) Debug.LogError("[content] " + errors[i]);

            BuildCamera();
            BuildSprites();

            int level = startLevel > 0
                ? startLevel
                : Mathf.Clamp(_progress.HighestUnlockedLevel, 1, LevelSource.DefaultLevelCount);

            LoadLevel(level);
        }

        void BuildCamera()
        {
            _camera = Camera.main;
            if (_camera == null)
            {
                var go = new GameObject("GreyBoxCamera");
                go.tag = "MainCamera";
                _camera = go.AddComponent<Camera>();
            }
            _camera.transform.position = new Vector3(0f, 0f, -10f);
            _camera.orthographic = true;
            _camera.backgroundColor = Tokens.Bg;
            _camera.clearFlags = CameraClearFlags.SolidColor;
        }

        void BuildSprites()
        {
            // one white square, tinted per cell — no atlases until there is art
            _square = MakeSprite(Color.white);
        }

        static Sprite MakeSprite(Color color)
        {
            const int size = 8;
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, false);
            texture.filterMode = FilterMode.Bilinear;
            for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
                texture.SetPixel(x, y, color);
            texture.Apply();
            return Sprite.Create(texture, new Rect(0f, 0f, size, size), new Vector2(0.5f, 0.5f), size);
        }

        void LoadLevel(int number)
        {
            _currentLevel = number;
            _rewardApplied = false;
            _lifeSpent = false;
            _reward = "";
            _selected = null;
            _log.Length = 0;
            _run = null;

            if (!_progress.IsUnlocked(number))
            {
                _status = "Level " + number + " is locked (progress: " + _progress.HighestUnlockedLevel + ")";
                return;
            }

            if (_lives.Current <= 0)
            {
                _status = "No lives left — next one in " + FormatTime(_lives.NextRefillInSeconds);
                ClearTiles();
                return;
            }

            var errors = new List<string>();
            _level = LevelSource.LoadLevel(number, chapter, errors);

            if (_level == null || errors.Count > 0)
            {
                _status = "Level " + number + " failed to load: " + string.Join("; ", errors.ToArray());
                for (int i = 0; i < errors.Count; i++) Debug.LogError(errors[i]);
                return;
            }

            _run = new LevelRun(_level, seed + (ulong)number);
            _status = "Level " + number + " (" + _level.Type + ")";

            BuildTiles();
            FrameCamera();
            RefreshTiles();
        }

        void ClearTiles()
        {
            if (_tiles == null) return;
            for (int i = 0; i < _tiles.Length; i++)
            {
                if (_tiles[i] != null) Destroy(_tiles[i].gameObject);
                if (_overlays[i] != null) Destroy(_overlays[i].gameObject);
            }
            _tiles = null;
            _overlays = null;
            if (_level != null) _camera.orthographicSize = 6f;
        }

        void FrameCamera()
        {
            float halfHeight = _level.Height * Cell * 0.5f + 1.2f;
            float halfWidth = _level.Width * Cell * 0.5f + 0.4f;
            float aspect = _camera.aspect <= 0.01f ? 0.6f : _camera.aspect;
            _camera.orthographicSize = Mathf.Max(halfHeight, halfWidth / aspect);
        }

        void BuildTiles()
        {
            ClearTiles();

            int count = _level.Width * _level.Height;
            _tiles = new SpriteRenderer[count];
            _overlays = new SpriteRenderer[count];

            for (int y = 0; y < _level.Height; y++)
            {
                for (int x = 0; x < _level.Width; x++)
                {
                    var cellGo = new GameObject("cell_" + x + "_" + y);
                    cellGo.transform.SetParent(transform, false);
                    cellGo.transform.localPosition = WorldOf(new CellPos(x, y));

                    var baseRenderer = cellGo.AddComponent<SpriteRenderer>();
                    baseRenderer.sprite = _square;
                    baseRenderer.sortingOrder = 0;

                    var overlayGo = new GameObject("overlay");
                    overlayGo.transform.SetParent(cellGo.transform, false);
                    overlayGo.transform.localScale = Vector3.one * 0.72f;
                    var overlay = overlayGo.AddComponent<SpriteRenderer>();
                    overlay.sprite = _square;
                    overlay.sortingOrder = 1;

                    int index = y * _level.Width + x;
                    _tiles[index] = baseRenderer;
                    _overlays[index] = overlay;
                }
            }
        }

        Vector3 WorldOf(CellPos pos)
        {
            float ox = (_level.Width - 1) * 0.5f;
            float oy = (_level.Height - 1) * 0.5f;
            return new Vector3((pos.X - ox) * Cell, (pos.Y - oy) * Cell, 0f);
        }

        CellPos? CellAt(Vector3 world)
        {
            if (_level == null) return null;
            float ox = (_level.Width - 1) * 0.5f;
            float oy = (_level.Height - 1) * 0.5f;
            int x = Mathf.RoundToInt(world.x / Cell + ox);
            int y = Mathf.RoundToInt(world.y / Cell + oy);
            if (x < 0 || y < 0 || x >= _level.Width || y >= _level.Height) return null;
            return new CellPos(x, y);
        }

        void RefreshTiles()
        {
            if (_run == null || _tiles == null) return;

            for (int y = 0; y < _level.Height; y++)
            {
                for (int x = 0; x < _level.Width; x++)
                {
                    int index = y * _level.Width + x;
                    var cell = _run.Board.At(x, y);
                    var baseRenderer = _tiles[index];
                    var overlay = _overlays[index];
                    if (cell == null || baseRenderer == null) continue;

                    if (cell.Blocked)
                    {
                        baseRenderer.color = Tokens.Border;
                        overlay.color = new Color(0f, 0f, 0f, 0f);
                        continue;
                    }

                    baseRenderer.color = ColorFor(cell.Piece);

                    var overlayColor = new Color(0f, 0f, 0f, 0f);

                    if (cell.HasObstacle)
                    {
                        baseRenderer.color = Color.Lerp(baseRenderer.color, Tokens.Bg, 0.45f);
                        overlayColor = cell.ObstacleLayers > 1 ? Tokens.BorderInput : Tokens.Border;
                    }

                    if (cell.PowerUp != PowerUpKind.None) overlayColor = Tokens.Gold + new Color(0f, 0f, 0f, 0.35f);

                    if (_selected.HasValue && _selected.Value.X == x && _selected.Value.Y == y)
                        overlayColor = Tokens.Accent;

                    overlay.color = overlayColor;
                }
            }
        }

        static Color ColorFor(PieceKind kind)
        {
            switch (kind)
            {
                case PieceKind.Firouzeh: return Tokens.Piece.Firouzeh;
                case PieceKind.Lajvard: return Tokens.Piece.Lajvard;
                case PieceKind.Aqiq: return Tokens.Piece.Aqiq;
                case PieceKind.Zomorrod: return Tokens.Piece.Zomorrod;
                case PieceKind.Morvarid: return Tokens.Piece.Morvarid;
                default: return Tokens.Surface;
            }
        }

        void Update()
        {
            // A life that came back while the app was open is worth saving; the refill is arithmetic
            // on a timestamp, so this is only about keeping the file in step with the screen.
            if (_lives.Refresh() > 0) _store.Save(_save);

            if (_run == null) return;

            Vector2 screen;
            bool down;
            bool up;
            if (InputCompat.TryGetPointer(out screen, out down, out up) && down && !_showTasks)
            {
                var world = _camera.ScreenToWorldPoint(new Vector3(screen.x, screen.y, -_camera.transform.position.z));
                var cell = CellAt(world);
                if (cell.HasValue) HandleTap(cell.Value);
            }

            HandleBoosterKeys();
            RefreshTiles();
        }

        void HandleTap(CellPos cell)
        {
            if (_run.Status != LevelStatus.Playing) return;

            if (!_selected.HasValue)
            {
                _selected = cell;
                return;
            }

            var from = _selected.Value;
            int distance = Mathf.Abs(from.X - cell.X) + Mathf.Abs(from.Y - cell.Y);
            if (distance != 1)
            {
                _selected = cell;
                return;
            }

            var result = _run.TrySwap(from.X, from.Y, cell.X, cell.Y);
            _selected = null;
            Describe(result);
            SettleOutcome();
        }

        void HandleBoosterKeys()
        {
            if (_run == null || _run.Status != LevelStatus.Playing) return;
            if (!_selected.HasValue) return;

            for (int i = 0; i < 5; i++)
            {
                if (!InputCompat.KeyPressedDown((int)KeyCode.Alpha1 + i)) continue;
                var result = _run.UseBooster((BoosterKind)i, _selected.Value);
                _selected = null;
                Describe(result);
                SettleOutcome();
                return;
            }
        }

        /// <summary>The one place that writes the outcome to the save. Idempotent per level attempt.</summary>
        void SettleOutcome()
        {
            if (_run == null) return;

            if (_run.Status == LevelStatus.Won && !_rewardApplied)
            {
                _rewardApplied = true;
                RewardBundle reward;
                bool firstClear = _progress.RecordLevelResult(_run, _wallet, out reward);
                _store.Save(_save);

                _reward = firstClear
                    ? "+" + reward.Potions + " potions, +" + reward.Coins + " coins, level " +
                      (_currentLevel + 1) + " unlocked"
                    : "replay: no reward (only the first clear pays)";
                return;
            }

            if (_run.Status == LevelStatus.Lost && !_lifeSpent)
            {
                _lifeSpent = true;
                _lives.TrySpend();
                _store.Save(_save);
            }
        }

        void Describe(MoveResult result)
        {
            _log.Length = 0;
            _log.Append(result.Accepted ? "accepted" : "rejected: " + result.RejectReason);
            if (result.Accepted)
            {
                _log.Append(" | cleared ").Append(result.PiecesCleared);
                _log.Append(" | cascades ").Append(result.Cascades);
                if (result.PowerUpsCreated > 0) _log.Append(" | +").Append(result.PowerUpsCreated).Append(" power-up");
                if (result.ObstaclesDestroyed > 0) _log.Append(" | obstacles ").Append(result.ObstaclesDestroyed);
            }
        }

        static string FormatTime(int seconds)
        {
            if (seconds <= 0) return "00:00";
            return (seconds / 60).ToString("00") + ":" + (seconds % 60).ToString("00");
        }

        void OnGUI()
        {
            var style = new GUIStyle(GUI.skin.label) { fontSize = 16 };
            var small = new GUIStyle(GUI.skin.label) { fontSize = 13 };

            // wallet + lives, always visible: this is the loop
            GUI.Label(new Rect(20, 12, 900, 24),
                "Level " + _currentLevel + "     Potions " + _wallet.Potions + "     Coins " + _wallet.Coins +
                "     Lives " + _lives.Current + "/" + _lives.Max +
                (_lives.IsFull ? "" : "  (next " + FormatTime(_lives.NextRefillInSeconds) + ")"), style);

            if (_run == null)
            {
                GUI.Label(new Rect(20, 44, 900, 24), _status, style);
                if (GUI.Button(new Rect(20, 80, 150, 32), "Tasks (T)")) _showTasks = !_showTasks;
                if (_showTasks) DrawTasks();
                return;
            }

            GUI.Label(new Rect(20, 44, 900, 24),
                _status + "     Moves " + _run.MovesLeft + "/" + _run.Level.MoveLimit + "     Goals: " + GoalsText(), style);
            GUI.Label(new Rect(20, 70, 900, 22), _log.ToString(), small);

            if (_reward.Length > 0) GUI.Label(new Rect(20, 94, 900, 24), _reward, style);
            if (_run.Status == LevelStatus.Lost)
                GUI.Label(new Rect(20, 118, 900, 24), "Out of moves — a life was used. Press R to retry.", style);

            if (GUI.Button(new Rect(20, 148, 110, 32), "Restart (R)")) LoadLevel(_currentLevel);

            var nextLabel = _progress.IsUnlocked(_currentLevel + 1) ? "Next (N)" : "Locked";
            if (GUI.Button(new Rect(140, 148, 110, 32), nextLabel) && _progress.IsUnlocked(_currentLevel + 1))
                LoadLevel(_currentLevel + 1);

            if (GUI.Button(new Rect(260, 148, 110, 32), "Tasks (T)")) _showTasks = !_showTasks;

            GUI.Label(new Rect(20, 190, 900, 22),
                "Tap two adjacent tiles to swap. Select a tile then 1-5 for Mallet / Ram / Auger / Whirlwind / Falcon.", small);

            if (_showTasks) DrawTasks();

            if (Event.current.type == EventType.KeyDown)
            {
                if (Event.current.keyCode == KeyCode.R) LoadLevel(_currentLevel);
                if (Event.current.keyCode == KeyCode.N)
                {
                    if (_progress.IsUnlocked(_currentLevel + 1)) LoadLevel(_currentLevel + 1);
                }
                if (Event.current.keyCode == KeyCode.T) _showTasks = !_showTasks;
            }
        }

        void DrawTasks()
        {
            if (_meta == null)
            {
                GUI.Label(new Rect(20, 220, 900, 24), "No chapter meta loaded.");
                return;
            }

            float y = 220f;
            GUI.Box(new Rect(16, y - 6, 620, 40 + _meta.Districts.Count * 118), "");
            GUI.Label(new Rect(24, y + 4, 600, 24), "Districts — spend potions to build", new GUIStyle(GUI.skin.label) { fontSize = 16, fontStyle = FontStyle.Bold });
            y += 34;

            for (int d = 0; d < _meta.Districts.Count; d++)
            {
                var district = _meta.Districts[d];
                bool complete = _progress.IsDistrictComplete(district.Costs());
                bool claimed = _progress.IsChestClaimed(district.Id);

                GUI.Label(new Rect(28, y, 600, 22),
                    district.TitleEn + "  (" + district.Tasks.Count + " tasks, " + district.TotalPotionCost() + " potions)" +
                    (complete ? "  — built" : ""), new GUIStyle(GUI.skin.label) { fontSize = 14 });

                y += 24;
                for (int t = 0; t < district.Tasks.Count; t++)
                {
                    var task = district.Tasks[t];
                    bool done = _progress.IsTaskComplete(task.Key);
                    string label = (done ? "[x] " : "[ ] ") + task.TitleEn + "  " + task.PotionCost;

                    GUI.enabled = !done && _wallet.CanAffordPotions(task.PotionCost);
                    if (GUI.Button(new Rect(40, y, 300, 26), label))
                    {
                        var core = new TaskCost(task.Key, task.PotionCost);
                        if (_progress.TryCompleteTask(core.Key, core.PotionCost, _wallet)) _store.Save(_save);
                    }
                    GUI.enabled = true;
                    y += 28;
                }

                if (!complete)
                {
                    long remaining = RemainingPotions(district);
                    GUI.enabled = _wallet.CanAffordPotions(remaining) && remaining > 0;
                    if (GUI.Button(new Rect(352, y - 28 * district.Tasks.Count, 130, 26), "Do it (" + remaining + ")"))
                    {
                        int built;
                        long spent;
                        if (_progress.TryCompleteTasks(district.Costs(), _wallet, out built, out spent)) _store.Save(_save);
                    }
                    GUI.enabled = true;
                }
                else if (!claimed)
                {
                    GUI.enabled = true;
                    if (GUI.Button(new Rect(352, y - 28 * district.Tasks.Count, 130, 26), "Open chest"))
                    {
                        if (_progress.TryClaimChest(district.Id, district.Chest, district.Costs(), _wallet)) _store.Save(_save);
                    }
                }
                else
                {
                    GUI.Label(new Rect(352, y - 28 * district.Tasks.Count, 160, 26), "chest opened");
                }

                y += 8;
            }
        }

        long RemainingPotions(DistrictDefinition district)
        {
            long total = 0;
            for (int i = 0; i < district.Tasks.Count; i++)
                if (!_progress.IsTaskComplete(district.Tasks[i].Key)) total += district.Tasks[i].PotionCost;
            return total;
        }

        string GoalsText()
        {
            var sb = new StringBuilder();
            for (int i = 0; i < _run.Goals.Count; i++)
            {
                if (i > 0) sb.Append("  ");
                var goal = _run.Goals.Goal(i);
                sb.Append(goal.Kind == GoalKind.ClearPieces ? goal.Piece.ToString() : goal.Obstacle.ToString());
                sb.Append(' ').Append(_run.Goals.Progress(i)).Append('/').Append(_run.Goals.Target(i));
            }
            return sb.ToString();
        }
    }
}
