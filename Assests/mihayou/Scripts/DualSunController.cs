using UnityEngine;

[ExecuteInEditMode]
public class DualSunController : MonoBehaviour
{
    [Header("Directional Lights")]
    public Light sunA;
    public Light sunB;

    [Header("Skybox Material")]
    public Material skyboxMaterial;

    private static readonly int SunADirectionID = Shader.PropertyToID("_SunADirection");
    private static readonly int SunBDirectionID = Shader.PropertyToID("_SunBDirection");

    void Update()
    {
        if (skyboxMaterial == null)
            return;

        if (sunA != null)
        {
            // Directional Light 的 forward 指向光照方向，太阳在天空中的位置是反方向
            Vector3 dirA = -sunA.transform.forward;
            skyboxMaterial.SetVector(SunADirectionID, new Vector4(dirA.x, dirA.y, dirA.z, 0));
        }

        if (sunB != null)
        {
            Vector3 dirB = -sunB.transform.forward;
            skyboxMaterial.SetVector(SunBDirectionID, new Vector4(dirB.x, dirB.y, dirB.z, 0));
        }
    }
}
