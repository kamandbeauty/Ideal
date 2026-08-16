using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.EnhancedTouch;
using Touch = UnityEngine.InputSystem.EnhancedTouch.Touch;

namespace RubyRun3D.Player
{
    public sealed class PlayerController : MonoBehaviour
    {
        [SerializeField] float forwardSpeed = 7f;
        [SerializeField] float horizontalSensitivity = .018f;
        [SerializeField] float horizontalSmoothTime = .08f;
        [SerializeField] float trackHalfWidth = 3.5f;
        float targetX;
        float horizontalVelocity;
        bool running;
        Vector2 previousPointer;

        public float ForwardSpeed { get => forwardSpeed; set => forwardSpeed = value; }
        public bool Running { get => running; set => running = value; }

        void OnEnable() => EnhancedTouchSupport.Enable();
        void OnDisable() => EnhancedTouchSupport.Disable();

        void Update()
        {
            if (!running) return;
            var delta = ReadPointerDelta();
            targetX = Mathf.Clamp(targetX + delta.x * horizontalSensitivity, -trackHalfWidth, trackHalfWidth);
            var position = transform.position;
            position.x = Mathf.SmoothDamp(position.x, targetX, ref horizontalVelocity, horizontalSmoothTime);
            position.z += forwardSpeed * Time.deltaTime;
            transform.position = position;
            var lean = Mathf.Clamp(horizontalVelocity * -1.4f, -12f, 12f);
            transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.Euler(0, 0, lean), Time.deltaTime * 9f);
        }

        static Vector2 ReadPointerDelta()
        {
            if (Touch.activeTouches.Count > 0)
            {
                var touch = Touch.activeTouches[0];
                return touch.phase is UnityEngine.InputSystem.TouchPhase.Moved ? touch.delta : Vector2.zero;
            }
            if (Mouse.current?.leftButton.isPressed == true) return Mouse.current.delta.ReadValue();
            return Vector2.zero;
        }
    }
}
