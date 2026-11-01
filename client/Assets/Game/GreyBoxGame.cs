using System.Collections.Generic;
using System.Text;
using Shazdeh.Core;
using UnityEngine;

namespace Shazdeh.Game
{
    /// <summary>
    /// M0 "feel" prototype: the real engine, the real levels, no art.
    ///
    /// Every square is a coloured sprite from the design tokens, obstacles and power-ups are drawn as
    /// overlays, and the HUD is IMGUI so the prototype needs no fonts, no prefabs and no packages. It
    /// is deliberately ugly: the only thing being tested here is whether swapping feels right and
    /// whether the engine settles correctly. It is replaced screen by screen in M1.
    /// </summary>
    public sealed class GreyBoxGame : MonoBehaviour
    {
        const float Cell = 1f;

        [Header("Start here")]
        public int startLevel = 1;
        public string chapter = "ch01";
        public ulong seed = 20260101UL;

        LevelDefinition _level;
        LevelRun _run;
        SpriteRenderer[] _tiles;
        SpriteRenderer[] _overlays;
        Sprite _square;
        Camera _camera;
        CellPos? _selected;
        readonly StringBuilder _log = new StringBuilder();
        string _status = "";

        void Awake()
        {
            BuildCamera();
            BuildSprites();
            LoadLevel(startLevel);
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
            var errors = new List<string>();
            _level = LevelSource.LoadLevel(number, chapter, errors);

            if (_level == null || errors.Count > 0)
            {
                _status = "Level " + number + " failed to load: " + string.Join("; ", errors.ToArray());
                for (int i = 0; i < errors.Count; i++) Debug.LogError(errors[i]);
                return;
            }

            _run = new LevelRun(_level, seed + (ulong)number);
            _selected = null;
            _log.Length = 0;
            _status = "Level " + number + " (" + _level.Type + ") - " + _level.Goals.Count + " goal(s)";

            BuildTiles();
            FrameCamera();
            RefreshTiles();
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
            if (_tiles != null)
            {
                for (int i = 0; i < _tiles.Length; i++)
                {
                    if (_tiles[i] != null) Destroy(_tiles[i].gameObject);
                    if (_overlays[i] != null) Destroy(_overlays[i].gameObject);
                }
            }

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
            float ox = (_level.Width - 1) * 0.5f;
            float oy = (_level.Height - 1) * 0.5f;
            int x = Mathf.RoundToInt(world.x / Cell + ox);
            int y = Mathf.RoundToInt(world.y / Cell + oy);
            if (x < 0 || y < 0 || x >= _level.Width || y >= _level.Height) return null;
            return new CellPos(x, y);
        }

        void RefreshTiles()
        {
            if (_run == null) return;

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
                        // obstacles read as a darker tile with a stout border
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
            if (_run == null) return;

            Vector2 screen;
            bool down;
            bool up;
            if (InputCompat.TryGetPointer(out screen, out down, out up) && down)
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
        }

        void HandleBoosterKeys()
        {
            if (_run.Status != LevelStatus.Playing) return;
            if (!_selected.HasValue) return;

            for (int i = 0; i < 5; i++)
            {
                if (!InputCompat.KeyPressedDown((int)KeyCode.Alpha1 + i)) continue;
                var result = _run.UseBooster((BoosterKind)i, _selected.Value);
                _selected = null;
                Describe(result);
                return;
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

            if (_run.Status == LevelStatus.Won)
                _status = "WON  +" + _run.PotionsEarned + " potions, +" + _run.CoinsEarned + " coins";
            else if (_run.Status == LevelStatus.Lost)
                _status = "OUT OF MOVES - press R to retry";
        }

        void OnGUI()
        {
            if (_run == null)
            {
                GUI.Label(new Rect(20, 20, 900, 40), _status);
                return;
            }

            var style = new GUIStyle(GUI.skin.label) { fontSize = 16 };
            GUI.Label(new Rect(20, 16, 900, 24), _status, style);
            GUI.Label(new Rect(20, 44, 900, 24),
                "Moves left: " + _run.MovesLeft + " / " + _run.MoveLimit + "     Goals: " + GoalsText(), style);
            GUI.Label(new Rect(20, 72, 900, 24), _log.ToString(), style);
            GUI.Label(new Rect(20, 100, 900, 24),
                "Tap two adjacent tiles to swap. Select a tile and press 1-5 for Mallet / Ram / Auger / Whirlwind / Falcon.", style);

            if (GUI.Button(new Rect(20, 132, 110, 32), "Restart (R)"))
                LoadLevel(startLevel);

            if (GUI.Button(new Rect(140, 132, 130, 32), "Next level (N)"))
            {
                startLevel = startLevel >= LevelSource.DefaultLevelCount ? 1 : startLevel + 1;
                LoadLevel(startLevel);
            }

            if (Event.current.type == EventType.KeyDown)
            {
                if (Event.current.keyCode == KeyCode.R) LoadLevel(startLevel);
                if (Event.current.keyCode == KeyCode.N)
                {
                    startLevel = startLevel >= LevelSource.DefaultLevelCount ? 1 : startLevel + 1;
                    LoadLevel(startLevel);
                }
            }
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
