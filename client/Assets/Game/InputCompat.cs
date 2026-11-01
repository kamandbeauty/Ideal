using UnityEngine;

#if ENABLE_INPUT_SYSTEM && !ENABLE_LEGACY_INPUT_MANAGER
using UnityEngine.InputSystem;
#endif

namespace Shazdeh.Game
{
    /// <summary>
    /// One place that reads the pointer, so the rest of the game does not care whether the project is
    /// set to the old Input Manager, the new Input System package, or both. Grey-box only: the real
    /// input map (drag to swap, tap to fire a booster) arrives with the UI in M1.
    /// </summary>
    public static class InputCompat
    {
        public static bool TryGetPointer(out Vector2 screenPosition, out bool isDown, out bool isUp)
        {
            screenPosition = Vector2.zero;
            isDown = false;
            isUp = false;

#if ENABLE_INPUT_SYSTEM && !ENABLE_LEGACY_INPUT_MANAGER
            var touch = Touchscreen.current;
            if (touch != null)
            {
                var primary = touch.primaryTouch;
                screenPosition = primary.position.ReadValue();
                isDown = primary.press.wasPressedThisFrame;
                isUp = primary.press.wasReleasedThisFrame;
                return isDown || isUp || primary.press.isPressed;
            }

            var mouse = Mouse.current;
            if (mouse != null)
            {
                screenPosition = mouse.position.ReadValue();
                isDown = mouse.leftButton.wasPressedThisFrame;
                isUp = mouse.leftButton.wasReleasedThisFrame;
                return isDown || isUp || mouse.leftButton.isPressed;
            }

            return false;
#else
            if (Input.touchCount > 0)
            {
                var touch = Input.GetTouch(0);
                screenPosition = touch.position;
                isDown = touch.phase == TouchPhase.Began;
                isUp = touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled;
                return true;
            }

            screenPosition = Input.mousePosition;
            isDown = Input.GetMouseButtonDown(0);
            isUp = Input.GetMouseButtonUp(0);
            return isDown || isUp || Input.GetMouseButton(0);
#endif
        }

        public static bool KeyPressedDown(int legacyKeyCode)
        {
#if ENABLE_INPUT_SYSTEM && !ENABLE_LEGACY_INPUT_MANAGER
            var keyboard = Keyboard.current;
            if (keyboard == null) return false;
            int digit = legacyKeyCode - (int)KeyCode.Alpha1;
            if (digit < 0 || digit > 8) return false;
            var key = keyboard[(Key)((int)Key.Digit1 + digit)];
            return key != null && key.wasPressedThisFrame;
#else
            return Input.GetKeyDown((KeyCode)legacyKeyCode);
#endif
        }
    }
}
