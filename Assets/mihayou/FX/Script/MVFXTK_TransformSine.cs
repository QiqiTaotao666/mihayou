using UnityEngine;

using Unity.Mathematics;

namespace MirzaVFXToolKit
{
    // Animates a GameObject's position, rotation, and scale (transform) using sine waves.

    public class MVFXTK_TransformSine : MonoBehaviour
    {
        public Space space;

        //[Range(1, 120)]
        //public uint fps = 120;

        [Header("Position")]

        public float positionAmplitude = 0.0f;
        public float3 positionAmplitudeTiling = Vector3.up;

        [Space]

        public float positionFrequency = 1.0f;
        public float3 positionFrequencyTiling = Vector3.one;

        [Space]

        public float positionPower = 1.0f;

        [Header("Rotation")]

        public float rotationAmplitude = 0.0f;
        public float3 rotationAmplitudeTiling = Vector3.up;

        [Space]

        public float rotationFrequency = 1.0f;
        public float3 rotationFrequencyTiling = Vector3.one;

        [Space]

        public float rotationPower = 1.0f;

        [Header("Scale")]

        public float scaleAmplitude = 0.0f;
        public float3 scaleAmplitudeTiling = Vector3.one;

        [Space]

        public float scaleFrequency = 1.0f;
        public float3 scaleFrequencyTiling = Vector3.one;

        [Space]

        public float scalePower = 1.0f;

        // ...

        float3 startPosition;
        Quaternion startRotation;

        float3 startScale;

        void Start()
        {
            startPosition = transform.localPosition;
            startRotation = transform.localRotation;

            startScale = transform.localScale;
        }

        void Update()
        {
            // Time and FPS.

            float time = Time.time;

            //time = Mathf.Floor(Time.time * fps) / fps;

            const float TAU = math.PI * 2.0f;
            float tauTime = time * TAU;

            // Position.

            float scaledTimeForPosition = tauTime * positionFrequency;

            float3 positionSine = math.sin(scaledTimeForPosition * positionFrequencyTiling);

            float3 positionSineAbs = math.abs(positionSine);
            float3 positionSineSign = math.sign(positionSine);

            positionSineAbs = math.pow(positionSineAbs, positionPower);

            positionSine = positionSineSign * positionSineAbs;

            float3 newPosition = startPosition + ((positionAmplitude * positionAmplitudeTiling) * positionSine);

            float scaledTimeForRotation = tauTime * rotationFrequency;

            // Rotation.

            float3 rotationSine = math.sin(scaledTimeForRotation * rotationFrequencyTiling);

            float3 rotationSineAbs = math.abs(rotationSine);
            float3 rotationSineSign = math.sign(rotationSine);

            rotationSineAbs = math.pow(rotationSineAbs, rotationPower);

            rotationSine = rotationSineSign * rotationSineAbs;

            float3 newRotation = (rotationAmplitude * rotationAmplitudeTiling) * rotationSine;

            // Apply position and rotation.

            if (space == Space.World)
            {
                transform.SetPositionAndRotation(newPosition, startRotation * Quaternion.Euler(newRotation));
            }
            else
            {
                transform.SetLocalPositionAndRotation(newPosition, startRotation * Quaternion.Euler(newRotation));
            }

            // Scale.

            float scaledTimeForScale = tauTime * scaleFrequency;

            float3 scaleSine = math.sin(scaledTimeForScale * scaleFrequencyTiling);

            float3 scaleSineAbs = math.abs(scaleSine);
            float3 scaleSineSign = math.sign(scaleSine);

            scaleSineAbs = math.pow(scaleSineAbs, scalePower);

            scaleSine = scaleSineSign * scaleSineAbs;

            float3 newScale = startScale + ((scaleAmplitude * scaleAmplitudeTiling) * scaleSine);

            transform.localScale = newScale;
        }
    }
}
