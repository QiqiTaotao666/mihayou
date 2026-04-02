Shader "My/Moon"
{
    Properties
    {
        _MainTex("_MainTex", 2D) = "white" {}
        _DistortTex("Distort Tex", 2D) = "gray" {}
        _DistortIntensity("Distort Intensity", Range(0, 1)) = 0.1
        _DistortSpeed("Distort Speed", Vector) = (0.1, 0.05, 0, 0)
        _MaskTex("Mask Tex", 2D) = "white" {}
        _MaskIntensity("Mask Intensity", Range(0, 2)) = 1
        [HDR]_MaskColor("Mask Color", Color) = (1,1,1,1)
        _MaskContrast("Mask Contrast", Range(0.1, 5)) = 1
        [HDR]_Color0("Color 0", Color) = (1,1,1,0)
        _Vector0("Vector 0", Vector) = (0,1,5,0)
        _OutlineVec("OutlineVec", Vector) = (0,1,5,0)
        [HDR]_OutlineColor("OutlineColor", Color) = (1,1,1,0)
        [HDR]_Tint("Tint", Color) = (0,0,0,0)
        _Contrast("Contrast", Range(0.1, 5)) = 1
        _Intensity("Intensity", Range(0, 5)) = 1

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
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }
        LOD 100

        Pass
        {
            Name "Unlit"
            Tags { "LightMode"="UniversalForward" }

            Blend Off
            Cull Back
            ZWrite On
            ZTest LEqual

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

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct MeshData
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
                float3 normalOS   : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct V2FData
            {
                float4 positionCS  : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float2 uv1         : TEXCOORD3;
                float2 uv2         : TEXCOORD4;
                float3 worldPos    : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_DistortTex);
            SAMPLER(sampler_DistortTex);
            TEXTURE2D(_MaskTex);
            SAMPLER(sampler_MaskTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _DistortTex_ST;
                float  _DistortIntensity;
                float4 _DistortSpeed;
                float4 _MaskTex_ST;
                float  _MaskIntensity;
                half4  _MaskColor;
                float  _MaskContrast;
                half4  _Tint;
                half4  _Color0;
                float3 _Vector0;
                half4  _OutlineColor;
                float3 _OutlineVec;
                float  _Contrast;
                float  _Intensity;
            CBUFFER_END

            V2FData vert(MeshData v)
            {
                V2FData o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                VertexPositionInputs posInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS  = posInputs.positionCS;
                o.worldPos    = posInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS);
                o.worldNormal = normalInputs.normalWS;

                o.uv  = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv1 = v.uv * _MaskTex_ST.xy + _MaskTex_ST.zw;
                o.uv2 = v.uv * _DistortTex_ST.xy + _DistortTex_ST.zw;

                return o;
            }

            half4 frag(V2FData i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                // View direction
                float3 worldViewDir = normalize(GetWorldSpaceViewDir(i.worldPos));
                float3 worldNormal  = normalize(i.worldNormal);

                // Fresnel (inner glow)
                float NdotV4 = dot(worldNormal, worldViewDir);
                float fresnel4 = _Vector0.x + _Vector0.y * pow(max(1.0 - NdotV4, 0.0001), _Vector0.z);

                // Fresnel (outline)
                float NdotV9 = dot(worldNormal, worldViewDir);
                float fresnel9 = _OutlineVec.x + _OutlineVec.y * pow(max(1.0 - NdotV9, 0.0001), _OutlineVec.z);

                // UV distortion
                float2 distortUV = i.uv2 + _Time.y * _DistortSpeed.xy;
                half4 distortSample = SAMPLE_TEXTURE2D(_DistortTex, sampler_DistortTex, distortUV);
                float2 distortOffset = (distortSample.rb - 0.5) * 2.0 * _DistortIntensity;
                float2 distortedUV = i.uv + distortOffset;

                // Sample texture
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, distortedUV);

                // Sample mask texture and multiply with main texture
                half4 maskColor = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, i.uv1);
                maskColor *= _MaskColor;
                maskColor.rgb = saturate(pow(maskColor.rgb / 0.5, _MaskContrast) * 0.5);
                texColor *= lerp(1.0, maskColor, _MaskIntensity);

                // Contrast: remap around midpoint 0.5
                texColor.rgb = saturate(pow(texColor.rgb / 0.5, _Contrast) * 0.5);

                // Combine
                half4 baseColor = (texColor * _Tint) + (_Color0 * fresnel4);
                half4 finalColor = lerp(baseColor, _OutlineColor, saturate(fresnel9));

                finalColor.rgb *= _Intensity;

                return finalColor;
            }
            ENDHLSL
        }
    }
}