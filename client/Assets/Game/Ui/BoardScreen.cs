using System;
using System.Collections.Generic;
using System.Text;
using Shazdeh.Core;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// The board screen: the real engine, the real level, drawn as tokens instead of candy.
    ///
    /// Art direction arrives with the sprites; what this screen owns is the shell around the board —
    /// where the moves counter sits, how the goals are written in Persian, what happens when the moves
    /// run out — because that is what players actually read while they play.
    ///
    /// One rule it keeps from M0: the view never mutates the model. A tap becomes a TrySwap call, and
    /// the board is redrawn from whatever the engine says afterwards.
    /// </summary>
    public sealed class BoardScreen : UiScreen
    {
        public Action HomeRequested;
        public Action<int> PlayRequested;

        const float Cell = 1f;
        const float BoardDropWorld = -0.55f; // the board sits slightly below centre, under the HUD

        Camera _camera;
        GameObject _boardRoot;
        Sprite _square;
        SpriteRenderer[] _tiles;
        SpriteRenderer[] _overlays;

        LevelDefinition _level;
        LevelRun _run;
        int _levelNumber;
        CellPos? _selected;
        bool _settled;

        TextMeshProUGUI _levelLabel;
        TextMeshProUGUI _movesLabel;
        TextMeshProUGUI _goalsLabel;
        TextMeshProUGUI _statusLabel;

        RectTransform _resultOverlay;
        TextMeshProUGUI _resultTitle;
        TextMeshProUGUI _resultBody;
        Button _primary;
        Button _secondary;
        TextMeshProUGUI _primaryLabel;
        TextMeshProUGUI _secondaryLabel;
        Action _primaryAction;
        Action _secondaryAction;

        readonly StringBuilder _goalsText = new StringBuilder(64);

        // ---- construction -------------------------------------------------------------------------

        protected override void Build()
        {
            // No background panel here on purpose: an opaque canvas image would cover the camera that
            // draws the board. The camera clears to Bg, which is the same colour the other screens use.
            BuildCamera();
            BuildHud();
            BuildResultOverlay();
        }

        void BuildCamera()
        {
            // The camera lives at the scene root, not inside the canvas: a camera parented under a UI
            // rect inherits UI coordinates, which is a bug that only shows up on an unusual aspect.
            var go = new GameObject("BoardCamera");
            go.transform.position = new Vector3(0f, 0f, -10f);

            _camera = go.AddComponent<Camera>();
            _camera.orthographic = true;
            _camera.clearFlags = CameraClearFlags.SolidColor;
            _camera.backgroundColor = Tokens.Bg;
            _camera.depth = -1;
            _camera.enabled = false;

            _boardRoot = new GameObject("Board");
            _boardRoot.transform.SetParent(go.transform, false);
            _boardRoot.transform.localPosition = new Vector3(0f, BoardDropWorld, 0f);

            _square = MakeSquareSprite();
        }

        void OnEnable()
        {
            if (_camera != null) _camera.enabled = true;
        }

        void OnDisable()
        {
            if (_camera != null) _camera.enabled = false;
        }

        void OnDestroy()
        {
            if (_camera != null) Destroy(_camera.gameObject);
        }

        static Sprite MakeSquareSprite()
        {
            const int size = 8;
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, false)
            {
                filterMode = FilterMode.Bilinear,
                name = "board_square"
            };
            var pixels = new Color32[size * size];
            for (int i = 0; i < pixels.Length; i++) pixels[i] = new Color32(255, 255, 255, 255);
            texture.SetPixels32(pixels);
            texture.Apply();
            return Sprite.Create(texture, new Rect(0f, 0f, size, size), new Vector2(0.5f, 0.5f), size);
        }

        void BuildHud()
        {
            UiKit.Button(Root, "home", "خانه", UiKit.CanvasWidth - 20f - 76f, 44f, 76f, 40f,
                Tokens.SurfaceRaised, Tokens.Text, () => HomeRequested?.Invoke(), (int)Tokens.Radius.Md);

            _levelLabel = UiKit.Label(Root, "level", "", Tokens.Type.Lg, Tokens.Text, TextAlignmentOptions.Center);
            UiKit.Place(_levelLabel.rectTransform, 96f, 44f, UiKit.CanvasWidth - 192f, 40f);

            var movesPill = UiKit.Panel(Root, "moves", 20f, 44f, 96f, 40f, Tokens.SurfaceRaised, (int)Tokens.Radius.Md);
            _movesLabel = UiKit.Label(movesPill, "value", "", Tokens.Type.Base, Tokens.Accent, TextAlignmentOptions.Center);
            UiKit.Stretch(_movesLabel.rectTransform, Tokens.Space.S2, 0f);

            _goalsLabel = UiKit.Label(Root, "goals", "", Tokens.Type.Sm, Tokens.TextMuted, TextAlignmentOptions.Center);
            UiKit.Place(_goalsLabel.rectTransform, 20f, 92f, UiKit.CanvasWidth - 40f, 22f);

            _statusLabel = UiKit.Label(Root, "status", "", Tokens.Type.Sm, Tokens.Gold, TextAlignmentOptions.Center);
            UiKit.Place(_statusLabel.rectTransform, 20f, 116f, UiKit.CanvasWidth - 40f, 22f);
        }

        void BuildResultOverlay()
        {
            var dim = UiKit.Background(Root, new Color(Tokens.Bg.r, Tokens.Bg.g, Tokens.Bg.b, 0.88f));
            dim.name = "result";
            dim.GetComponent<Image>().raycastTarget = true;
            _resultOverlay = dim;

            var card = UiKit.Panel(dim, "card", 20f, 210f, UiKit.CanvasWidth - 40f, 318f,
                Tokens.Surface, (int)Tokens.Radius.Panel);

            _resultTitle = UiKit.Label(card, "title", "", Tokens.Type.Xl, Tokens.Gold, TextAlignmentOptions.Center);
            UiKit.Place(_resultTitle.rectTransform, 16f, 28f, card.sizeDelta.x - 32f, 34f);

            _resultBody = UiKit.Label(card, "body", "", Tokens.Type.Base, Tokens.Text, TextAlignmentOptions.Center);
            UiKit.Place(_resultBody.rectTransform, 24f, 80f, card.sizeDelta.x - 48f, 96f);

            _primary = UiKit.Button(card, "primary", "", 24f, 196f, card.sizeDelta.x - 48f, 52f,
                Tokens.Accent, Tokens.OnAccent, () => _primaryAction?.Invoke(), (int)Tokens.Radius.Md);
            _primaryLabel = _primary.GetComponentInChildren<TextMeshProUGUI>();

            _secondary = UiKit.Button(card, "secondary", "خانه", 24f, 258f, card.sizeDelta.x - 48f, 44f,
                Tokens.SurfaceRaised, Tokens.Text, () => _secondaryAction?.Invoke(), (int)Tokens.Radius.Md);
            _secondaryLabel = _secondary.GetComponentInChildren<TextMeshProUGUI>();

            _resultOverlay.gameObject.SetActive(false);
        }

        // ---- playing ------------------------------------------------------------------------------

        /// <summary>Starts a level and shows the screen. Returns false when the attempt may not start.</summary>
        public bool StartLevel(int number)
        {
            _levelNumber = number;
            _run = Session.StartAttempt(number, out _level, out string error);
            _settled = false;
            _selected = null;

            ClearTiles();
            _resultOverlay.gameObject.SetActive(false);
            _camera.enabled = true;

            if (_run == null)
            {
                RtlText.Set(_levelLabel, "مرحله " + Core.Text.PersianText.Number(number));
                RtlText.Set(_goalsLabel, error ?? "");
                return false;
            }

            BuildTiles();
            FrameCamera();
            DrawBoard();
            Refresh();
            return true;
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
                    var go = new GameObject("cell_" + x + "_" + y);
                    go.transform.SetParent(_boardRoot.transform, false);
                    go.transform.localPosition = WorldOf(new CellPos(x, y));

                    var baseRenderer = go.AddComponent<SpriteRenderer>();
                    baseRenderer.sprite = _square;
                    baseRenderer.sortingOrder = 0;

                    var overlayGo = new GameObject("overlay");
                    overlayGo.transform.SetParent(go.transform, false);
                    overlayGo.transform.localScale = Vector3.one * 0.74f;
                    var overlay = overlayGo.AddComponent<SpriteRenderer>();
                    overlay.sprite = _square;
                    overlay.sortingOrder = 1;

                    int index = y * _level.Width + x;
                    _tiles[index] = baseRenderer;
                    _overlays[index] = overlay;
                }
            }
        }

        void ClearTiles()
        {
            if (_tiles != null)
            {
                for (int i = 0; i < _tiles.Length; i++)
                {
                    if (_tiles[i] != null && _tiles[i].gameObject != null) Destroy(_tiles[i].gameObject);
                }
            }

            _tiles = null;
            _overlays = null;
        }

        void FrameCamera()
        {
            float halfHeight = _level.Height * Cell * 0.5f + 1.4f;
            float halfWidth = _level.Width * Cell * 0.5f + 0.5f;
            float aspect = _camera.aspect <= 0.01f ? 0.56f : _camera.aspect;
            _camera.orthographicSize = Mathf.Max(halfHeight, halfWidth / aspect);
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

        void Update()
        {
            if (_run == null || !gameObject.activeInHierarchy) return;

            Session.RefreshLives();
            RefreshTimerFreeHud();

            if (_run.Status != LevelStatus.Playing) return;

            if (EventSystem.current != null && EventSystem.current.IsPointerOverGameObject()) return;

            if (!InputCompat.TryGetPointer(out Vector2 screen, out bool down, out _) || !down) return;

            // The camera sits at z = -10; the board is drawn on z = 0.
            var world = _camera.ScreenToWorldPoint(new Vector3(screen.x, screen.y, 10f));
            world -= _boardRoot.transform.position;
            var cell = CellAt(world);
            if (cell.HasValue) HandleTap(cell.Value);
        }

        void HandleTap(CellPos cell)
        {
            if (!_selected.HasValue)
            {
                _selected = cell;
                DrawBoard();
                return;
            }

            var from = _selected.Value;
            if (Mathf.Abs(from.X - cell.X) + Mathf.Abs(from.Y - cell.Y) != 1)
            {
                _selected = cell;
                DrawBoard();
                return;
            }

            _run.TrySwap(from.X, from.Y, cell.X, cell.Y);
            _selected = null;
            DrawBoard();
            AfterMove();
        }

        void AfterMove()
        {
            if (_run.Status == LevelStatus.Playing) return;
            if (_settled) return;

            _settled = true;
            Session.FinishAttempt(_run, out RewardBundle reward, out bool firstClear);
            ShowResult(reward, firstClear);
        }

        void ShowResult(RewardBundle reward, bool firstClear)
        {
            bool won = _run.Status == LevelStatus.Won;
            bool canPlayNext = won && Session.IsUnlocked(_levelNumber + 1);

            RtlText.Set(_resultTitle, won ? "مرحله کامل شد" : "حرکت تمام شد");

            if (won)
            {
                string body = firstClear
                    ? Core.Text.PersianText.Number(reward.Potions) + " معجون و " +
                      Core.Text.PersianText.Number(reward.Coins) + " سکه"
                    : "این مرحله قبلاً جایزه گرفته است";
                if (won && Session.IsChapterBuilt) body += "\nناحیه‌های فصل کامل شد";
                RtlText.Set(_resultBody, body);
            }
            else
            {
                int next = Session.Lives.NextRefillInSeconds;
                RtlText.Set(_resultBody, "یک جان کم شد\nجان بعدی تا " + Core.Text.PersianText.Time(next));
            }

            if (canPlayNext)
            {
                int nextLevel = _levelNumber + 1;
                RtlText.Set(_primaryLabel, "مرحله بعد");
                _primaryAction = () => PlayRequested?.Invoke(nextLevel);
                _primary.interactable = Session.BlockedReason(nextLevel) == null;
            }
            else if (won)
            {
                RtlText.Set(_primaryLabel, "ناحیه‌ها");
                _primaryAction = () => HomeRequested?.Invoke();
                _primary.interactable = true;
            }
            else
            {
                int retryLevel = _levelNumber;
                RtlText.Set(_primaryLabel, "تلاش دوباره");
                _primaryAction = () => PlayRequested?.Invoke(retryLevel);
                _primary.interactable = Session.Lives.Current > 0;
            }

            RtlText.Set(_secondaryLabel, "خانه");
            _secondaryAction = () => HomeRequested?.Invoke();

            _resultOverlay.gameObject.SetActive(true);
            _resultOverlay.SetAsLastSibling();
        }

        // ---- drawing ------------------------------------------------------------------------------

        void DrawBoard()
        {
            if (_run == null || _tiles == null) return;

            for (int y = 0; y < _level.Height; y++)
            {
                for (int x = 0; x < _level.Width; x++)
                {
                    int index = y * _level.Width + x;
                    var cell = _run.Board.At(x, y);
                    var baseRenderer = _tiles[index];
                    if (cell == null || baseRenderer == null) continue;

                    var overlay = _overlays[index];
                    var overlayColor = new Color(0f, 0f, 0f, 0f);

                    if (cell.Blocked)
                    {
                        baseRenderer.color = Tokens.Border;
                    }
                    else
                    {
                        baseRenderer.color = ColorFor(cell.Piece);

                        if (cell.HasObstacle)
                        {
                            baseRenderer.color = Color.Lerp(baseRenderer.color, Tokens.Bg, 0.45f);
                            overlayColor = cell.ObstacleLayers > 1 ? Tokens.BorderInput : Tokens.Border;
                        }

                        if (cell.PowerUp != PowerUpKind.None)
                            overlayColor = new Color(Tokens.Gold.r, Tokens.Gold.g, Tokens.Gold.b, 0.8f);

                        if (_selected.HasValue && _selected.Value.X == x && _selected.Value.Y == y)
                            overlayColor = Tokens.Accent;
                    }

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

        // ---- hud ----------------------------------------------------------------------------------

        void RefreshTimerFreeHud()
        {
            if (_run == null) return;

            if (_movesLabel != null && _run.Status == LevelStatus.Playing)
                RtlText.Set(_movesLabel, "حرکت " + Core.Text.PersianText.Number(_run.MovesLeft));
        }

        public override void Refresh()
        {
            if (Session == null) return;

            RtlText.Set(_levelLabel, "مرحله " + Core.Text.PersianText.Number(_levelNumber));

            if (_run != null)
            {
                RtlText.Set(_movesLabel, "حرکت " + Core.Text.PersianText.Number(_run.MovesLeft));
                RtlText.Set(_goalsLabel, GoalsText());
                RtlText.Set(_statusLabel, _run.Status == LevelStatus.Playing ? "" : "پایان مرحله");
            }
        }

        string GoalsText()
        {
            _goalsText.Length = 0;
            var goals = _run.Goals;
            for (int i = 0; i < goals.Count; i++)
            {
                if (i > 0) _goalsText.Append("  ·  ");
                var goal = goals.Goal(i);
                _goalsText.Append(goal.Kind == GoalKind.ClearPieces ? PieceWord(goal.Piece) : ObstacleWord(goal.Obstacle));
                _goalsText.Append(' ').Append(Core.Text.PersianText.Number(goals.Progress(i)));
                _goalsText.Append('/').Append(Core.Text.PersianText.Number(goals.Target(i)));
            }
            return _goalsText.ToString();
        }

        static string PieceWord(PieceKind kind)
        {
            switch (kind)
            {
                case PieceKind.Firouzeh: return "فیروزه";
                case PieceKind.Lajvard: return "لاجورد";
                case PieceKind.Aqiq: return "عقیق";
                case PieceKind.Zomorrod: return "زمرد";
                case PieceKind.Morvarid: return "مروارید";
                default: return "مهره";
            }
        }

        static string ObstacleWord(ObstacleKind kind)
        {
            switch (kind)
            {
                case ObstacleKind.Crate: return "جعبه";
                case ObstacleKind.Frost: return "یخ";
                case ObstacleKind.Ivy: return "پیچک";
                case ObstacleKind.Vial: return "شیشهٔ معجون";
                case ObstacleKind.Samovar: return "سماور";
                case ObstacleKind.FlowerPot: return "گلدان";
                case ObstacleKind.Chain: return "زنجیر";
                case ObstacleKind.Seal: return "مُهر";
                default: return "مانع";
            }
        }

        public override string ToString() => "BoardScreen(" + _levelNumber + ")";

        // Kept for the log when a level is misconfigured; the HUD shows the same information in Persian.
        public string DebugSummary()
        {
            if (_run == null) return "no run";
            var parts = new List<string>(2);
            for (int i = 0; i < _run.Goals.Count; i++)
                parts.Add(_run.Goals.Progress(i) + "/" + _run.Goals.Target(i));
            return "moves " + _run.MovesLeft + ", goals " + string.Join(",", parts.ToArray());
        }
    }
}
