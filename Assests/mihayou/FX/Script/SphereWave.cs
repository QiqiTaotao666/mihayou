
using UnityEngine;
using UnityEngine.Serialization;

namespace MirzaBeig.PortalVFX
{
    [ExecuteAlways]
    public class SphereWave : MonoBehaviour
    {
        public SphereWaveManager manager;

        public float radiusScale = 1.0f;

        //[ColorUsage(true, true)]
        //public Color colour = Color.red;

        [Space]

        public float scale = 1.0f;

        //public float phase = 0.0f;
        public float speed = 1.0f;

        [Space]

        //[Range(0.0f, 1.0f)] public float strength = 1.0f;
        [Range(0.0f, 1.0f)] public float mask = 0.0f;

        void Awake()
        {
            if (manager == null)
            {
                manager = FindObjectOfType<SphereWaveManager>();
            }
        }

        void Start()
        {

        }

        void OnEnable()
        {
            manager.Add(this);
        }
        void OnDisable()
        {
            manager.Remove(this);
        }

        void LateUpdate()
        {

        }

        void OnDrawGizmos()
        {
            //Gizmos.color = colour;
            Gizmos.DrawWireSphere(transform.position, transform.lossyScale.x * radiusScale);
        }
    }
}