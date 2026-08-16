using UnityEngine;

namespace RubyRun3D.Core
{
    public sealed class BobAnimator : MonoBehaviour
    {
        public float amplitude = .06f;
        public float frequency = 9f;
        public float sway = 3f;
        Vector3 origin;
        Quaternion rotation;
        float offset;
        void Awake() { origin = transform.localPosition; rotation = transform.localRotation; offset = Random.value * 6f; }
        void Update()
        {
            var phase = Time.time * frequency + offset;
            transform.localPosition = origin + Vector3.up * (Mathf.Abs(Mathf.Sin(phase)) * amplitude);
            transform.localRotation = rotation * Quaternion.Euler(0, 0, Mathf.Sin(phase * .5f) * sway);
        }
    }
}
