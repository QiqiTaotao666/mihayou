Shader "MY/Water"
{
    Properties
    {
        _ReflectionTex("_ReflectionTex", 2D) = "white" {}
        _Normal("Normal", 2D) = "bump" {}
        _Normal2("Normal2", 2D) = "bump" {}
        _Titling("Titling", Float) = 0
        _NormalScale("NormalScale", Range(0, 2)) = 0
        _NormalScale2("NormalScale2", Range(0, 2)) = 0
        _Speed("Speed", Range(0, 1)) = 0
        _SpecularRange("SpecularRange", Range(0, 1)) = 0
        _SpecularIntensity("SpecularIntensity", Range(0, 2)) = 0
        _Distortion("Distortion", Range(0, 1)) = 0
        [HDR]_SpecularTint("SpecularTint", Color) = (1,1,1,0)
        _DistortRange("DistortRange", Range(0, 1)) = 0
        _RipplePos("RipplePos", Vector) = (-0.064,-0.075,0.002,0)
        _RippleRange("RippleRange", Float) = 5.0
        _RippleFrequency("RippleFrequency", Float) = 15.0
        _RippleIntensity("RippleIntensity", Float) = 1.0

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
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        LOD 100

        Pass
        {
            Name "Unlit"
            Tags { "LightMode" = "UniversalForward" }

            Blend Off
            AlphaToMask Off
            Cull Back
            ColorMask RGBA
            ZWrite On
            ZTest LEqual
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

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            TEXTURE2D(_ReflectionTex);   SAMPLER(sampler_ReflectionTex);
            TEXTURE2D(_Normal);          SAMPLER(sampler_Normal);
            TEXTURE2D(_Normal2);         SAMPLER(sampler_Normal2);

            CBUFFER_START(UnityPerMaterial)
                float  _Distortion;
                float  _Titling;
                float  _Speed;
                float  _NormalScale;
                float  _NormalScale2;
                float3 _RipplePos;
                float  _RippleRange;
                float  _RippleFrequency;
                float  _RippleIntensity;
                float  _DistortRange;
                float  _SpecularRange;
                float  _SpecularIntensity;
                float4 _SpecularTint;
            CBUFFER_END

            // ---- helpers ----
            float3 UnpackScaleNormalURP(float4 packednormal, float scale)
            {
                float3 normal;
                normal.xy = (packednormal.wy * 2.0 - 1.0) * scale;
                normal.z = sqrt(saturate(1.0 - dot(normal.xy, normal.xy)));
                return normal;
            }

            float3 BlendNormals(float3 n1, float3 n2)
            {
                return normalize(float3(n1.xy + n2.xy, n1.z * n2.z));
            }

            float3 PerturbNormal107_g7(float3 surf_pos, float3 surf_norm, float height, float scale)
            {
                float3 vSigmaS = ddx(surf_pos);
                float3 vSigmaT = ddy(surf_pos);
                float3 vN = surf_norm;
                float3 vR1 = cross(vSigmaT, vN);
                float3 vR2 = cross(vN, vSigmaS);
                float fDet = dot(vSigmaS, vR1);
                float dBs = ddx(height);
                float dBt = ddy(height);
                float3 vSurfGrad = scale * 0.05 * sign(fDet) * (dBs * vR1 + dBt * vR2);
                return normalize(abs(fDet) * vN - vSurfGrad);
            }

            struct MeshData
            {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float3 normal   : NORMAL;
                float4 tangent  : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct V2FData
            {
                float4 posCS     : SV_POSITION;
                float3 worldPos  : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 worldNorm : TEXCOORD2;
                float3 worldTan  : TEXCOORD3;
                float3 worldBiT  : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            V2FData vert(MeshData v)
            {
                V2FData o = (V2FData)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                VertexPositionInputs posInputs = GetVertexPositionInputs(v.vertex.xyz);
                o.posCS    = posInputs.positionCS;
                o.worldPos = posInputs.positionWS;
                o.screenPos = ComputeScreenPos(o.posCS);

                VertexNormalInputs nrmInputs = GetVertexNormalInputs(v.normal, v.tangent);
                o.worldNorm = nrmInputs.normalWS;
                o.worldTan  = nrmInputs.tangentWS;
                o.worldBiT  = nrmInputs.bitangentWS;

                return o;
            }

            half4 frag(V2FData i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 WorldPosition = i.worldPos;

                // screen UV
                float4 screenPos = i.screenPos;
                float4 ase_screenPosNorm = screenPos / screenPos.w;
                ase_screenPosNorm.z = (UNITY_NEAR_CLIP_VALUE >= 0)
                    ? ase_screenPosNorm.z
                    : ase_screenPosNorm.z * 0.5 + 0.5;

                // tiling & speed
                float2 temp_output_15_0 = WorldPosition.xz * _Titling;
                float mulTime9 = _Time.y * (_Speed * 0.1);
                float2 temp_output_12_0 = mulTime9 * float2(0, 1);

                // ---- RippleCircle ----
                float3 ase_worldNormal = i.worldNorm;
                float temp_output_70_0 = 1.0 - saturate(distance(_RipplePos.xz, WorldPosition.xz) / _RippleRange);
                float mulTime85 = _Time.y * 0.1;
                float height107_g7 = temp_output_70_0 * cos((temp_output_70_0 + mulTime85) * _RippleFrequency * 3.14) * _RippleIntensity;
                float3 localPerturbNormal = PerturbNormal107_g7(WorldPosition, ase_worldNormal, height107_g7, 1.0);

                float3 ase_worldTangent   = i.worldTan;
                float3 ase_worldBitangent = i.worldBiT;
                float3x3 worldToTangent   = float3x3(ase_worldTangent, ase_worldBitangent, ase_worldNormal);
                float3 RippleCircle79     = mul(worldToTangent, localPerturbNormal);

                // ---- BlendNormalMap ----
                float3 n1 = UnpackScaleNormalURP(SAMPLE_TEXTURE2D(_Normal,  sampler_Normal,  temp_output_15_0 + temp_output_12_0),  _NormalScale);
                float3 n2 = UnpackScaleNormalURP(SAMPLE_TEXTURE2D(_Normal2, sampler_Normal2, temp_output_15_0 - temp_output_12_0), _NormalScale2);
                float3 BlendNormalMap39 = BlendNormals(BlendNormals(n1, n2), RippleCircle79);

                // ---- Reflection ----
                float3 normalizedWorldNormal = normalize(ase_worldNormal);
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(WorldPosition);
                float dotNV = dot(normalizedWorldNormal, viewDirWS);
                float smoothstepResult56 = smoothstep(0.0, _DistortRange, dotNV);

                float3 distortVec = _Distortion * BlendNormalMap39 * 0.1;
                float4 distortSwizzle = float4(distortVec.y, distortVec.x, distortVec.z, distortVec.z);
                float4 reflUV = ase_screenPosNorm + distortSwizzle * smoothstepResult56;
                float4 Reflection48 = SAMPLE_TEXTURE2D(_ReflectionTex, sampler_ReflectionTex, reflUV.xy);

                // ---- Specular (GGX) ----
                float roughness = _SpecularRange;
                float clampedR = clamp(roughness, 0.01, 0.99);
                float a2 = clampedR * clampedR;

                // world normal from tangent-space blended normal
                float3 tanToWorld0 = float3(ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x);
                float3 tanToWorld1 = float3(ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y);
                float3 tanToWorld2 = float3(ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z);
                float3 worldNormal4 = normalize(float3(
                    dot(tanToWorld0, BlendNormalMap39),
                    dot(tanToWorld1, BlendNormalMap39),
                    dot(tanToWorld2, BlendNormalMap39)));

                // main light direction (URP)
                Light mainLight = GetMainLight();
                float3 lightDirWS = normalize(mainLight.direction);

                float3 N = normalize(worldNormal4);
                float3 L = lightDirWS;
                float3 V = viewDirWS;
                float3 H = normalize(L + V);

                // NDF (GGX)
                float NdotH = saturate(dot(N, H));
                float denom = NdotH * NdotH * (a2 - 1.0) + 1.0;
                float D = a2 / max(denom * denom * PI, 0.0001);

                // Fresnel (Schlick, F0=0.04)
                float NdotV = saturate(dot(N, V));
                float F = pow(1.0 - NdotV, 5.0) * (1.0 - 0.04) + 0.04;

                float4 Specular43 = (D * F * _SpecularIntensity) * _SpecularTint;
                //return float4(n2, 1.0);
                // ---- Final ----
                return Reflection48 + Specular43;

            }
            ENDHLSL
        }
    }
}
