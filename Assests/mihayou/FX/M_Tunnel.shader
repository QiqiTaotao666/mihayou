Shader "Stargate - Portal/Space Tunnel"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc("BlendMode Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst("BlendMode Dst", Float) = 10

        [HDR]_ColorA ("Cloud Color A", Color) = (1,1,1,1)
        [HDR]_ColorB ("Cloud Color B", Color) = (1,1,1,1)
        [HDR]_EmissionColor ("Emission Color", Color) = (1,1,1,1)
        _SkyTex ("Texture", Cube) = "white" {}
        _MainTex ("Texture", 2D) = "white" {}
        _FlowTex ("Flow Displace", 2D) = "white" {}
        [Header(ScrollSpeed1 XY l ScrollSpeed2 XY)]
        _Settings("", Vector) = (1,1,1,1)
        [Header(Fresnel Mult Pow l Flow Speed l Influence)]
        _Settings3("", Vector) = (1,1,1,1)
        [Header(UV Distort XY l Flow Distort XY)]
        _Settings4("", Vector) = (1,1,1,1)
        [Header(Distort Opacity l  Emission Opacity l EMPTY l Global Opacity)]
        _Settings5("", Vector) = (1,1,1,1)
        [Header(Emission Mult Pow l Dissolve Progress l Dissolve Softness)]
        _Settings6("", Vector) = (1,1,1,1)
        [Header(Event Horizon Mult Pow l EMPTY l EMPTY)]
        _Settings8("", Vector) = (1,1,1,1)
        [Header(Phase Stabilization Pattern Pow Mult l Progress l Alpha)]
        _PhaseStabilization("", Vector) = (1,1,1,1)
        // Stencil
        _StencilRef("Stencil Ref", Range(0, 255)) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilFail("Stencil Fail", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilZFail("Stencil ZFail", Float) = 0
        _StencilReadMask("Stencil Read Mask", Range(0, 255)) = 255
        _StencilWriteMask("Stencil Write Mask", Range(0, 255)) = 255
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        Blend [_BlendSrc] [_BlendDst]
        ZWrite Off
        Cull Back
        LOD 100

        Stencil
        {
            Ref [_StencilRef]
            Comp [_StencilComp]
            Pass [_StencilPass]
            Fail [_StencilFail]
            ZFail [_StencilZFail]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Pass
        {
            Name "SpaceTunnel"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "StargateCG.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _FlowTex_ST;
                float4 _Settings;
                float4 _Settings3;
                float4 _Settings4;
                float4 _Settings5;
                float4 _Settings6;
                float4 _Settings7;
                float4 _Settings8;
                float4 _PhaseStabilization;
                float4 _ColorA;
                float4 _ColorB;
                float4 _EmissionColor;
            CBUFFER_END

            TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);
            TEXTURE2D(_FlowTex);        SAMPLER(sampler_FlowTex);
            TEXTURECUBE(_SkyTex);        SAMPLER(sampler_SkyTex);

            // URP 不透明纹理（替代 GrabPass）
            TEXTURE2D(_CameraOpaqueTexture);    SAMPLER(sampler_CameraOpaqueTexture);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 uv : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 uv2 : TEXCOORD2;
                float4 positionCS : SV_POSITION;
                float4 color : COLOR;
                float3 worldNormal : TEXCOORD3;
                float3 viewDir : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
                half3 worldRefl : TEXCOORD6;
            };

            float3 RotateAroundYInDegrees(float3 vertex, float degrees)
            {
                float alpha = degrees * PI / 180.0;
                float sina, cosa;
                sincos(alpha / 2, sina, cosa);
                float3x3 m = float3x3(
                    cosa,  -sina, 0,
                    sina,   cosa, 0,
                    0,      0,    1);
                return mul(m, vertex.xyz);
            }

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                float dissolveMask2 = saturate(((v.uv.y) - _Settings6.z - 0.1) / _Settings6.w);
                v.positionOS.xz *= lerp(dissolveMask2, 1, v.color.b);

                VertexPositionInputs posInputs = GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs normInputs = GetVertexNormalInputs(v.normalOS);

                o.positionCS = posInputs.positionCS;
                o.uv.xy = v.uv.xy * _MainTex_ST.xy;
                o.uv.zw = v.uv.xy * _MainTex_ST.zw;

                o.uv1.xy = v.uv.xy * _FlowTex_ST.xy;
                o.uv1.zw = v.uv.xy * _FlowTex_ST.zw;

                o.uv2.xy = v.uv.xy;

                o.worldNormal = normInputs.normalWS;
                o.viewDir = GetWorldSpaceNormalizeViewDir(posInputs.positionWS);
                o.color = v.color;
                o.screenPos = ComputeScreenPos(o.positionCS);

                // sky reflection
                float3 worldViewDir = normalize(GetWorldSpaceViewDir(posInputs.positionWS));
                o.worldRefl = RotateAroundYInDegrees(-worldViewDir + o.worldNormal * v.uv.y, _Time.x * 1500);

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 sinPattern = 1 - abs(sin(float2(i.uv2.x - _Time.y * 0.5, i.uv2.y + i.uv2.y * 0.33) * 15 + _PhaseStabilization.z));
                float ripple = max(0, (pow((sinPattern.x + sinPattern.y) * sin(saturate(i.uv2.y * 1 + _PhaseStabilization.z) * PI) * _PhaseStabilization.x, _PhaseStabilization.y)));

                half4 flowTex = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex, i.uv1.xy + _Time.x * _Settings3.z * float2(-1, 1) + ripple * 3);

                half4 mainTex  = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy + flowTex.xy * _Settings3.w + _Time.x * _Settings.xy);
                half4 mainTex2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.zw + flowTex.zw * _Settings3.w + _Time.x * _Settings.zw);
                half4 mainTex3 = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex, i.uv.zw + flowTex.zw * _Settings3.w + _Time.x * _Settings.zw * 1.3);

                float4 dustCloud = Overlay(mainTex, mainTex2);

                float fresnel = saturate(pow(saturate(dot(normalize(i.worldNormal + (mainTex.xyz + mainTex2.xyz - 1)), normalize(i.viewDir))) * _Settings3.x, _Settings3.y));

                // 使用 _CameraOpaqueTexture 替代 GrabPass
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                screenUV += ((i.worldNormal.xy * _Settings4.xy + dustCloud.xy * _Settings4.zw) * i.uv.y * i.color.g) * fresnel;

                half3 bgColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV).rgb;

                // sky reflection
                float3 reflUV = i.worldRefl * lerp(flowTex.xyz, 1, 1 - i.uv.y);
                half4 skyData = SAMPLE_TEXTURECUBE(_SkyTex, sampler_SkyTex, reflUV + ripple * 5) * 1.5;

                float4 finalColor = float4(bgColor, _Settings5.x);

                finalColor = lerp(finalColor, lerp(_ColorA, _ColorB, dustCloud.r), fresnel);

                finalColor.rgba *= saturate(pow(dot(normalize(i.worldNormal), normalize(i.viewDir)), 3)) * i.uv.y;

                float emissionFactor = saturate(pow(Overlay(Overlay(sin(mainTex.r + mainTex2.b + i.uv.y), mainTex3.r), i.uv.y) * _Settings6.x, _Settings6.y));

                finalColor += lerp(dustCloud.b, dustCloud.a, sin(mainTex.r + mainTex.b)) * emissionFactor * _EmissionColor * i.color.r * _Settings5.y;

                finalColor.rgb = lerp(finalColor.rgb, skyData.rgb, 1 - emissionFactor * 0.5);

                float eventHorizon = (pow((1 - i.uv2.y) * _Settings8.x, _Settings8.y));

                finalColor.rgb = lerp(finalColor.rgb, Overlay(eventHorizon.rrr, finalColor.rgb), saturate(eventHorizon));

                finalColor.a = Overlay(finalColor.a, i.color.r);

                finalColor.a *= _Settings5.w;

                float lum = dot(finalColor.rgb, float3(0.2126, 0.7152, 0.0722));
                float dissolveMask = saturate(((1 - Overlay(i.uv2.y, lum)) - _Settings6.z) / _Settings6.w);

                finalColor.rgb += lerp(Overlay(finalColor, _EmissionColor), Overlay(finalColor, _ColorA), ripple).rgb * ripple * _PhaseStabilization.w * _EmissionColor.rgb;

                finalColor.rgb = lerp(bgColor, finalColor.rgb, saturate(dissolveMask * 2 - 1));

                finalColor.rgba *= saturate(dissolveMask * 4);

                return clamp(finalColor, 0, 10);
            }
            ENDHLSL
        }
    }
}
