using UnityEngine;

namespace Shazdeh.Game
{
    /// <summary>
    /// The design-system check, in the engine, before any screen is built: every colour role, the type
    /// scale, spacing, radius and the component states from replica/design/components.md, drawn from
    /// the same Tokens class the game uses. If a value here looks wrong, the token is wrong — fix it in
    /// tokens.json and regenerate, never here.
    ///
    /// IMGUI on purpose: it needs no prefabs, no font assets and no canvas, so it runs on the first
    /// frame of a brand-new project.
    /// </summary>
    public sealed class DesignSystemView : MonoBehaviour
    {
        GUIStyle _label;
        GUIStyle _heading;
        Vector2 _scroll;

        Texture2D Swatch(Color color)
        {
            var texture = new Texture2D(1, 1, TextureFormat.RGBA32, false);
            texture.SetPixel(0, 0, color);
            texture.Apply();
            texture.hideFlags = HideFlags.DontSave;
            return texture;
        }

        GUIStyle Box(Color color)
        {
            var style = new GUIStyle(GUI.skin.box);
            style.normal.background = Swatch(color);
            return style;
        }

        void EnsureStyles()
        {
            if (_label != null) return;
            _label = new GUIStyle(GUI.skin.label) { fontSize = 14 };
            _heading = new GUIStyle(GUI.skin.label) { fontSize = 20, fontStyle = FontStyle.Bold };
        }

        void OnGUI()
        {
            EnsureStyles();
            GUI.color = Color.white;
            GUI.DrawTexture(new Rect(0, 0, Screen.width, Screen.height), Swatch(Tokens.Bg));

            _scroll = GUI.BeginScrollView(new Rect(0, 0, Screen.width, Screen.height), _scroll,
                new Rect(0, 0, 1000, 1750));

            float y = 16f;
            GUI.Label(new Rect(16, y, 960, 30), "کاخ شازده — design system (grey box)", _heading);
            y += 40f;
            GUI.Label(new Rect(16, y, 960, 22), "Tokens.gen.cs is generated from replica/design/tokens.json. 19 pairs, 0 AA failures.", _label);
            y += 34f;

            y = Section(y, "Colour roles");
            y = Swatches(y,
                new[] { "bg", "surface", "surface-raised", "border", "border-input", "text", "text-muted",
                        "accent", "accent-strong", "on-accent", "gold", "on-gold",
                        "danger", "danger-strong", "on-danger", "success", "warning" },
                new[] { Tokens.Bg, Tokens.Surface, Tokens.SurfaceRaised, Tokens.Border, Tokens.BorderInput,
                        Tokens.Text, Tokens.TextMuted, Tokens.Accent, Tokens.AccentStrong, Tokens.OnAccent,
                        Tokens.Gold, Tokens.OnGold, Tokens.Danger, Tokens.DangerStrong, Tokens.OnDanger,
                        Tokens.Success, Tokens.Warning });

            y = Section(y, "Stones (not text — silhouette + emblem carry the meaning)");
            y = Swatches(y,
                new[] { "firouzeh", "lajvard", "aqiq", "zomorrod", "morvarid" },
                new[] { Tokens.Piece.Firouzeh, Tokens.Piece.Lajvard, Tokens.Piece.Aqiq,
                        Tokens.Piece.Zomorrod, Tokens.Piece.Morvarid });

            y = Section(y, "Type scale (Vazirmatn / Estedad in production; IMGUI default font here)");
            string[] names = { "xs 12", "sm 14", "base 16", "lg 20", "xl 26", "display 34" };
            float[] sizes = { Tokens.Type.Xs, Tokens.Type.Sm, Tokens.Type.Base, Tokens.Type.Lg, Tokens.Type.Xl, Tokens.Type.Display };
            for (int i = 0; i < sizes.Length; i++)
            {
                var style = new GUIStyle(GUI.skin.label) { fontSize = (int)sizes[i] };
                GUI.Label(new Rect(16, y, 960, sizes[i] + 8), names[i] + "  —  کاخ شازده ۱۲۳۴۵", style);
                y += sizes[i] + 12;
            }
            y += 8;

            y = Section(y, "Spacing / radius");
            float[] spaces = { Tokens.Space.S0, Tokens.Space.S1, Tokens.Space.S2, Tokens.Space.S3,
                               Tokens.Space.S4, Tokens.Space.S5, Tokens.Space.S6, Tokens.Space.S7 };
            for (int i = 0; i < spaces.Length; i++)
            {
                GUI.Label(new Rect(16, y, 60, 20), "S" + i + " (" + spaces[i] + ")", _label);
                GUI.Box(new Rect(110, y + 4, spaces[i], 14), "", Box(Tokens.Accent));
                y += 22;
            }
            GUI.Label(new Rect(16, y, 960, 20), "radius sm 8 · md 14 · lg 22 · panel 28 · pill 999", _label);
            y += 30;

            y = Section(y, "Button states");
            y = ButtonRow(y, "primary", Tokens.Accent, Tokens.OnAccent);
            y = ButtonRow(y, "secondary", Tokens.Text, Tokens.Bg);
            y = ButtonRow(y, "gold", Tokens.Gold, Tokens.OnGold);
            y = ButtonRow(y, "danger", Tokens.DangerStrong, Tokens.OnDanger);
            y = ButtonRow(y, "disabled", Blend(Tokens.Surface, Tokens.Bg, 0.5f), Tokens.TextMuted);

            y = Section(y, "HUD pieces");
            Pill(new Rect(16, y, 120, 36), Tokens.SurfaceRaised, Tokens.Gold, "coins 1,240");
            Pill(new Rect(148, y, 120, 36), Tokens.SurfaceRaised, Tokens.Gold, "potions 350");
            Pill(new Rect(280, y, 120, 36), Tokens.SurfaceRaised, Tokens.Danger, "lives 4");
            y += 46;
            GoalChip(new Rect(16, y, 150, 44), "aqiq", 12, 18, true);
            GoalChip(new Rect(176, y, 150, 44), "crate", 1, 3, false);
            y += 56;
            ProgressBar(new Rect(16, y, 420, 16), 0.58f);
            GUI.Label(new Rect(446, y - 2, 200, 20), "district 4/7", _label);
            y += 36;

            y = Section(y, "Panel + modal");
            GUI.Box(new Rect(16, y, 420, 120), "", Box(Tokens.Surface));
            GUI.Label(new Rect(32, y + 12, 380, 24), "Panel: surface, radius 28, gold hairline", _label);
            GUI.Label(new Rect(32, y + 40, 380, 24), "Scrim bg 72% behind modals", _label);
            GUI.Label(new Rect(32, y + 68, 380, 24), "Muqarnas crown arrives with the art", _label);
            y += 140;

            y = Section(y, "Notes");
            GUI.Label(new Rect(16, y, 960, 22), "IMGUI cannot shape Persian text, so this screen is Latin on purpose. Persian is tested in the real UI (TMP + Vazirmatn) from M1.", _label);
            y += 26;
            GUI.Label(new Rect(16, y, 960, 22), "Nothing here is a screen: it is the checklist components.md asks for before any screen exists.", _label);

            GUI.EndScrollView();
        }

        float Section(float y, string title)
        {
            GUI.Label(new Rect(16, y, 960, 26), title, _heading);
            return y + 30;
        }

        float Swatches(float y, string[] names, Color[] colors)
        {
            const float size = 56f;
            for (int i = 0; i < colors.Length; i++)
            {
                float x = 16 + (i % 8) * (size + 66);
                float row = y + (i / 8) * (size + 26);
                GUI.Box(new Rect(x, row, size, size), "", Box(colors[i]));
                GUI.Label(new Rect(x, row + size + 2, size + 60, 20), names[i], _label);
            }
            return y + ((colors.Length + 7) / 8) * (size + 26) + 10;
        }

        float ButtonRow(float y, string name, Color background, Color foreground)
        {
            GUI.Label(new Rect(16, y + 8, 100, 22), name, _label);
            GUI.Box(new Rect(120, y, 200, 48), "", Box(background));
            var label = new GUIStyle(GUI.skin.label) { fontSize = 17, fontStyle = FontStyle.Bold, alignment = TextAnchor.MiddleCenter };
            GUI.contentColor = foreground;
            GUI.Label(new Rect(120, y, 200, 48), "بازی", label);
            GUI.contentColor = Color.white;

            GUI.Box(new Rect(336, y + 10, 200, 28), "", Box(background));
            GUI.Label(new Rect(336, y + 14, 200, 20), "pressed (sink 2dp)", _label);
            return y + 60;
        }

        void Pill(Rect rect, Color background, Color ring, string text)
        {
            GUI.Box(rect, "", Box(background));
            GUI.Box(new Rect(rect.x + 1, rect.y + 1, rect.width - 2, rect.height - 2), "", Box(ring));
            var style = new GUIStyle(GUI.skin.label) { alignment = TextAnchor.MiddleCenter, fontSize = 13, fontStyle = FontStyle.Bold };
            GUI.contentColor = Tokens.Bg;
            GUI.Label(rect, text, style);
            GUI.contentColor = Color.white;
        }

        void GoalChip(Rect rect, string item, int progress, int target, bool complete)
        {
            GUI.Box(rect, "", Box(Tokens.Text));
            var style = new GUIStyle(GUI.skin.label) { alignment = TextAnchor.MiddleCenter, fontSize = 13, fontStyle = FontStyle.Bold };
            GUI.contentColor = Tokens.Bg;
            GUI.Label(rect, item + "  " + progress + "/" + target + (complete ? "  ✓" : ""), style);
            GUI.contentColor = Color.white;
            if (complete) GUI.Box(new Rect(rect.x, rect.y, rect.width, 4), "", Box(Tokens.Gold));
        }

        void ProgressBar(Rect rect, float value)
        {
            GUI.Box(rect, "", Box(Tokens.SurfaceRaised));
            GUI.Box(new Rect(rect.x, rect.y, rect.width * Mathf.Clamp01(value), rect.height), "", Box(Tokens.Accent));
        }

        static Color Blend(Color a, Color b, float t) => Color.Lerp(a, b, t);
    }
}
