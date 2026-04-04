Shader "My/Sun"
{
    Properties
    {
        [HDR] _Color ("Color", Color) = (1,1,1,1)
        _Opacity ("Opacity", Range(0,1)) = 1.0
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _MainTexRotSpeed ("Main Tex Rotation Speed", Float) = 0.0
        _MainTexFlowSpeed ("Main Tex Flow Speed (XY)", Vector) = (0, 0.1, 0, 0)
        _SecondTex ("Second Texture", 2D) = "white" {}
        _SecondTexRotSpeed ("Second Tex Rotation Speed", Float) = 0.0
        _SecondTexBlend ("Second Tex Blend", Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" }
        LOD 200

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float fogFactor : TEXCOORD2;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_SecondTex);
            SAMPLER(sampler_SecondTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _SecondTex_ST;
                half4 _Color;
                half _Opacity;
                half _MainTexRotSpeed;
                float4 _MainTexFlowSpeed;
                half _SecondTexRotSpeed;
                half _SecondTexBlend;
            CBUFFER_END

            float2 RotateUV(float2 uv, float angle)
            {
                float s, c;
                sincos(angle, s, c);
                float2 center = float2(0.5, 0.5);
                uv -= center;
                float2 rotated = float2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
                return rotated + center;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.uv2 = TRANSFORM_TEX(IN.uv2, _SecondTex);
                OUT.fogFactor = ComputeFogFactor(OUT.positionHCS.z);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 uv1 = RotateUV(IN.uv, _Time.y * _MainTexRotSpeed);
                uv1 += _Time.y * _MainTexFlowSpeed.xy;
                float2 uv2 = RotateUV(IN.uv2, _Time.y * _SecondTexRotSpeed);

                half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv1) ;
                half4 c2 = SAMPLE_TEXTURE2D(_SecondTex, sampler_SecondTex, uv2);
                c.a = c.a * _Opacity*c.r*c2.r;
                c.rgb = c.rgb * _Color;
                c.rgb = MixFog(c.rgb, IN.fogFactor);
                return c;
            }
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Lit"
}
