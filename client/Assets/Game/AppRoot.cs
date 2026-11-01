using System.Collections.Generic;
using Shazdeh.Core;
using Shazdeh.Game.Ui;
using UnityEngine;

namespace Shazdeh.Game
{
    /// <summary>
    /// The one component a scene needs. It loads the save, builds the canvas and the three screens, and
    /// is the only thing that knows how they connect — screens call back up to it and never to each
    /// other, so the navigation graph is this file and nothing else.
    ///
    /// Nothing here is authored in the editor: the scene is a single GameObject, and every widget is
    /// built by code from the design tokens. That is why there is no prefab to break and why CI can
    /// build the game without opening Unity.
    /// </summary>
    public sealed class AppRoot : MonoBehaviour
    {
        const string Chapter = "ch01";

        IClock _clock;
        ISaveStore _store;
        GameSession _session;
        TopBar _topBar;
        HomeScreen _home;
        DistrictScreen _districts;
        BoardScreen _board;
        float _hudTimer;

        [Tooltip("Log every content and save problem to the console. Off in a store build.")]
        public bool verboseLog = true;

        void Awake()
        {
            _clock = new SystemClock();
            _store = new FileSaveStore(_clock);

            var errors = new List<string>();
            _session = GameSession.Load(_clock, _store, Chapter, errors);

            if (verboseLog)
            {
                for (int i = 0; i < errors.Count; i++) Debug.LogWarning("[boot] " + errors[i]);
                Debug.Log("[boot] save at " + _store.Location + " — level " + _session.CurrentLevel +
                          ", " + _session.Wallet.Potions + " potions, " + _session.Lives.Current + " lives");
            }

            // The canvas stays at the scene root on purpose: a ScreenSpaceOverlay canvas is happiest
            // there, and the screens are its children.
            var canvas = UiKit.CreateCanvas("ShazdehCanvas");

            _topBar = TopBar.Create(canvas.transform, _session);

            _home = CreateScreen<HomeScreen>(canvas.transform, "HomeScreen");
            _home.PlayRequested = () => Play(_session.CurrentLevel);
            _home.DistrictsRequested = ShowDistricts;

            _districts = CreateScreen<DistrictScreen>(canvas.transform, "DistrictScreen");
            _districts.BackRequested = ShowHome;

            _board = CreateScreen<BoardScreen>(canvas.transform, "BoardScreen");
            _board.HomeRequested = ShowHome;
            _board.PlayRequested = Play;

            _session.Changed += RefreshAll;
            _session.RefreshLives();

            ShowHome();
        }

        void OnDestroy()
        {
            if (_session != null) _session.Changed -= RefreshAll;
        }

        T CreateScreen<T>(Transform parent, string name) where T : UiScreen
        {
            var go = new GameObject(name, typeof(RectTransform));
            go.transform.SetParent(parent, false);

            var screen = go.AddComponent<T>();
            screen.Init(_session);
            go.SetActive(false);
            return screen;
        }

        // ---- navigation ---------------------------------------------------------------------------

        void ShowHome()
        {
            _home.SetVisible(true);
            _districts.SetVisible(false);
            _board.SetVisible(false);

            _home.Refresh();
            _topBar.Refresh();
        }

        void ShowDistricts()
        {
            _home.SetVisible(false);
            _board.SetVisible(false);
            _districts.SetVisible(true);

            _districts.Refresh();
            _topBar.Refresh();
        }

        /// <summary>Starts a level if it may be started; otherwise stays on the home screen, which explains why.</summary>
        void Play(int level)
        {
            if (_session.BlockedReason(level) != null)
            {
                ShowHome();
                _home.Refresh();
                return;
            }

            _home.SetVisible(false);
            _districts.SetVisible(false);
            _board.SetVisible(true);

            _board.StartLevel(level);
            _topBar.Refresh();
        }

        void RefreshAll()
        {
            _topBar.Refresh();
            if (_home.gameObject.activeSelf) _home.Refresh();
            if (_districts.gameObject.activeSelf) _districts.Refresh();
            if (_board.gameObject.activeSelf) _board.Refresh();
        }

        // ---- ticks --------------------------------------------------------------------------------

        void Update()
        {
            if (_session == null) return;

            // Lives refill from a timestamp, so nothing has to wake up: this only notices that the
            // clock moved and repaints the counter.
            _session.RefreshLives();

            _hudTimer += Time.unscaledDeltaTime;
            if (_hudTimer >= 1f)
            {
                _hudTimer = 0f;
                _topBar.Refresh();
                if (_home.gameObject.activeSelf) _home.Refresh();
            }
        }

        /// <summary>For the editor tools: the session without building a scene.</summary>
        public GameSession Session => _session;
    }
}
