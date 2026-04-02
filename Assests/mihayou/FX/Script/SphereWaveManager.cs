using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace MirzaBeig.PortalVFX
{
    [ExecuteAlways]
    public class SphereWaveManager : MonoBehaviour
    {
        // Make sure this matches shader.

        const int MAX_COUNT = 32;

        public List<SphereWave> waves;
        public Material[] materials;

        public struct Data
        {
            public Vector3 position;

            public float radius;
            public float scale;

            public float phase;
            public float mask;
        };

        int dataSize;
        Data[] data;

        ComputeBuffer dataBuffer;

        public string waveCountPropertyName = "_WaveCount";

        void Start()
        {
            //DeInitializeDataBuffer();
            dataSize = System.Runtime.InteropServices.Marshal.SizeOf(typeof(Data));
        }

        void OnDisable()
        {
            DeInitializeDataBuffer();
        }

        void InitializeDataBuffer()
        {
            dataBuffer = new ComputeBuffer(data.Length, dataSize);
        }
        void DeInitializeDataBuffer()
        {
            if (dataBuffer != null)
            {
                dataBuffer.Release();
                dataBuffer.Dispose();

                dataBuffer = null;
            }
        }    

        void LateUpdate()
        {
            // Setup compute buffer.

            if (data == null || data.Length != MAX_COUNT)
            {
                data = new Data[MAX_COUNT];
            }

            if (dataBuffer == null)
            {
                InitializeDataBuffer();
            }
            else
            {
                if (!dataBuffer.IsValid() || dataBuffer.count != MAX_COUNT)
                {
                    dataBuffer.Release();
                    dataBuffer.Dispose();

                    InitializeDataBuffer();
                }
            }

            for (int i = 0; i < waves.Count; i++)
            {
                SphereWave wave = waves[i];

                data[i] = new Data
                {
                    position = wave.transform.position,
                    radius = wave.transform.lossyScale.x * wave.radiusScale,

                    scale = wave.scale,
                    phase = wave.speed * Time.time,

                    //phase = wave.phase + (wave.speed * Time.time),

                    mask = wave.mask,
                };
            }

            // Update materials.

            for (int i = 0; i < materials.Length; i++)
            {
                Material material = materials[i];

                material.SetInt(waveCountPropertyName, waves.Count);

                dataBuffer.SetData(data);
                material.SetBuffer("waveDataBuffer", dataBuffer);
            }
        }

        public bool Add(SphereWave scan)
        {
            if (waves.Contains(scan))
            {
                return false;
            }

            waves.Add(scan);

            return true;
        }
        public bool Remove(SphereWave scan)
        {
            if (!waves.Contains(scan))
            {
                return false;
            }

            waves.Remove(scan);

            return true;
        }

        void OnDrawGizmos()
        {
            for (int i = 0; i < waves.Count; i++)
            {
                SphereWave scan = waves[i];

                //Gizmos.color = scan.colour;
                Gizmos.DrawWireSphere(scan.transform.position, scan.transform.lossyScale.x);
            }
        }
    }
}