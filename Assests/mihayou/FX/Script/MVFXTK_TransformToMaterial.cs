using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace MirzaVFXToolkit
{
    [ExecuteAlways]
    public class MVFXTK_TransformToMaterial : MonoBehaviour
    {
        public Material material;

        [Space]

        public string positionPropertyName = "_Position";
        public string rotationPropertyName = "_Rotation";
        public string scalePropertyName = "_Scale";

        [Space]

        public float scale = 1.0f;

        [Space]

        public bool autoMaterial;

        [Space]

        public bool debugRender;

        void Start()
        {

        }

        void Update()
        {
            if (autoMaterial)
            {
                Renderer renderer = GetComponent<Renderer>();

                if (Application.isPlaying)
                {
                    if (material == renderer.sharedMaterial)
                    {
                        material = renderer.material;
                    }
                }
                else
                {
                    material = renderer.sharedMaterial;
                }
            }

            material.SetVector(positionPropertyName, transform.position);
            material.SetVector(rotationPropertyName, transform.eulerAngles);
            material.SetVector(scalePropertyName, transform.lossyScale * scale);

            //material.SetMatrix(rotationPropertyName, Matrix4x4.Rotate(transform.rotation));   
        }

        // No radius if disabled.

        //void OnDisable()
        //{
        //    material.SetVector(scalePropertyName, Vector3.zero);
        //}

        void OnDrawGizmos()
        {
            if (!debugRender)
            {
                return;
            }

            Gizmos.color = Color.yellow;

            Gizmos.matrix = Matrix4x4.TRS(transform.position, transform.rotation, transform.lossyScale * scale);
            Gizmos.DrawWireSphere(Vector3.zero, 1.0f);
        }
    }
}