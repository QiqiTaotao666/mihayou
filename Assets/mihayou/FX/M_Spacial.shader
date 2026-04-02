Shader "My/SpacialDust"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc("BlendMode Src", Float) = 5
		[Enum(UnityEngine.Rendering.BlendMode)] _BlendDst("BlendMode Dst", Float) = 10
        _Progress("Progress", float) = 1
        [HDR]_ColorA ("Cloud Color A", Color) = (1,1,1,1)
        [HDR]_ColorB ("Cloud Color B", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _FlowTex ("Flow Displace", 2D) = "white" {}
        [Header(ScrollSpeed1 XY l ScrollSpeed2 XY)]
        _Settings("", Vector) = (1,1,1,1)
        [Header(Fresnel Mult Pow l Speed l Influence)]
        _Settings3("", Vector) = (1,1,1,1)
        [Header(UV Distort XY l Flow Distort XY)]
        _Settings4("", Vector) = (1,1,1,1)
        [Header(Distort Opacity l Emission Opacity l EMPTY l Global Opacity)]
        _Settings5("", Vector) = (1,1,1,1)
        [Header(Emission Mult l Pow l Progress l EMPTY)]
        _Settings6("", Vector) = (1,1,1,1)
        [HDR]_EmissionColor ("Emission Color", Color) = (1,1,1,1)
        [HDR]_EmissionColor2 ("Emission Color 2", Color) = (1,1,1,1)

        [IntRange] _StencilRef ("Stencil Reference Value", Range(0,255)) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("Stencil Comp", Int) = 8
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Int) = 4
    }
    SubShader
    {
        Blend [_BlendSrc] [_BlendDst]
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline"}
        ZWrite Off
        Cull Off
        LOD 100
        ZTest [_ZTest]

        Stencil{
                Ref [_StencilRef]
                Comp [_StencilComp]
            }

        Pass
        {
            Name "SpacialDust"
            Tags { "LightMode"="SRPDefaultUnlit" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #include "StargateCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                float4 worldNormal : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
                float4 screenPos : TEXCOORD4;
            };

            TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);
            TEXTURE2D(_FlowTex);        SAMPLER(sampler_FlowTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST, _FlowTex_ST;
                float4 _Settings, _Settings3, _Settings4, _Settings5, _Settings6;
                float4 _ColorA, _ColorB, _EmissionColor, _EmissionColor2;
                float _Progress;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs posInputs = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = posInputs.positionCS;

                o.uv.xy = v.uv.xy * _MainTex_ST.xy;
                o.uv.zw = v.uv.xy * _MainTex_ST.zw;

                o.uv1.xy = v.uv.xy * _FlowTex_ST.xy;
                o.uv1.zw = v.uv.xy * _FlowTex_ST.zw;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal);
                o.worldNormal.xyz = normalInputs.normalWS;
                o.worldNormal.w = v.uv.y;

                float3 worldPos = posInputs.positionWS;
                o.viewDir = GetWorldSpaceNormalizeViewDir(worldPos);

                o.color = v.color;
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // 屏幕UV（SampleSceneColor 内部处理平台翻转）
                float2 screenUV = i.screenPos.xy / i.screenPos.w;

                half4 flowTex = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex,
                    i.uv1.xy + _Time.x * _Settings3.z * float2(-1, 1));

                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                    i.uv.xy + flowTex.xy * _Settings3.w + _Time.x * _Settings.xy);
                half4 mainTex2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                    i.uv.zw + flowTex.zw * _Settings3.w + _Time.x * _Settings.zw);
                half4 mainTex3 = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex,
                    i.uv.zw + flowTex.zw * _Settings3.w + _Time.x * _Settings.zw * 1.3);

                float4 dustCloud = Overlay(mainTex, mainTex2);

                float fresnel = saturate(pow(
                    saturate(dot(
                        normalize(i.worldNormal.xyz + (mainTex.xyz + mainTex2.xyz - 1)),
                        normalize(i.viewDir)
                    )) * _Settings3.x,
                    _Settings3.y));

                // 扰动屏幕UV，参考 M_Distortion 的做法
                float2 distort = (i.worldNormal.xy * _Settings4.xy + dustCloud.xy * _Settings4.zw)
                    * i.uv.y * i.color.g * fresnel;
                float2 distortedUV = screenUV + distort;

                // 用 URP 官方 SampleSceneColor 采样屏幕颜色
                half3 bgColor = SampleSceneColor(distortedUV);

                float4 finalColor = float4(bgColor, _Settings5.x);

                float4 debug = finalColor;
                finalColor = lerp(finalColor, lerp(_ColorA, _ColorB, dustCloud.r), fresnel);

                finalColor.rgba *= saturate(pow(dot(normalize(i.worldNormal.xyz), normalize(i.viewDir)), 1.5)) * i.uv.y;

                float emissionFactor = pow(
                    Overlay(Overlay(sin(mainTex.r + mainTex2.b + i.uv.y), mainTex3.r), i.uv.y) * _Settings6.x,
                    _Settings6.y);

                finalColor += lerp(dustCloud.b, dustCloud.a, sin(mainTex.r + mainTex.b))
                    * emissionFactor
                    * lerp(_EmissionColor, _EmissionColor2, i.uv.y)
                    * i.color.r * _Settings5.y;

                finalColor.a = Overlay(finalColor.a, i.color.r);
                finalColor.a *= _Settings5.a;

                finalColor.rgba *= lerp(1, sin(saturate(_Settings6.z + i.worldNormal.w) * PI), _Progress);

                finalColor *= i.color.b;

                return float4(finalColor);
            }
            ENDHLSL
        }
    }

}
