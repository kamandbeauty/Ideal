using System;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Shazdeh.Game.Ui
{
    /// <summary>
    /// The screen kit: every panel, label and button in the game is built by these five methods.
    ///
    /// Three rules, because a UI built in code goes wrong in three predictable ways:
    ///
    /// 1. Coordinates are dp from the top-left of the canvas, like a design tool. Anyone who has read
    ///    replica/design/components.md can check a number here against the spec without converting.
    /// 2. No magic colours or sizes: everything comes from Tokens.gen.cs.
    /// 3. Persian goes through RtlText, never straight into TMP — TMP does not shape Arabic script.
    ///
    /// Rounded corners come from a sprite generated at runtime (Radius tokens), which is why the
    /// screens look like screens and not like coloured boxes without shipping a single image.
    /// </summary>
    public static class UiKit
    {
        /// <summary>
        /// The design space: 1 unit = 1 dp, which is how replica/design/components.md is written (touch
        /// target 48, safe top 44, type 12–34). The 1080×1920 art reference is these points at ~2.6×,
        /// so a value in a spec and a value in a screen are the same number and a reviewer can compare
        /// them without arithmetic.
        /// </summary>
        public const float CanvasWidth = 415f;
        public const float CanvasHeight = 738f;

        static readonly Dictionary<int, Sprite> RoundedSprites = new Dictionary<int, Sprite>(4);

        // ---- canvas -------------------------------------------------------------------------------

        public static Canvas CreateCanvas(string name, Transform parent = null)
        {
            var go = new GameObject(name);
            if (parent != null) go.transform.SetParent(parent, false);

            var canvas = go.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 0;

            var scaler = go.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(CanvasWidth, CanvasHeight);
            scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
            scaler.matchWidthOrHeight = 0.5f;

            go.AddComponent<GraphicRaycaster>();
            EnsureEventSystem();
            return canvas;
        }

        /// <summary>
        /// Buttons need something to receive the click. The module depends on which input backend the
        /// project uses, and the two assemblies are mutually exclusive, so it is resolved by name
        /// instead of with an #if that would have to be kept in sync with the player settings.
        /// </summary>
        public static void EnsureEventSystem()
        {
            if (EventSystem.current != null) return;

            var existing = UnityEngine.Object.FindAnyObjectByType<EventSystem>();
            if (existing != null) return;

            var go = new GameObject("EventSystem");
            go.AddComponent<EventSystem>();

            var inputSystemModule = Type.GetType(
                "UnityEngine.InputSystem.UI.InputSystemUIInputModule, Unity.InputSystem");
            if (inputSystemModule != null) go.AddComponent(inputSystemModule);
            else go.AddComponent<StandaloneInputModule>();
        }

        // ---- building blocks ----------------------------------------------------------------------

        /// <summary>A coloured rectangle anchored by its top-left corner in canvas pixels.</summary>
        public static RectTransform Panel(Transform parent, string name, float x, float y, float width, float height, Color color, int radius = 0)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);

            var image = go.AddComponent<Image>();
            image.color = color;
            image.raycastTarget = false;

            if (radius > 0)
            {
                image.sprite = Rounded(radius);
                image.type = Image.Type.Sliced;
                image.pixelsPerUnitMultiplier = 1f;
            }

            return Place(go.GetComponent<RectTransform>(), x, y, width, height);
        }

        /// <summary>A hit-testable panel with a label: the only kind of button this game has.</summary>
        public static Button Button(Transform parent, string name, string label, float x, float y, float width, float height, Color face, Color labelColor, Action onClick, int radius = 0)
        {
            var rect = Panel(parent, name, x, y, width, height, face, radius);
            rect.GetComponent<Image>().raycastTarget = true;

            var button = rect.gameObject.AddComponent<Button>();
            button.targetGraphic = rect.GetComponent<Image>();
            var colors = button.colors;
            colors.normalColor = Color.white;
            colors.highlightedColor = new Color(1.08f, 1.08f, 1.08f, 1f);
            colors.pressedColor = new Color(0.86f, 0.86f, 0.86f, 1f);
            colors.disabledColor = new Color(0.55f, 0.55f, 0.55f, 0.6f);
            colors.fadeDuration = Tokens.Motion.Fast;
            button.colors = colors;

            var text = Label(rect, "label", label, Tokens.Hud.ButtonLabel, labelColor, TextAlignmentOptions.Center);
            Stretch(text.rectTransform, Tokens.Space.S3, Tokens.Space.S3);

            if (onClick != null) button.onClick.AddListener(() => onClick());
            return button;
        }

        public static TextMeshProUGUI Label(Transform parent, string name, string text, float size, Color color, TextAlignmentOptions alignment = TextAlignmentOptions.Center)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);

            var label = go.AddComponent<TextMeshProUGUI>();
            label.font = ShazdehFonts.Ui;
            label.fontSize = size;
            label.color = color;
            label.alignment = alignment;
            label.raycastTarget = false;
            label.overflowMode = TextOverflowModes.Truncate;
            label.richText = false;
            // TMP's own RTL flag reverses characters but does not shape them. PersianText does both, so
            // it must stay off or the string would be reversed twice.
            label.isRightToLeftText = false;

            RtlText.Set(label, text);
            Place(label.rectTransform, 0f, 0f, CanvasWidth, size * 1.5f);
            return label;
        }

        /// <summary>A right-aligned label, which in a Persian layout is the "reading" side.</summary>
        public static TextMeshProUGUI LabelRight(Transform parent, string name, string text, float size, Color color)
            => Label(parent, name, text, size, color, TextAlignmentOptions.Right);

        public static TextMeshProUGUI LabelLeft(Transform parent, string name, string text, float size, Color color)
            => Label(parent, name, text, size, color, TextAlignmentOptions.Left);

        // ---- geometry -----------------------------------------------------------------------------

        /// <summary>
        /// Anchors a rect to the top-left of its parent and gives it a size and a position in canvas
        /// pixels: <paramref name="y"/> grows downwards, which is how the design file reads.
        /// </summary>
        public static RectTransform Place(RectTransform rect, float x, float y, float width, float height)
        {
            rect.anchorMin = new Vector2(0f, 1f);
            rect.anchorMax = new Vector2(0f, 1f);
            rect.pivot = new Vector2(0f, 1f);
            rect.anchoredPosition = new Vector2(x, -y);
            rect.sizeDelta = new Vector2(width, height);
            return rect;
        }

        /// <summary>Fills the parent, inset by the same amount on both sides.</summary>
        public static RectTransform Stretch(RectTransform rect, float insetX, float insetY)
        {
            rect.anchorMin = Vector2.zero;
            rect.anchorMax = Vector2.one;
            rect.pivot = new Vector2(0.5f, 0.5f);
            rect.offsetMin = new Vector2(insetX, insetY);
            rect.offsetMax = new Vector2(-insetX, -insetY);
            return rect;
        }

        /// <summary>Full-bleed background: the first thing every screen adds.</summary>
        public static RectTransform Background(Transform parent, Color color)
        {
            var rect = Panel(parent, "background", 0f, 0f, CanvasWidth, CanvasHeight, color);
            rect.anchorMin = Vector2.zero;
            rect.anchorMax = Vector2.one;
            rect.pivot = new Vector2(0.5f, 0.5f);
            rect.offsetMin = Vector2.zero;
            rect.offsetMax = Vector2.zero;
            return rect;
        }

        /// <summary>A horizontal accent rule: the cheapest ornament that still looks deliberate.</summary>
        public static RectTransform Rule(Transform parent, float x, float y, float width, Color color, float thickness = 2f)
            => Panel(parent, "rule", x, y, width, thickness, color);

        // ---- rounded corners without art ----------------------------------------------------------

        /// <summary>
        /// A 9-sliced rounded rectangle, generated once per radius and cached. Drawn with a signed
        /// distance test on a small texture, so a 28-pixel panel radius stays smooth at any scale.
        /// </summary>
        public static Sprite Rounded(int radius)
        {
            if (RoundedSprites.TryGetValue(radius, out var cached)) return cached;

            int size = Mathf.Clamp(radius * 2 + 2, 8, 128);
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, false)
            {
                filterMode = FilterMode.Bilinear,
                wrapMode = TextureWrapMode.Clamp,
                name = "rounded_" + radius
            };

            float r = Mathf.Min(radius, size * 0.5f);
            var pixels = new Color32[size * size];
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float dx = Mathf.Max(r - (x + 0.5f), (x + 0.5f) - (size - r));
                    float dy = Mathf.Max(r - (y + 0.5f), (y + 0.5f) - (size - r));
                    dx = Mathf.Max(dx, 0f);
                    dy = Mathf.Max(dy, 0f);
                    float distance = Mathf.Sqrt(dx * dx + dy * dy);
                    float alpha = Mathf.Clamp01(r - distance + 0.5f);
                    pixels[y * size + x] = new Color32(255, 255, 255, (byte)(alpha * 255f));
                }
            }
            texture.SetPixels32(pixels);
            texture.Apply();

            var border = new Vector4(r, r, r, r);
            var sprite = Sprite.Create(texture, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), 100f, 0, SpriteMeshType.FullRect, border);
            sprite.name = "rounded_" + radius;
            RoundedSprites[radius] = sprite;
            return sprite;
        }
    }
}
