Shader "My/LensFlare"
{
    Properties
    {
        _MainTex("_MainTex", 2D) = "white" {}
        _AlphaScale("AlphaScale", Float) = 1
        [HDR]_Tint("Tint", Color) = (1,1,1,1)
        _Color_Pow_Scale("Color_Pow_Scale", Vector) = (1,1,0,0)
        _AlphaCenterFade_Pow_Scale("AlphaCenterFade_Pow_Scale", Vector) = (1,1,0,0)
        [Toggle(_ENABLEALPHACENTERFADE_ON)] _EnableAlphaCenterFade("EnableAlphaCenterFade", Float) = 0
        [HideInInspector] _texcoord( "", 2D ) = "white" {}

        // Blending
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 10
        [Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2

        // Queue
        [HideInInspector] _QueueOffset("Queue Offset", Float) = 0.0

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
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }
        LOD 100

        Blend [_SrcBlend] [_DstBlend]
        AlphaToMask Off
        Cull [_Cull]
        ColorMask RGBA
        ZWrite [_ZWrite]
        ZTest [_ZTest]
        Offset 0, 0

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
            Name "Unlit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma shader_feature_local _ENABLEALPHACENTERFADE_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct MeshData
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float4 ase_texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct V2FData
            {
                float4 vertex : SV_POSITION;
                float4 ase_texcoord1 : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float2 _Color_Pow_Scale;
                float4 _Tint;
                float _AlphaScale;
                float2 _AlphaCenterFade_Pow_Scale;
                float _SrcBlend;
                float _DstBlend;
                float _ZWrite;
                float _ZTest;
                float _Cull;
                float _QueueOffset;
                float _StencilRef;
                float _StencilComp;
                float _StencilPass;
                float _StencilFail;
                float _StencilZFail;
                float _StencilReadMask;
                float _StencilWriteMask;
            CBUFFER_END

            V2FData vert(MeshData v)
            {
                V2FData o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                o.ase_texcoord1.xy = v.ase_texcoord.xy;
                o.ase_texcoord1.zw = 0;

                // Billboard: 用观察空间的 right/up 轴重建顶点位置
                float3 centerWS = TransformObjectToWorld(float3(0, 0, 0));
                float3 viewDir = normalize(_WorldSpaceCameraPos - centerWS);

                // 从 UNITY_MATRIX_V 取摄像机的 right 和 up
                float3 camRight = UNITY_MATRIX_V[0].xyz;
                float3 camUp    = UNITY_MATRIX_V[1].xyz;

                // 用模型空间的 xy 偏移（保留物体缩放）
                float3 scaleX = float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x);
                float3 scaleY = float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y);
                float sX = length(scaleX);
                float sY = length(scaleY);

                float3 billboardWS = centerWS
                    + camRight * (v.vertex.x * sX)
                    + camUp    * (v.vertex.y * sY);

                o.vertex = TransformWorldToHClip(billboardWS);
                return o;
            }

            half4 frag(V2FData i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float2 uv_MainTex = i.ase_texcoord1.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                float4 tex2DNode1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv_MainTex);

                float2 texCoord10 = i.ase_texcoord1.xy * float2(1, 1) + float2(0, 0);

                #ifdef _ENABLEALPHACENTERFADE_ON
                    float staticSwitch17 = (pow((1.0 - distance(texCoord10, float2(0.5, 0.5))), _AlphaCenterFade_Pow_Scale.x) * _AlphaCenterFade_Pow_Scale.y);
                #else
                    float staticSwitch17 = _AlphaScale;
                #endif

                float4 appendResult7 = float4(
                    ((pow(tex2DNode1.r, _Color_Pow_Scale.x) * _Color_Pow_Scale.y) * _Tint).rgb,
                    (tex2DNode1.a * staticSwitch17)
                );

                return appendResult7;
            }
            ENDHLSL
        }
    }
}
