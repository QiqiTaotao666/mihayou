Shader "My/Skybox_Cubemap"
{
    Properties
    {
        [NoScaleOffset] _Cubemap ("Cubemap", Cube) = "" {}
        [HDR] _Tint ("Tint Color", Color) = (1,1,1,1)
        _Exposure ("Exposure", Range(0, 8)) = 1.0
        _Rotation ("Rotation (Y-Axis)", Range(0, 360)) = 0
        _RotationX ("Rotation (X-Axis)", Range(0, 360)) = 0
        _RotationSpeed ("Rotation Speed", Float) = 0

        [Header(Cloud)]
        [NoScaleOffset] _CloudCubemap ("Cloud Cubemap", Cube) = "" {}
        [HDR] _CloudTint ("Cloud Tint", Color) = (1,1,1,1)
        _CloudExposure ("Cloud Exposure", Range(0, 8)) = 1.0
        _CloudRotation ("Cloud Rotation", Range(0, 360)) = 0
        _CloudRotationSpeed ("Cloud Rotation Speed", Float) = 1

        // Star Properties
        [Header(Star Noise 1)]
        _Noise1PowScale("Noise1 PowScale", Vector) = (100, 50, 0, 0)
        _Noise1Scale("Noise1 Scale", Float) = 200
        _Noise1RotateSpeed("Noise1 Rotate Speed", Float) = -0.035

        [Header(Star Noise 2)]
        _Noise2PowScale("Noise2 PowScale", Vector) = (150, 1000, 0, 0)
        _Noise2Scale("Noise2 Scale", Float) = 100
        _Noise2RotateSpeed("Noise2 Rotate Speed", Float) = -0.07

        [Header(Star Noise Mask)]
        _NoiseMaskPowScale("NoiseMask PowScale", Vector) = (1, 1, 0, 0)
        _NoiseMaskScale("NoiseMask Scale", Float) = 2
        _NoiseMaskRotateSpeed("NoiseMask Rotate Speed", Float) = 0.1

        [Header(Cloud Gradient)]
        _GradientColorIntensity("Gradient Color Intensity", Range(0, 1)) = 1
        _CloudGradient("Cloud Gradient", 2D) = "white" {}

        [Header(Star Background)]
        _BGTint1("BG Tint1", Color) = (0, 0, 0, 0)
        _BGTint2("BG Tint2", Color) = (0.65, 0.62, 1, 0)
        _PosMin("Pos Min", Range(0, 1)) = 0
        _PosMax("Pos Max", Range(0, 1)) = 0.083

        _StarIntensity("Star Intensity", Range(0, 2)) = 1

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
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" "RenderPipeline"="UniversalPipeline" }

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

        Cull Off
        ZWrite Off

        Pass
        {
            Name "Skybox_Cubemap"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 texcoord : TEXCOORD0;
                float3 vertexPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            TEXTURECUBE(_Cubemap);
            TEXTURECUBE(_CloudCubemap);
            SAMPLER(sampler_Cubemap); // fallback
            // seamless cubemap sampler
            SamplerState skybox_trilinear_clamp_sampler;
            TEXTURE2D(_CloudGradient); SAMPLER(sampler_CloudGradient);

            CBUFFER_START(UnityPerMaterial)
                half4 _Tint;
                half  _Exposure;
                float _Rotation;
                float _RotationX;
                float _RotationSpeed;

                half4 _CloudTint;
                half  _CloudExposure;
                float _CloudRotation;
                float _CloudRotationSpeed;

                float4 _Noise1PowScale;
                float  _Noise1Scale;
                float  _Noise1RotateSpeed;

                float4 _Noise2PowScale;
                float  _Noise2Scale;
                float  _Noise2RotateSpeed;

                float4 _NoiseMaskPowScale;
                float  _NoiseMaskScale;
                float  _NoiseMaskRotateSpeed;

                float  _GradientColorIntensity;

                float4 _BGTint1;
                float4 _BGTint2;
                float  _PosMin;
                float  _PosMax;

                float  _StarIntensity;
            CBUFFER_END

            // --- Rotate around arbitrary axis ---
            float3 RotateAroundAxis(float3 center, float3 original, float3 u, float angle)
            {
                original -= center;
                float C = cos(angle);
                float S = sin(angle);
                float t = 1.0 - C;
                float m00 = t * u.x * u.x + C;
                float m01 = t * u.x * u.y - S * u.z;
                float m02 = t * u.x * u.z + S * u.y;
                float m10 = t * u.x * u.y + S * u.z;
                float m11 = t * u.y * u.y + C;
                float m12 = t * u.y * u.z - S * u.x;
                float m20 = t * u.x * u.z - S * u.y;
                float m21 = t * u.y * u.z + S * u.x;
                float m22 = t * u.z * u.z + C;
                float3x3 finalMatrix = float3x3(m00, m01, m02, m10, m11, m12, m20, m21, m22);
                return mul(finalMatrix, original) + center;
            }

            // --- Rotate around Y axis (cubemap rotation) ---
            float3 RotateAroundYAxis(float3 v, float degree)
            {
                float rad = degree * PI / 180.0;
                float s = sin(rad);
                float c = cos(rad);
                return float3(v.x * c - v.z * s, v.y, v.x * s + v.z * c);
            }

            // --- Rotate around X axis ---
            float3 RotateAroundXAxis(float3 v, float degree)
            {
                float rad = degree * PI / 180.0;
                float s = sin(rad);
                float c = cos(rad);
                return float3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
            }

            // --- Simplex 3D Noise ---
            float3 mod289_3(float3 x) { return x - floor(x / 289.0) * 289.0; }
            float4 mod289_4(float4 x) { return x - floor(x / 289.0) * 289.0; }
            float4 permute(float4 x) { return mod289_4((x * 34.0 + 1.0) * x); }
            float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - r * 0.85373472095314; }

            float snoise(float3 v)
            {
                const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
                float3 i = floor(v + dot(v, C.yyy));
                float3 x0 = v - i + dot(i, C.xxx);
                float3 g = step(x0.yzx, x0.xyz);
                float3 l = 1.0 - g;
                float3 i1 = min(g.xyz, l.zxy);
                float3 i2 = max(g.xyz, l.zxy);
                float3 x1 = x0 - i1 + C.xxx;
                float3 x2 = x0 - i2 + C.yyy;
                float3 x3 = x0 - 0.5;
                i = mod289_3(i);
                float4 p = permute(permute(permute(
                    i.z + float4(0.0, i1.z, i2.z, 1.0))
                    + i.y + float4(0.0, i1.y, i2.y, 1.0))
                    + i.x + float4(0.0, i1.x, i2.x, 1.0));
                float4 j = p - 49.0 * floor(p / 49.0);
                float4 x_ = floor(j / 7.0);
                float4 y_ = floor(j - 7.0 * x_);
                float4 x = (x_ * 2.0 + 0.5) / 7.0 - 1.0;
                float4 y = (y_ * 2.0 + 0.5) / 7.0 - 1.0;
                float4 h = 1.0 - abs(x) - abs(y);
                float4 b0 = float4(x.xy, y.xy);
                float4 b1 = float4(x.zw, y.zw);
                float4 s0 = floor(b0) * 2.0 + 1.0;
                float4 s1 = floor(b1) * 2.0 + 1.0;
                float4 sh = -step(h, 0.0);
                float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
                float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
                float3 g0 = float3(a0.xy, h.x);
                float3 g1 = float3(a0.zw, h.y);
                float3 g2 = float3(a1.xy, h.z);
                float3 g3 = float3(a1.zw, h.w);
                float4 norm = taylorInvSqrt(float4(dot(g0, g0), dot(g1, g1), dot(g2, g2), dot(g3, g3)));
                g0 *= norm.x;
                g1 *= norm.y;
                g2 *= norm.z;
                g3 *= norm.w;
                float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
                m = m * m;
                m = m * m;
                float4 px = float4(dot(x0, g0), dot(x1, g1), dot(x2, g2), dot(x3, g3));
                return 42.0 * dot(m, px);
            }

            // --- PowerScale helper (pow then multiply) ---
            float PowerScale(float val, float p, float s)
            {
                return pow(max(val, 0.0001), p) * s;
            }

            v2f vert(appdata v)
            {
                v2f o;
                VertexPositionInputs posInputs = GetVertexPositionInputs(v.vertex.xyz);
                o.pos = posInputs.positionCS;
                o.texcoord = v.vertex.xyz;
                o.vertexPos = v.vertex.xyz;
                o.uv = v.uv;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                // --- Original cubemap skybox ---
                float3 dir = RotateAroundYAxis(normalize(i.texcoord), _Rotation + _Time.y * _RotationSpeed);
                dir = RotateAroundXAxis(dir, _RotationX);
                half4 cubemap = SAMPLE_TEXTURECUBE_LOD(_Cubemap, skybox_trilinear_clamp_sampler, dir, 0);
                half3 skyColor = cubemap.rgb * _Tint.rgb * _Exposure;

                // --- Cloud cubemap ---
                float3 cloudDir = RotateAroundYAxis(normalize(i.texcoord), _CloudRotation + _Time.y * _CloudRotationSpeed);
                half4 cloudCubemap = SAMPLE_TEXTURECUBE_LOD(_CloudCubemap, skybox_trilinear_clamp_sampler, cloudDir, 0);
                // Cloud gradient (sample by cloud luminance)
                half cloudGray = dot(cloudCubemap.rgb, half3(0.299, 0.587, 0.114));
                float2 gradUV = float2(saturate(cloudGray), 0.5);
                half4 gradColor = SAMPLE_TEXTURE2D(_CloudGradient, sampler_CloudGradient, gradUV);
                half4 cloudGrad = lerp(half4(1,1,1,0), gradColor, _GradientColorIntensity);
                half3 cloudColor = cloudCubemap.rgb * _CloudTint.rgb * _CloudExposure * cloudGrad.rgb;
                skyColor += cloudColor;

                // --- Star calculation ---
                float3 vPos = RotateAroundYAxis(i.vertexPos, _Time.y * _RotationSpeed);
                vPos = RotateAroundXAxis(vPos, _RotationX);
                float timeX = _Time.x;

                // Noise 1: rotate around X axis (1,0,0)
                float3 rotated1 = RotateAroundAxis(float3(0,0,0), vPos, float3(1,0,0), timeX * _Noise1RotateSpeed);
                float n1 = snoise(rotated1 * _Noise1Scale) * 0.5 + 0.5;
                float star1 = PowerScale(n1, _Noise1PowScale.x, _Noise1PowScale.y);

                // Noise 2: rotate around (1,1,0) axis
                float3 rotated2 = RotateAroundAxis(float3(0,0,0), vPos, float3(1,1,0), timeX * _Noise2RotateSpeed);
                float n2 = snoise(rotated2 * _Noise2Scale) * 0.5 + 0.5;
                float star2 = PowerScale(n2, _Noise2PowScale.x, _Noise2PowScale.y);

                // Noise Mask: rotate around (1,1,0) axis
                float3 rotatedMask = RotateAroundAxis(float3(0,0,0), vPos, float3(1,1,0), timeX * _NoiseMaskRotateSpeed);
                float nMask = snoise(rotatedMask * _NoiseMaskScale) * 0.5 + 0.5;
                float mask = PowerScale(nMask, _NoiseMaskPowScale.x, _NoiseMaskPowScale.y);

                // Combine: Noise2 * Mask, clamped to 10
                half4 combined = min(star2 * mask, 10.0);

                // Star = max(Noise1, combined)
                half4 starResult = max(star1, combined);

                // Background gradient based on vertex Y position
                float bgBlend = smoothstep(_PosMin, _PosMax, vPos.y);
                half4 bgColor = lerp(_BGTint1, _BGTint2, bgBlend);

                // Final star layer
                half4 starLayer = (starResult + bgColor) * _StarIntensity;

                // Blend star layer with cubemap skybox (additive)
                half3 finalColor = skyColor + starLayer.rgb;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }

    Fallback Off
}
