using System;
using UnityEngine;

namespace RubyRun3D.Player
{
    [RequireComponent(typeof(Camera))]
    public sealed class ThirdPersonCamera : MonoBehaviour
    {
        public Transform target;
        public Vector3 offset = new(0, 8.2f, -10.5f);
        public float positionDamping = 8f;
        public float lookDamping = 10f;
        Vector3 shake;
        float shakeTime;

        public void ConfigureCinemachineIfPresent()
        {
            // Cinemachine 3 is installed. Reflection keeps this runtime resilient across patch API changes.
            var brainType = Type.GetType("Unity.Cinemachine.CinemachineBrain, Unity.Cinemachine");
            if (brainType != null && GetComponent(brainType) == null) gameObject.AddComponent(brainType);
        }

        public void Shake(float strength = .2f, float duration = .18f)
        {
            shake = UnityEngine.Random.insideUnitSphere * strength;
            shakeTime = duration;
        }

        void LateUpdate()
        {
            if (!target) return;
            var desired = target.position + offset;
            if (shakeTime > 0) { shakeTime -= Time.deltaTime; desired += shake * (shakeTime * 5f); }
            transform.position = Vector3.Lerp(transform.position, desired, 1f - Mathf.Exp(-positionDamping * Time.deltaTime));
            var look = Quaternion.LookRotation(target.position + Vector3.up * 1.1f - transform.position);
            transform.rotation = Quaternion.Slerp(transform.rotation, look, 1f - Mathf.Exp(-lookDamping * Time.deltaTime));
        }
    }
}
