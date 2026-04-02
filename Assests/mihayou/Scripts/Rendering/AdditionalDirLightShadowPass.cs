using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// 自定义 RenderPass：为额外的 Directional Light 渲染 Shadow Map
/// 矩阵构建方式与 URP 官方 ShadowUtils 保持一致
/// </summary>
public class AdditionalDirLightShadowPass : ScriptableRenderPass
{
    private const string PROFILER_TAG = "AdditionalDirLightShadow";

    private Light _targetLight;
    private RenderTexture _shadowMap;
    private Matrix4x4 _lightViewMatrix;
    private Matrix4x4 _lightProjectionMatrix; // 原始正交投影（不经过 GL.GetGPUProjectionMatrix）
    private float _shadowBias;
    private float _shadowNormalBias;
    private float _shadowDistance;

    // Shader property IDs
    private static readonly int ID_ShadowMap = Shader.PropertyToID("_AdditionalDirShadowMap");
    private static readonly int ID_ShadowMatrix = Shader.PropertyToID("_AdditionalDirShadowMatrix");
    private static readonly int ID_LightDir = Shader.PropertyToID("_AdditionalDirLightDirection");
    private static readonly int ID_LightColor = Shader.PropertyToID("_AdditionalDirLightColor");
    private static readonly int ID_ShadowParams = Shader.PropertyToID("_AdditionalDirShadowParams");
    private static readonly int ID_Enabled = Shader.PropertyToID("_AdditionalDirShadowEnabled");

    public AdditionalDirLightShadowPass()
    {
        renderPassEvent = RenderPassEvent.BeforeRenderingShadows;
    }

    public void Setup(Light light, float shadowDistance, float shadowBias, float shadowNormalBias, int shadowMapSize)
    {
        _targetLight = light;
        _shadowDistance = shadowDistance;
        _shadowBias = shadowBias;
        _shadowNormalBias = shadowNormalBias;

        int size = Mathf.Max(256, shadowMapSize);
        if (_shadowMap == null || _shadowMap.width != size)
        {
            if (_shadowMap != null)
                _shadowMap.Release();

            _shadowMap = new RenderTexture(size, size, 24, RenderTextureFormat.Shadowmap);
            _shadowMap.name = "AdditionalDirShadowMap";
            _shadowMap.filterMode = FilterMode.Bilinear;
            _shadowMap.wrapMode = TextureWrapMode.Clamp;
            _shadowMap.Create();
        }
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (_targetLight == null || !_targetLight.isActiveAndEnabled || _targetLight.shadows == LightShadows.None || _shadowMap == null)
        {
            Shader.SetGlobalFloat(ID_Enabled, 0);
            return;
        }

        int shadowLightIndex = FindVisibleLightIndex(ref renderingData);
        if (shadowLightIndex < 0)
        {
            Shader.SetGlobalFloat(ID_Enabled, 0);
            return;
        }

        if (!renderingData.cullResults.GetShadowCasterBounds(shadowLightIndex, out Bounds _))
        {
            Shader.SetGlobalFloat(ID_Enabled, 0);
            return;
        }

        if (!renderingData.cullResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                shadowLightIndex,
                0,
                1,
                Vector3.zero,
                _shadowMap.width,
                _targetLight.shadowNearPlane,
                out _lightViewMatrix,
                out _lightProjectionMatrix,
                out ShadowSplitData splitData))
        {
            Shader.SetGlobalFloat(ID_Enabled, 0);
            return;
        }

        VisibleLight shadowLight = renderingData.lightData.visibleLights[shadowLightIndex];
        Vector4 shadowBias = ShadowUtils.GetShadowBias(ref shadowLight, shadowLightIndex, ref renderingData.shadowData, _lightProjectionMatrix, _shadowMap.width);

        var shadowSlice = new ShadowSliceData
        {
            viewMatrix = _lightViewMatrix,
            projectionMatrix = _lightProjectionMatrix,
            shadowTransform = GetShadowTransform(_lightProjectionMatrix, _lightViewMatrix),
            offsetX = 0,
            offsetY = 0,
            resolution = _shadowMap.width,
            splitData = splitData
        };

        var shadowSettings = new ShadowDrawingSettings(renderingData.cullResults, shadowLightIndex, BatchCullingProjectionType.Orthographic)
        {
            splitData = splitData,
            useRenderingLayerMaskTest = UniversalRenderPipeline.asset != null && UniversalRenderPipeline.asset.useRenderingLayers
        };

        CommandBuffer cmd = CommandBufferPool.Get(PROFILER_TAG);
        cmd.SetRenderTarget(_shadowMap);
        cmd.ClearRenderTarget(true, false, Color.clear);
        ShadowUtils.SetupShadowCasterConstantBuffer(cmd, ref shadowLight, shadowBias);
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        ShadowUtils.RenderShadowSlice(cmd, ref context, ref shadowSlice, ref shadowSettings, _lightProjectionMatrix, _lightViewMatrix);

        cmd.SetGlobalTexture(ID_ShadowMap, _shadowMap);
        cmd.SetGlobalMatrix(ID_ShadowMatrix, shadowSlice.shadowTransform);
        cmd.SetGlobalVector(ID_LightDir, (Vector4)(-_targetLight.transform.forward));
        cmd.SetGlobalVector(ID_LightColor, _targetLight.color * _targetLight.intensity);
        cmd.SetGlobalVector(ID_ShadowParams, new Vector4(_shadowBias, _shadowNormalBias, 1f / _shadowMap.width, 0));
        cmd.SetGlobalFloat(ID_Enabled, 1);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    private int FindVisibleLightIndex(ref RenderingData renderingData)
    {
        var visibleLights = renderingData.lightData.visibleLights;
        for (int i = 0; i < visibleLights.Length; i++)
        {
            if (visibleLights[i].light == _targetLight)
                return i;
        }

        return -1;
    }

    /// <summary>
    /// 构造世界空间 → 阴影贴图 UV 空间的矩阵
    /// 与 URP ShadowUtils.GetShadowTransform 完全一致
    /// 输入的 proj 是原始投影矩阵（不含 GPU 平台适配）
    /// </summary>
    private static Matrix4x4 GetShadowTransform(Matrix4x4 proj, Matrix4x4 view)
    {
        // Currently CullResults ComputeDirectionalShadowMatricesAndCullingPrimitives doesn't
        // apply z reversal to projection matrix. We need to do it manually here.
        if (SystemInfo.usesReversedZBuffer)
        {
            proj.m20 = -proj.m20;
            proj.m21 = -proj.m21;
            proj.m22 = -proj.m22;
            proj.m23 = -proj.m23;
        }

        Matrix4x4 worldToShadow = proj * view;

        // textureScaleAndBias maps texture space coordinates from [-1,1] to [0,1]
        var textureScaleAndBias = Matrix4x4.identity;
        textureScaleAndBias.m00 = 0.5f;
        textureScaleAndBias.m11 = 0.5f;
        textureScaleAndBias.m22 = 0.5f;
        textureScaleAndBias.m03 = 0.5f;
        textureScaleAndBias.m13 = 0.5f;
        textureScaleAndBias.m23 = 0.5f;

        return textureScaleAndBias * worldToShadow;
    }

    public void Cleanup()
    {
        if (_shadowMap != null)
        {
            _shadowMap.Release();
            _shadowMap = null;
        }
        Shader.SetGlobalFloat(ID_Enabled, 0);
    }
}
