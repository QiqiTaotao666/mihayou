Shader "Custom/M_Hole"
{
    Properties
    {
        [HDR] _Color ("Color", Color) = (1,1,1,1)
        _Opacity ("Opacity", Range(0, 1)) = 1
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _FresnelPower ("Fresnel Power", Range(0.1, 20)) = 8
        _FresnelScale ("Fresnel Scale", Range(0, 1)) = 1
        _FresnelCutoff ("Fresnel Cutoff", Range(0, 1)) = 0.5
        _FresnelSoftness ("Fresnel Softness", Range(0.001, 0.5)) = 0.1
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _SwirlSpeed ("Swirl Speed", Float) = 1
        _SwirlStrength ("Swirl Strength", Range(0, 2)) = 0.5
        _EdgeWidth ("Edge Width (Swirl Area)", Range(0, 1)) = 0.3
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "Unlit"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex_ST;
                half4  _Color;
                half   _Opacity;
                half   _FresnelPower;
                half   _FresnelScale;
                half   _FresnelCutoff;
                half   _FresnelSoftness;
                half   _SwirlSpeed;
                half   _SwirlStrength;
                half   _EdgeWidth;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float3 viewDirWS   : TEXCOORD2;
                float3 posOS       : TEXCOORD3;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 posWS    = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(posWS);
                OUT.uv          = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.normalWS    = TransformObjectToWorldNormal(IN.normalOS);
                OUT.viewDirWS   = GetWorldSpaceNormalizeViewDir(posWS);
                OUT.posOS        = IN.positionOS.xyz;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {

                half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv) * _Color;
                c.a *= _Opacity;
                return c;
            }
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Unlit"
}
