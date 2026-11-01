using System;
using System.Collections.Generic;
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

        // Motion, in seconds. These are the numbers a playtest would tune; keeping them here means
        // "the game feels slow" is a one-line change and not a hunt through the file.
        const float SwapSeconds = 0.12f;
        const float ClearSeconds = 0.14f;
        const float SettleSeconds = 0.19f;
        const float RejectSeconds = 0.16f;
        const float SwipeCells = 0.45f;  // a drag shorter than this is a tap, not a swipe

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
        TextMeshProUGUI _hintLabel;

        const int MaxGoalChips = 3;
        readonly RectTransform[] _goalChip = new RectTransform[MaxGoalChips];
        readonly Image[] _goalChipIcon = new Image[MaxGoalChips];
        readonly TextMeshProUGUI[] _goalChipLabel = new TextMeshProUGUI[MaxGoalChips];

        string _hint;
        float _hintUntil;

        // ---- motion --------------------------------------------------------------------------------

        struct TileTween
        {
            public int Index;
            public Vector3 FromPosition;
            public Vector3 ToPosition;
            public Vector3 FromScale;
            public Vector3 ToScale;
            public float Delay;
            public float Duration;
        }

        readonly List<TileTween> _tweens = new List<TileTween>(48);
        readonly List<int> _clearedCells = new List<int>(24);
        float _tweenClock;
        Action _tweenDone;

        // Input: a press is remembered in board space so the release can be read as a direction.
        bool _pressActive;
        Vector3 _pressWorld;

        RectTransform _resultOverlay;
        Image _resultBanner;
        readonly Image[] _resultStars = new Image[3];
        float _resultShownAt;
        TextMeshProUGUI _resultTitle;
        TextMeshProUGUI _resultBody;
        Button _primary;
        Button _secondary;
        TextMeshProUGUI _primaryLabel;
        TextMeshProUGUI _secondaryLabel;
        Action _primaryAction;
        Action _secondaryAction;


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

            BuildGoalChips();

            _hintLabel = UiKit.Label(Root, "hint", "", Tokens.Type.Xs, Tokens.TextMuted, TextAlignmentOptions.Center);
            UiKit.Place(_hintLabel.rectTransform, 20f, 120f, UiKit.CanvasWidth - 40f, 18f);
        }

        /// <summary>
        /// One chip per goal, right to left because the language is: icon, then "۴ از ۱۲". The chips
        /// are built once at full width and switched off when a level has fewer goals, which keeps the
        /// layout from moving between levels.
        /// </summary>
        void BuildGoalChips()
        {
            const float gap = 6f;
            const float height = 30f;
            const float icon = 20f;
            float width = (UiKit.CanvasWidth - 40f - gap * (MaxGoalChips - 1)) / MaxGoalChips;

            for (int i = 0; i < MaxGoalChips; i++)
            {
                float x = UiKit.CanvasWidth - 20f - width - i * (width + gap);
                var chip = UiKit.Panel(Root, "goal_" + i, x, 86f, width, height, Tokens.SurfaceRaised, (int)Tokens.Radius.Md);

                var iconRect = UiKit.Panel(chip, "icon", width - icon - 6f, (height - icon) * 0.5f, icon, icon,
                    new Color(1f, 1f, 1f, 0f));
                _goalChipIcon[i] = iconRect.GetComponent<Image>();
                _goalChipIcon[i].raycastTarget = false;

                _goalChipLabel[i] = UiKit.Label(chip, "value", "", Tokens.Type.Sm, Tokens.Text, TextAlignmentOptions.Center);
                UiKit.Place(_goalChipLabel[i].rectTransform, 4f, 0f, width - icon - 10f, height);

                _goalChip[i] = chip;
                chip.gameObject.SetActive(false);
            }
        }

        void BuildResultOverlay()
        {
            var dim = UiKit.Background(Root, new Color(Tokens.Bg.r, Tokens.Bg.g, Tokens.Bg.b, 0.88f));
            dim.name = "result";
            dim.GetComponent<Image>().raycastTarget = true;
            _resultOverlay = dim;

            float cardWidth = UiKit.CanvasWidth - 40f;
            var card = UiKit.Panel(dim, "card", 20f, 176f, cardWidth, 386f, Tokens.Surface, (int)Tokens.Radius.Panel);

            // The plaque is drawn art (result_win / result_lose, 720×200 at the same 3.6:1 ratio) and
            // the title sits on its dark middle. When the sprite is missing the title still reads on
            // the card, so the screen never depends on art existing.
            var banner = UiKit.Panel(card, "banner", 20f, 6f, cardWidth - 40f, (cardWidth - 40f) / 3.6f,
                new Color(1f, 1f, 1f, 0f));
            _resultBanner = banner.GetComponent<Image>();
            _resultBanner.raycastTarget = false;
            _resultBanner.enabled = false;

            _resultTitle = UiKit.LabelBold(card, "title", "", Tokens.Type.Xl, Tokens.Gold, TextAlignmentOptions.Center);
            UiKit.Place(_resultTitle.rectTransform, 16f, 32f, cardWidth - 32f, 40f);

            for (int i = 0; i < _resultStars.Length; i++)
            {
                const float size = 44f;
                const float gap = 10f;
                float total = _resultStars.Length * size + (_resultStars.Length - 1) * gap;
                float x = (cardWidth - total) * 0.5f + i * (size + gap);
                var star = UiKit.Panel(card, "star_" + i, x, 104f, size, size, new Color(1f, 1f, 1f, 0f));
                var image = star.GetComponent<Image>();
                image.raycastTarget = false;
                if (ArtLibrary.ApplyTo(image, "icon_star")) image.color = Tokens.TextMuted;
                else image.color = new Color(1f, 1f, 1f, 0f);
                _resultStars[i] = image;
            }

            _resultBody = UiKit.Label(card, "body", "", Tokens.Type.Base, Tokens.Text, TextAlignmentOptions.Center);
            UiKit.Place(_resultBody.rectTransform, 24f, 160f, cardWidth - 48f, 76f);

            _primary = UiKit.Button(card, "primary", "", 24f, 250f, cardWidth - 48f, 54f,
                Tokens.Accent, Tokens.OnAccent, () => _primaryAction?.Invoke(), (int)Tokens.Radius.Md);
            _primaryLabel = _primary.GetComponentInChildren<TextMeshProUGUI>();

            _secondary = UiKit.Button(card, "secondary", "خانه", 24f, 314f, cardWidth - 48f, 46f,
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
            StopMotion();
            ClearHint();

            ClearTiles();
            _resultOverlay.gameObject.SetActive(false);
            _camera.enabled = true;

            if (_run == null)
            {
                RtlText.Set(_levelLabel, "مرحله " + Core.Text.PersianText.Number(number));
                ShowHint(error, 600f);
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
                    overlayGo.transform.localScale = Vector3.one * OverlayScale;
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

            // Motion runs even when the level is over: the last cascade still has to play, and the
            // overlay is shown when it finishes rather than on top of it.
            AdvanceTweens();
            AnimateResultStars();

            Session.RefreshLives();
            RefreshTimerFreeHud();

            if (_run.Status != LevelStatus.Playing) return;
            if (_tweens.Count > 0) return;
            if (EventSystem.current != null && EventSystem.current.IsPointerOverGameObject()) return;
            if (!InputCompat.TryGetPointer(out Vector2 screen, out bool down, out bool up)) return;

            var world = BoardPoint(screen);

            if (down)
            {
                // A press is not a tap yet: it becomes either a tap or a swipe when it is released.
                _pressActive = CellAt(world).HasValue;
                _pressWorld = world;
                return;
            }

            if (!up || !_pressActive) return;
            _pressActive = false;

            Vector3 drag = world - _pressWorld;
            drag.z = 0f;

            if (drag.magnitude >= Cell * SwipeCells)
            {
                var origin = CellAt(_pressWorld);
                if (!origin.HasValue) return;
                var target = Neighbour(origin.Value, drag);
                if (target.HasValue) Play(origin.Value, target.Value);
                return;
            }

            var cell = CellAt(world);
            if (cell.HasValue) HandleTap(cell.Value);
        }

        /// <summary>Screen point to board-local space: the camera sits at z = -10, the board at z = 0.</summary>
        Vector3 BoardPoint(Vector2 screen)
        {
            var world = _camera.ScreenToWorldPoint(new Vector3(screen.x, screen.y, 10f));
            return world - _boardRoot.transform.position;
        }

        /// <summary>The cell a drag points at, or null when the drag leaves the board.</summary>
        CellPos? Neighbour(CellPos from, Vector3 drag)
        {
            int dx = 0, dy = 0;
            if (Mathf.Abs(drag.x) >= Mathf.Abs(drag.y)) dx = drag.x > 0f ? 1 : -1;
            else dy = drag.y > 0f ? 1 : -1;

            var to = new CellPos(from.X + dx, from.Y + dy);
            if (to.X < 0 || to.Y < 0 || to.X >= _level.Width || to.Y >= _level.Height) return null;
            return to;
        }

        /// <summary>
        /// Tap-to-select stays: it is the forgiving path for a player who cannot swipe reliably, and
        /// it is the only path that works with a keyboard or accessibility switch. A second tap on a
        /// neighbour plays the move; a second tap elsewhere moves the selection.
        /// </summary>
        void HandleTap(CellPos cell)
        {
            if (_selected.HasValue)
            {
                var from = _selected.Value;
                if (from.X == cell.X && from.Y == cell.Y)
                {
                    _selected = null;
                    DrawBoard();
                    return;
                }

                if (Mathf.Abs(from.X - cell.X) + Mathf.Abs(from.Y - cell.Y) == 1)
                {
                    Play(from, cell);
                    return;
                }
            }

            _selected = cell;
            DrawBoard();
        }

        // ---- a turn ---------------------------------------------------------------------------------

        /// <summary>
        /// One player action, start to finish: the model decides, then the view plays what the model
        /// said happened. Nothing here is allowed to change the board — it only reads the events.
        /// </summary>
        void Play(CellPos from, CellPos to)
        {
            if (_run == null || _run.Status != LevelStatus.Playing) return;
            if (_tweens.Count > 0) return;

            var result = _run.TrySwap(from.X, from.Y, to.X, to.Y);
            _selected = null;

            if (result == null || !result.Accepted)
            {
                PlayRejected(from, to);
                return;
            }

            PlaySwap(from, to, result);
        }

        void PlayRejected(CellPos from, CellPos to)
        {
            ClearHint();
            DrawBoard();

            // Push the two pieces towards each other and let them spring back: the cheapest way to
            // say "that is not a move" without a modal, and it cannot be misread as a hint.
            _tweenDone = null;
            int a = Index(from), b = Index(to);
            if (a < 0 || b < 0) return;

            Vector3 pa = WorldOf(from);
            Vector3 pb = WorldOf(to);
            Vector3 push = (pb - pa).normalized * 0.16f;

            AddTween(a, pa + push, pa, Vector3.one, Vector3.one, 0f, RejectSeconds);
            AddTween(b, pb - push, pb, Vector3.one, Vector3.one, 0f, RejectSeconds);
        }

        void PlaySwap(CellPos from, CellPos to, MoveResult result)
        {
            int a = Index(from), b = Index(to);
            Vector3 pa = WorldOf(from);
            Vector3 pb = WorldOf(to);

            // Each tile carries its own piece across, which is what a swap looks like; the redraw
            // afterwards puts both tiles back on their cells.
            AddTween(a, pa, pb, Vector3.one, Vector3.one, 0f, SwapSeconds);
            AddTween(b, pb, pa, Vector3.one, Vector3.one, 0f, SwapSeconds);

            _clearedCells.Clear();
            var events = result.Events;
            for (int i = 0; i < events.Count; i++)
            {
                if (events[i] is PieceClearedEvent cleared)
                {
                    int index = Index(cleared.Position);
                    if (index >= 0 && !_clearedCells.Contains(index)) _clearedCells.Add(index);
                }
            }

            _tweenDone = () =>
            {
                ResetTiles();
                DrawBoard();
                PlayClear();
            };
        }

        void PlayClear()
        {
            if (_clearedCells.Count == 0)
            {
                SettleTurn();
                return;
            }

            for (int i = 0; i < _clearedCells.Count; i++)
            {
                int index = _clearedCells[i];
                Vector3 rest = RestOf(index);
                // A cleared piece rises a little as it shrinks, so the eye reads "taken" not "gone".
                AddTween(index, rest, rest + Vector3.up * 0.14f, Vector3.one, Vector3.one * 0.08f, 0f, ClearSeconds);
            }

            _tweenDone = () =>
            {
                ResetTiles();
                DrawBoard();
                PlaySettle();
            };
        }

        void PlaySettle()
        {
            // Everything above a cleared cell falls into the gap. Columns are independent, so the
            // stagger is a row distance and the whole thing stays predictable frame to frame.
            int width = _level.Width;
            for (int i = 0; i < _clearedCells.Count; i++)
            {
                int index = _clearedCells[i];
                int column = index % width;
                int lowest = index / width;

                for (int y = lowest + 1; y < _level.Height; y++)
                {
                    int falling = y * width + column;
                    if (_tiles[falling] == null) continue;
                    if (AlreadyDropping(falling)) continue;

                    int steps = y - lowest;
                    Vector3 rest = WorldOf(new CellPos(column, y));
                    _tiles[falling].transform.localPosition = rest + Vector3.up * (0.35f + 0.10f * steps);
                    _tiles[falling].transform.localScale = Vector3.one * 0.72f;

                    AddTween(falling, rest + Vector3.up * (0.35f + 0.10f * steps), rest,
                        Vector3.one * 0.72f, Vector3.one, 0.012f * steps, SettleSeconds);
                }
            }

            _tweenDone = () =>
            {
                ResetTiles();
                DrawBoard();
                SettleTurn();
            };

            // Nothing to drop (a clear at the very top row): finish the turn now, without leaving a
            // callback behind for the next tween to trip over.
            if (_tweens.Count == 0)
            {
                var done = _tweenDone;
                _tweenDone = null;
                done?.Invoke();
            }
        }

        /// <summary>Two clears in one column would otherwise queue the same cell twice.</summary>
        bool AlreadyDropping(int index)
        {
            for (int i = 0; i < _tweens.Count; i++)
                if (_tweens[i].Index == index) return true;
            return false;
        }

        void SettleTurn()
        {
            _clearedCells.Clear();
            DrawBoard();
            Refresh();
            AfterMove();
        }

        void AfterMove()
        {
            if (_run == null) return;
            if (_run.Status == LevelStatus.Playing) return;
            if (_settled) return;

            _settled = true;
            Session.FinishAttempt(_run, out RewardBundle reward, out bool firstClear);
            ShowResult(reward, firstClear);
        }

        // ---- tweening --------------------------------------------------------------------------------

        int Index(CellPos cell)
        {
            if (_level == null) return -1;
            if (cell.X < 0 || cell.Y < 0 || cell.X >= _level.Width || cell.Y >= _level.Height) return -1;
            return cell.Y * _level.Width + cell.X;
        }

        Vector3 RestOf(int index)
        {
            if (_level == null || _level.Width <= 0) return Vector3.zero;
            return WorldOf(new CellPos(index % _level.Width, index / _level.Width));
        }

        void AddTween(int index, Vector3 fromPosition, Vector3 toPosition, Vector3 fromScale, Vector3 toScale,
            float delay, float duration)
        {
            if (_tiles == null || index < 0 || index >= _tiles.Length || _tiles[index] == null) return;

            _tweens.Add(new TileTween
            {
                Index = index,
                FromPosition = fromPosition,
                ToPosition = toPosition,
                FromScale = fromScale,
                ToScale = toScale,
                Delay = delay,
                Duration = duration
            });
        }

        void StopMotion()
        {
            _tweens.Clear();
            _tweenDone = null;
            _tweenClock = 0f;
            _clearedCells.Clear();
            _pressActive = false;
        }

        void AdvanceTweens()
        {
            if (_tweens.Count == 0) return;

            _tweenClock += Time.deltaTime;
            bool finished = true;

            for (int i = 0; i < _tweens.Count; i++)
            {
                var tween = _tweens[i];
                var tile = _tiles != null && tween.Index < _tiles.Length ? _tiles[tween.Index] : null;
                if (tile == null) continue;

                float progress = tween.Duration <= 0f
                    ? 1f
                    : Mathf.Clamp01((_tweenClock - tween.Delay) / tween.Duration);
                if (progress < 1f) finished = false;

                float eased = EaseOutCubic(progress);
                tile.transform.localPosition = Vector3.LerpUnclamped(tween.FromPosition, tween.ToPosition, eased);
                tile.transform.localScale = Vector3.LerpUnclamped(tween.FromScale, tween.ToScale, eased);
            }

            if (!finished) return;

            _tweens.Clear();
            _tweenClock = 0f;
            var done = _tweenDone;
            _tweenDone = null;
            done?.Invoke();
        }

        static float EaseOutCubic(float t)
        {
            float inverted = 1f - t;
            return 1f - inverted * inverted * inverted;
        }

        static float EaseOutBack(float t)
        {
            const float overshoot = 1.70158f;
            float shifted = t - 1f;
            return 1f + (overshoot + 1f) * shifted * shifted * shifted + overshoot * shifted * shifted;
        }

        /// <summary>Puts every tile back exactly where the board says it lives.</summary>
        void ResetTiles()
        {
            if (_tiles == null) return;

            for (int i = 0; i < _tiles.Length; i++)
            {
                if (_tiles[i] == null) continue;
                _tiles[i].transform.localPosition = RestOf(i);
                _tiles[i].transform.localScale = Vector3.one;
            }
        }

        void AnimateResultStars()
        {
            if (_resultOverlay == null || !_resultOverlay.gameObject.activeSelf) return;

            float elapsed = Time.unscaledTime - _resultShownAt;
            for (int i = 0; i < _resultStars.Length; i++)
            {
                if (_resultStars[i] == null) continue;

                float local = Mathf.Clamp01((elapsed - 0.10f * i) / 0.22f);
                float scale = local <= 0f ? 0f : EaseOutBack(local);
                _resultStars[i].rectTransform.localScale = Vector3.one * scale;
            }
        }

        void ShowResult(RewardBundle reward, bool firstClear)
        {
            bool won = _run.Status == LevelStatus.Won;
            bool canPlayNext = won && Session.IsUnlocked(_levelNumber + 1);
            int stars = StarRating.FromRun(_run);

            RtlText.Set(_resultTitle, won ? "مرحله کامل شد" : "حرکت تمام شد");

            if (won)
            {
                string body = firstClear
                    ? Core.Text.PersianText.Number(reward.Potions) + " معجون و " +
                      Core.Text.PersianText.Number(reward.Coins) + " سکه"
                    : "این مرحله قبلاً جایزه گرفته است";

                if (stars < StarRating.Max)
                {
                    StarRating.TwoStarAt(_level.MoveLimit, out int second, out int third);
                    int needed = stars == StarRating.Min ? second : third;
                    body += "\nبرای ستاره بعدی " + Core.Text.PersianText.Number(needed) + " حرکت مانده لازم است";
                }

                if (Session.IsChapterBuilt) body += "\nناحیه‌های فصل کامل شد";
                RtlText.Set(_resultBody, body);
            }
            else
            {
                int next = Session.Lives.NextRefillInSeconds;
                RtlText.Set(_resultBody, "یک جان کم شد\nجان بعدی تا " + Core.Text.PersianText.Time(next));
            }

            ShowStars(stars);
            ShowBanner(won);

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

            _resultShownAt = Time.unscaledTime;
            _resultOverlay.gameObject.SetActive(true);
            _resultOverlay.SetAsLastSibling();
            AnimateResultStars();
        }

        /// <summary>Earned stars are gold, the rest are outlines: the count is readable at a glance.</summary>
        void ShowStars(int stars)
        {
            for (int i = 0; i < _resultStars.Length; i++)
            {
                var image = _resultStars[i];
                if (image == null || image.sprite == null) continue;

                image.color = i < stars ? Tokens.Gold : new Color(Tokens.TextMuted.r, Tokens.TextMuted.g, Tokens.TextMuted.b, 0.30f);
            }
        }

        void ShowBanner(bool won)
        {
            if (_resultBanner == null) return;

            bool drawn = ArtLibrary.ApplyTo(_resultBanner, won ? "result_win" : "result_lose");
            _resultBanner.enabled = drawn;
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

                    // Reset both renderers to the placeholder state; art opts in below. Redrawing from a
                    // known state is what keeps this function honest after a sprite swap.
                    baseRenderer.sprite = _square;
                    baseRenderer.transform.localScale = Vector3.one;
                    overlay.sprite = _square;
                    overlay.transform.localScale = Vector3.one * OverlayScale;

                    if (cell.Blocked)
                    {
                        baseRenderer.color = Tokens.Border;
                        overlay.color = overlayColor;
                        continue;
                    }

                    // The piece: art if the file exists, a token colour if not.
                    bool pieceArt = ArtLibrary.ApplyTo(baseRenderer, PieceId(cell.Piece), Cell * 0.94f);
                    if (!pieceArt) baseRenderer.color = ColorFor(cell.Piece);
                    else if (cell.HasObstacle) baseRenderer.color = Color.Lerp(Color.white, Tokens.Bg, 0.45f);

                    if (cell.HasObstacle && !ArtLibrary.ApplyTo(overlay, ObstacleId(cell.Obstacle), Cell * 0.9f))
                        overlayColor = cell.ObstacleLayers > 1 ? Tokens.BorderInput : Tokens.Border;

                    if (cell.PowerUp != PowerUpKind.None && !ArtLibrary.ApplyTo(overlay, PowerUpId(cell.PowerUp), Cell * 0.8f))
                        overlayColor = new Color(Tokens.Gold.r, Tokens.Gold.g, Tokens.Gold.b, 0.8f);

                    if (_selected.HasValue && _selected.Value.X == x && _selected.Value.Y == y)
                        overlayColor = Tokens.Accent;

                    overlay.color = overlayColor;
                }
            }
        }

        const float OverlayScale = 0.74f;

        static string PieceId(PieceKind kind)
        {
            switch (kind)
            {
                case PieceKind.Firouzeh: return "piece_firouzeh";
                case PieceKind.Lajvard: return "piece_lajvard";
                case PieceKind.Aqiq: return "piece_aqiq";
                case PieceKind.Zomorrod: return "piece_zomorrod";
                case PieceKind.Morvarid: return "piece_morvarid";
                default: return "";
            }
        }

        static string ObstacleId(ObstacleKind kind)
        {
            switch (kind)
            {
                case ObstacleKind.Crate: return "obstacle_crate";
                case ObstacleKind.Frost: return "obstacle_frost";
                case ObstacleKind.Ivy: return "obstacle_ivy";
                case ObstacleKind.Vial: return "obstacle_vial";
                case ObstacleKind.Samovar: return "obstacle_samovar";
                case ObstacleKind.FlowerPot: return "obstacle_flowerpot";
                case ObstacleKind.Chain: return "obstacle_chain";
                case ObstacleKind.Seal: return "obstacle_seal";
                default: return "";
            }
        }

        static string PowerUpId(PowerUpKind kind)
        {
            switch (kind)
            {
                case PowerUpKind.RocketVertical: return "powerup_rocket_col";
                case PowerUpKind.RocketHorizontal: return "powerup_rocket_row";
                case PowerUpKind.Spinner: return "powerup_spinner";
                case PowerUpKind.Dynamite: return "powerup_dynamite";
                case PowerUpKind.ElectroBall: return "powerup_electro";
                case PowerUpKind.SuperElectroBall: return "powerup_electro";
                default: return "";
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
            if (_run == null) return;

            RtlText.Set(_movesLabel, "حرکت " + Core.Text.PersianText.Number(_run.MovesLeft));
            RefreshGoalChips();

            if (_hint == null || Time.unscaledTime >= _hintUntil) ClearHint();
        }

        /// <summary>
        /// Each goal is one chip: its icon, then "۴ از ۱۲". A finished goal goes gold and stops
        /// changing, which is the only feedback that matters while the board is busy.
        /// </summary>
        void RefreshGoalChips()
        {
            var goals = _run.Goals;

            for (int i = 0; i < MaxGoalChips; i++)
            {
                if (i >= goals.Count)
                {
                    if (_goalChip[i] != null) _goalChip[i].gameObject.SetActive(false);
                    continue;
                }

                if (_goalChip[i] != null) _goalChip[i].gameObject.SetActive(true);

                var goal = goals.Goal(i);
                bool done = goals.IsComplete(i);
                RtlText.SetFraction(_goalChipLabel[i], goals.Progress(i), goals.Target(i));
                if (_goalChipLabel[i] != null)
                    _goalChipLabel[i].color = done ? Tokens.Gold : Tokens.Text;

                string iconId = goal.Kind == GoalKind.ClearPieces ? PieceId(goal.Piece) : ObstacleId(goal.Obstacle);
                var icon = _goalChipIcon[i];
                if (icon == null) continue;

                bool drawn = ArtLibrary.Get(iconId) != null;
                if (drawn)
                {
                    ArtLibrary.ApplyTo(icon, iconId);
                    icon.color = done ? Color.white : new Color(1f, 1f, 1f, 0.86f);
                }
                else
                {
                    icon.sprite = null;
                    icon.color = done ? Tokens.Gold : ColorFor(goal.Piece);
                }
            }
        }

        // ---- the hint line --------------------------------------------------------------------------

        void ShowHint(string text, float seconds)
        {
            _hint = text;
            _hintUntil = Time.unscaledTime + seconds;
            RtlText.Set(_hintLabel, text);
        }

        void ClearHint()
        {
            if (_hint == null) return;

            _hint = null;
            _hintUntil = 0f;
            RtlText.Set(_hintLabel, "");
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
