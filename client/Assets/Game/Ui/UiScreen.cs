using UnityEngine;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// One full-screen view. A screen builds its widgets once and then only refreshes numbers, so the
    /// garbage collector sees nothing while the player is tapping.
    ///
    /// Named UiScreen, not Screen: inside this namespace `Screen` would shadow UnityEngine.Screen and
    /// quietly break any file that wants to read the display size.
    ///
    /// Screens do not navigate: they call back into <see cref="AppRoot"/> through the delegates it sets,
    /// which keeps the arrow of dependency one-way (AppRoot knows every screen, a screen knows none).
    /// </summary>
    public abstract class UiScreen : MonoBehaviour
    {
        protected GameSession Session { get; private set; }

        protected RectTransform Root { get; private set; }

        protected bool Built { get; private set; }

        public void Init(GameSession session)
        {
            if (Built) return;

            Session = session;
            Root = (RectTransform)transform;
            Root.anchorMin = Vector2.zero;
            Root.anchorMax = Vector2.one;
            Root.pivot = new Vector2(0.5f, 0.5f);
            Root.offsetMin = Vector2.zero;
            Root.offsetMax = Vector2.zero;

            Build();
            Built = true;
            Refresh();
        }

        /// <summary>Creates the widgets. Called once.</summary>
        protected abstract void Build();

        /// <summary>Updates the widgets from the session. Called whenever the session changes.</summary>
        public abstract void Refresh();

        public void SetVisible(bool visible)
        {
            if (gameObject.activeSelf != visible) gameObject.SetActive(visible);
        }
    }
}
