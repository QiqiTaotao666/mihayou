using UnityEngine;
using UnityEngine.Rendering.Universal;

/// <summary>
/// RendererFeature：额外方向光阴影
/// 
/// 使用方法：
/// 1. 在 Forward Renderer Data 中添加此 Feature
/// 2. 在第二盏 Directional Light 上挂 AdditionalDirLightTag 组件
/// 3. 调整阴影参数
/// </summary>
[System.Serializable]
public class AdditionalDirLightShadowFeature : ScriptableRendererFeature
{
    [Header("阴影参数")]
    [Tooltip("阴影贴图分辨率")]
    public int shadowMapResolution = 2048;

    [Tooltip("阴影距离")]
    public float shadowDistance = 50f;

    [Tooltip("深度偏移")]
    [Range(0f, 10f)]
    public float shadowBias = 1.5f;

    [Tooltip("法线偏移")]
    [Range(0f, 10f)]
    public float shadowNormalBias = 1f;

    private AdditionalDirLightShadowPass _shadowPass;

    public override void Create()
    {
        _shadowPass = new AdditionalDirLightShadowPass();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // 运行时从场景中查找带 Tag 的灯光
        var tag = AdditionalDirLightTag.Instance;
        if (tag == null || tag.targetLight == null)
            return;

        Light light = tag.targetLight;

        if (!light.isActiveAndEnabled || light.type != LightType.Directional || light.shadows == LightShadows.None)
            return;

        _shadowPass.Setup(light, shadowDistance, shadowBias, shadowNormalBias, shadowMapResolution);
        renderer.EnqueuePass(_shadowPass);
    }

    protected override void Dispose(bool disposing)
    {
        _shadowPass?.Cleanup();
    }
}
