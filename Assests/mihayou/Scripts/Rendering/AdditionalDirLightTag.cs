using UnityEngine;

/// <summary>
/// 挂在第二盏 Directional Light 上，标记它为额外阴影光源。
/// Feature 会自动找到此组件。
/// </summary>
[ExecuteAlways]
[RequireComponent(typeof(Light))]
public class AdditionalDirLightTag : MonoBehaviour
{
    public static AdditionalDirLightTag Instance { get; private set; }

    [HideInInspector]
    public Light targetLight;

    void Awake()
    {
        Instance = this;
        targetLight = GetComponent<Light>();
    }

    void OnEnable()
    {
        Instance = this;
        if (targetLight == null)
            targetLight = GetComponent<Light>();
    }

    void OnDisable()
    {
        if (Instance == this)
            Instance = null;
    }

    void OnDestroy()
    {
        if (Instance == this)
            Instance = null;
    }
}
