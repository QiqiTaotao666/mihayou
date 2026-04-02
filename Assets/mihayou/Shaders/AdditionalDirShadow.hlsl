#ifndef ADDITIONAL_DIR_SHADOW_INCLUDED
#define ADDITIONAL_DIR_SHADOW_INCLUDED

// 由 AdditionalDirLightShadowPass 设置的全局变量
TEXTURE2D_SHADOW(_AdditionalDirShadowMap);
SAMPLER_CMP(sampler_AdditionalDirShadowMap);

float4x4 _AdditionalDirShadowMatrix;
float4 _AdditionalDirLightDirection; // xyz = light dir (world)
float4 _AdditionalDirLightColor;     // rgb * intensity
float4 _AdditionalDirShadowParams;   // x=bias, y=normalBias, z=texelSize
float _AdditionalDirShadowEnabled;

half SampleAdditionalDirShadow(float3 positionWS)
{
    // 世界坐标 → 阴影贴图 UV
    float4 shadowCoord = mul(_AdditionalDirShadowMatrix, float4(positionWS, 1.0));
    shadowCoord.xyz /= shadowCoord.w;

    // 范围外不遮挡
    float2 uv = shadowCoord.xy;
    if (uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1 || shadowCoord.z < 0 || shadowCoord.z > 1)
        return 1.0;

    // PCF 3x3 软阴影
    float texelSize = _AdditionalDirShadowParams.z;
    if (texelSize <= 0) texelSize = 1.0 / 2048.0;

    float shadow = 0;
    [unroll]
    for (int x = -1; x <= 1; x++)
    {
        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            float2 offset = float2(x, y) * texelSize;
            shadow += SAMPLE_TEXTURE2D_SHADOW(
                _AdditionalDirShadowMap,
                sampler_AdditionalDirShadowMap,
                float3(uv + offset, shadowCoord.z));
        }
    }
    shadow /= 9.0;

    return shadow;
}

Light GetAdditionalDirLight(float3 positionWS)
{
    Light light;
    light.direction = normalize(_AdditionalDirLightDirection.xyz);
    light.color = _AdditionalDirLightColor.rgb;
    light.distanceAttenuation = 1.0;
    light.shadowAttenuation = SampleAdditionalDirShadow(positionWS);
    light.layerMask = 0xFFFFFFFF;
    return light;
}

half3 CalculateAdditionalDirLightPBR(InputData inputData, SurfaceData surfaceData)
{
    if (_AdditionalDirShadowEnabled < 0.5)
        return half3(0, 0, 0);

    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);

#if defined(_SPECULARHIGHLIGHTS_OFF)
    const bool specularHighlightsOff = true;
#else
    const bool specularHighlightsOff = false;
#endif

    Light light = GetAdditionalDirLight(inputData.positionWS);

    // GI: 与 UniversalFragmentPBR 保持一致
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    half3 bakedGI = inputData.bakedGI;
    MixRealtimeAndBakedGI(light, inputData.normalWS, bakedGI);

    half3 giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                       bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                       inputData.normalWS, inputData.viewDirectionWS);

    // 直接光照
    half3 directColor = LightingPhysicallyBased(
        brdfData,
        brdfDataClearCoat,
        light,
        inputData.normalWS,
        inputData.viewDirectionWS,
        surfaceData.clearCoatMask,
        specularHighlightsOff);

    return giColor + directColor;
}


#endif
