Shader "My/Distortion"
{
    Properties
    {
        [Header(Distortion)]
        _DistortionTex ("Distortion Texture", 2D) = "bump" {}
        _DistortionStrength ("Strength", Range(0, 0.2)) = 0.02
        _SpeedX ("Speed X", Float) = 0.0
        _SpeedY ("Speed Y", Float) = 0.5
        _TilingX ("Tiling X", Float) = 1.0
        _TilingY ("Tiling Y", Float) = 1.0

        [Header(Mask)]
        [Toggle] _UseMask ("Use Mask", Float) = 0
        _MaskTex ("Mask Texture", 2D) = "white" {}

        [Header(Tint)]
        [Toggle] _UseTint ("Use Tint", Float) = 0
        [HDR] _TintColor ("Tint Color", Color) = (1,1,1,0)
        _TintStrength ("Tint Strength", Range(0, 1)) = 0

        [Header(Wave)]
        _WaveCount ("Wave Count", Range(0, 32)) = 0
        [HDR] _WaveColour ("Wave Colour", Color) = (1,1,1,1)
        _WavePower ("Wave Power", Float) = 1
        _WaveVertexOffset ("Wave Vertex Offset", Float) = 0
        _WaveNormalStrength ("Wave Normal Strength", Float) = 0

        [Header(Stencil)]
        _StencilRef ("Stencil Ref", Range(0, 255)) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("Stencil Comp", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass ("Stencil Pass", Float) = 0

        [Header(Depth Fade)]
        _DepthFade ("Depth Fade Distance", Range(0.01, 5.0)) = 0.5

        [Header(Rendering)]
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }

        Stencil
        {
            Ref [_StencilRef]
            Comp [_StencilComp]
            Pass [_StencilPass]
        }

        Pass
        {
            Name "Distortion"
            Tags { "LightMode" = "UniversalForward" }

            ZWrite Off
            ZTest LEqual
            Cull [_Cull]
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5
            #pragma shader_feature_local _USEMASK_ON
            #pragma shader_feature_local _USETINT_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            // ────────────── Wave Data ──────────────
            struct WaveData
            {
                float3 position;
                float radius;
                float scale;
                float phase;
                float mask;
            };

            StructuredBuffer<WaveData> waveDataBuffer;

            void Waves(float3 worldPosition, uint count, out float output)
            {
                float total = 0.0;

                for (uint i = 0; i < count; i++)
                {
                    WaveData wave = waveDataBuffer[i];

                    float3 pos = worldPosition - wave.position;

                    float sdf = length(pos) / wave.radius;
                    float waveMask = 1.0 - saturate(sdf + wave.mask);

                    sdf *= wave.scale;
                    sdf -= wave.phase;

                    float waveSdf = sin(sdf * 3.14159);
                    waveSdf = pow(abs(waveSdf), 2.0);

                    float maskedWaveSdf = waveSdf * waveMask;
                    total = max(total, maskedWaveSdf);
                }

                output = total;
            }

            // Mikkelsen bump-from-height (screen-space ddx/ddy)
            float3 PerturbNormal(float3 surfPos, float3 surfNorm, float height, float scale)
            {
                float3 vSigmaS = ddx(surfPos);
                float3 vSigmaT = ddy(surfPos);
                float3 vN = surfNorm;
                float3 vR1 = cross(vSigmaT, vN);
                float3 vR2 = cross(vN, vSigmaS);
                float fDet = dot(vSigmaS, vR1);
                float dBs = ddx(height);
                float dBt = ddy(height);
                float3 vSurfGrad = scale * 0.05 * sign(fDet) * (dBs * vR1 + dBt * vR2);
                return normalize(abs(fDet) * vN - vSurfGrad);
            }
            // ────────────────────────────────────────

            TEXTURE2D(_DistortionTex);
            SAMPLER(sampler_DistortionTex);

            TEXTURE2D(_MaskTex);
            SAMPLER(sampler_MaskTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _DistortionTex_ST;
                float4 _MaskTex_ST;
                half _DistortionStrength;
                half _SpeedX;
                half _SpeedY;
                half _TilingX;
                half _TilingY;
                half _UseMask;
                half4 _TintColor;
                half _TintStrength;
                half _UseTint;
                half _DepthFade;
                // Wave
                float _WaveCount;
                float _WavePower;
                float _WaveVertexOffset;
                float _WaveNormalStrength;
                float4 _WaveColour;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv : TEXCOORD0;
                half4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float4 screenPos   : TEXCOORD1;
                half4  color       : COLOR;
                float3 worldPos    : TEXCOORD2;
                float3 worldNormal : TEXCOORD3;
            };

            Varyings vert(Attributes input)
            {
                Varyings o;

                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(input.normalOS);

                // ── Wave vertex offset ──
                uint waveCount = (uint)_WaveCount;
                float waveOutput = 0.0;
                if (waveCount > 0)
                {
                    Waves(worldPos, waveCount, waveOutput);
                    waveOutput = pow(waveOutput, _WavePower);
                    float3 vertexOffset = waveOutput * _WaveVertexOffset * input.normalOS;
                    input.positionOS.xyz += vertexOffset;
                    worldPos = TransformObjectToWorld(input.positionOS.xyz);
                }

                o.positionCS  = TransformObjectToHClip(input.positionOS.xyz);
                o.uv          = input.uv;
                o.screenPos   = ComputeScreenPos(o.positionCS);
                o.color       = input.color;
                o.worldPos    = worldPos;
                o.worldNormal = worldNormal;

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 screenUV = i.screenPos.xy / i.screenPos.w;

                // ── Wave 计算（片元级）──
                uint waveCount = (uint)_WaveCount;
                float wavesValue = 0.0;
                float3 waveNormalOffset = float3(0, 0, 0);
                if (waveCount > 0)
                {
                    float waveRaw = 0.0;
                    Waves(i.worldPos, waveCount, waveRaw);
                    wavesValue = pow(waveRaw, _WavePower);

                    // 法线扰动 → 转为屏幕空间偏移用于折射
                    float3 perturbedNormal = PerturbNormal(
                        i.worldPos, normalize(i.worldNormal), wavesValue, _WaveNormalStrength);
                    waveNormalOffset = perturbedNormal - normalize(i.worldNormal);
                }

                // 场景深度 vs 面片自身深度
                float sceneDepthRaw = SampleSceneDepth(screenUV);
                float sceneDepthLinear = LinearEyeDepth(sceneDepthRaw, _ZBufferParams);
                float selfDepthLinear = LinearEyeDepth(i.screenPos.z / i.screenPos.w, _ZBufferParams);

                float depthDiff = sceneDepthLinear - selfDepthLinear;
                float depthFade = saturate(depthDiff / _DepthFade);

                // 计算扰动 UV（Tiling + 滚动动画）
                float2 distortUV = i.uv * float2(_TilingX, _TilingY)
                                 + _Time.y * float2(_SpeedX, _SpeedY);

                // 采样扰动贴图
                half2 distort = SAMPLE_TEXTURE2D(_DistortionTex, sampler_DistortionTex, distortUV).rg;
                distort = (distort - 0.5) * 2.0 * _DistortionStrength;

                // Mask 遮罩（可选）
                #if defined(_USEMASK_ON)
                    half mask = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, i.uv).r;
                    distort *= mask;
                #endif

                // 顶点色 Alpha 控制扰动强度
                distort *= i.color.a;

                // 用深度因子衰减扰动强度
                distort *= depthFade;

                // ── Wave 法线扰动叠加到屏幕 UV ──
                float2 waveDistort = waveNormalOffset.xy;
                distort += waveDistort;

                // 扰动后的屏幕 UV
                float2 distortedUV = screenUV + distort;

                // 对扰动后的 UV 也做深度软过渡，防止采样到前方物体
                float distortedDepthRaw = SampleSceneDepth(distortedUV);
                float distortedDepthLinear = LinearEyeDepth(distortedDepthRaw, _ZBufferParams);
                float distortedDepthDiff = distortedDepthLinear - selfDepthLinear;
                float distortedFade = saturate(distortedDepthDiff / _DepthFade);

                // 在扰动 UV 和原始 UV 之间做软混合
                distortedUV = lerp(screenUV, distortedUV, distortedFade);

                // 采样场景颜色
                half3 sceneColor = SampleSceneColor(distortedUV);

                // 叠加染色（可选）
                #if defined(_USETINT_ON)
                    sceneColor = lerp(sceneColor, sceneColor * _TintColor.rgb, _TintStrength);
                #endif

                // ── Wave 颜色混合 ──
                sceneColor = lerp(sceneColor, _WaveColour.rgb, _WaveColour.a * wavesValue);

                return half4(sceneColor, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
