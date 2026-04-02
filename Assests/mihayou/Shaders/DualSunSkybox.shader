Shader "Skybox/DualSunSkybox"
{
    Properties
    {
        [Header(Sky)]
        _SkyTopColor ("Sky Top Color", Color) = (0.2, 0.5, 0.85, 1)
        _SkyHorizonColor ("Sky Horizon Color", Color) = (0.65, 0.82, 0.95, 1)
        _SkyGroundColor ("Ground Color", Color) = (0.3, 0.25, 0.2, 1)
        _SkyExponent ("Sky Gradient Exponent", Range(0.1, 10)) = 2.0
        _HorizonSharpness ("Horizon Sharpness", Range(0.1, 10)) = 3.0

        [Header(Sun A Main Sun)]
        _SunADirection ("Sun A Direction", Vector) = (0.5, 0.3, 0.5, 0)
        _SunAColor ("Sun A Color", Color) = (1, 0.95, 0.8, 1)
        _SunAIntensity ("Sun A Intensity", Range(0, 10)) = 2.0
        _SunASize ("Sun A Size", Range(0.001, 0.2)) = 0.05
        _SunAGlowSize ("Sun A Glow Size", Range(0.01, 1.0)) = 0.2
        _SunAGlowIntensity ("Sun A Glow Intensity", Range(0, 5)) = 1.0

        [Header(Sun B Second Sun)]
        _SunBDirection ("Sun B Direction", Vector) = (-0.6, 0.2, 0.3, 0)
        _SunBColor ("Sun B Color", Color) = (1, 0.6, 0.3, 1)
        _SunBIntensity ("Sun B Intensity", Range(0, 10)) = 1.5
        _SunBSize ("Sun B Size", Range(0.001, 0.2)) = 0.04
        _SunBGlowSize ("Sun B Glow Size", Range(0.01, 1.0)) = 0.15
        _SunBGlowIntensity ("Sun B Glow Intensity", Range(0, 5)) = 0.8

        [Header(Atmosphere)]
        _AtmosphereTint ("Atmosphere Tint", Color) = (1, 0.7, 0.4, 1)
        _AtmosphereIntensity ("Atmosphere Intensity", Range(0, 3)) = 0.5
        _AtmosphereExponent ("Atmosphere Exponent", Range(1, 20)) = 5.0

        [Header(Stars Optional)]
        _StarsDensity ("Stars Density", Range(0, 500)) = 100
        _StarsIntensity ("Stars Intensity", Range(0, 2)) = 0.0
    }

    SubShader
    {
        Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" }
        Cull Off
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 viewDir : TEXCOORD0;
            };

            // Sky
            half4 _SkyTopColor;
            half4 _SkyHorizonColor;
            half4 _SkyGroundColor;
            half _SkyExponent;
            half _HorizonSharpness;

            // Sun A
            float4 _SunADirection;
            half4 _SunAColor;
            half _SunAIntensity;
            half _SunASize;
            half _SunAGlowSize;
            half _SunAGlowIntensity;

            // Sun B
            float4 _SunBDirection;
            half4 _SunBColor;
            half _SunBIntensity;
            half _SunBSize;
            half _SunBGlowSize;
            half _SunBGlowIntensity;

            // Atmosphere
            half4 _AtmosphereTint;
            half _AtmosphereIntensity;
            half _AtmosphereExponent;

            // Stars
            half _StarsDensity;
            half _StarsIntensity;

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.viewDir = v.vertex.xyz;
                return o;
            }

            // Simple hash for stars
            float hash(float3 p)
            {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            // Calculate sun contribution
            half3 calcSun(float3 viewDir, float3 sunDir, half3 sunColor, half intensity,
                          half sunSize, half glowSize, half glowIntensity)
            {
                float cosAngle = dot(viewDir, sunDir);

                // Hard sun disc
                float sunDisc = smoothstep(1.0 - sunSize * 0.01, 1.0 - sunSize * 0.005, cosAngle);
                half3 sun = sunColor * sunDisc * intensity;

                // Soft glow around sun
                float glow = pow(saturate(cosAngle), 1.0 / max(glowSize * 0.1, 0.001));
                sun += sunColor * glow * glowIntensity;

                // Bloom / halo
                float halo = pow(saturate(cosAngle), 8.0) * 0.5;
                sun += sunColor * halo * glowIntensity * 0.3;

                return sun;
            }

            half4 frag(v2f i) : SV_Target
            {
                float3 viewDir = normalize(i.viewDir);
                float y = viewDir.y;

                // === Sky gradient ===
                // Upper sky: horizon -> top
                float skyFactor = pow(saturate(y), _SkyExponent);
                half3 skyUpper = lerp(_SkyHorizonColor.rgb, _SkyTopColor.rgb, skyFactor);

                // Lower sky: horizon -> ground
                float groundFactor = pow(saturate(-y), _HorizonSharpness);
                half3 skyLower = lerp(_SkyHorizonColor.rgb, _SkyGroundColor.rgb, groundFactor);

                // Combine
                half3 sky = (y >= 0) ? skyUpper : skyLower;

                // === Sun A ===
                float3 sunADir = normalize(_SunADirection.xyz);
                half3 sunA = calcSun(viewDir, sunADir, _SunAColor.rgb, _SunAIntensity,
                                     _SunASize, _SunAGlowSize, _SunAGlowIntensity);

                // === Sun B ===
                float3 sunBDir = normalize(_SunBDirection.xyz);
                half3 sunB = calcSun(viewDir, sunBDir, _SunBColor.rgb, _SunBIntensity,
                                     _SunBSize, _SunBGlowSize, _SunBGlowIntensity);

                // === Atmosphere scattering near horizon ===
                float horizonMask = 1.0 - abs(y);
                horizonMask = pow(saturate(horizonMask), _AtmosphereExponent);

                // Atmosphere tinted by both suns
                float sunAHorizon = saturate(dot(sunADir, float3(viewDir.x, 0, viewDir.z)));
                float sunBHorizon = saturate(dot(sunBDir, float3(viewDir.x, 0, viewDir.z)));
                half3 atmosphere = _AtmosphereTint.rgb * horizonMask * _AtmosphereIntensity
                                   * (sunAHorizon * 0.6 + sunBHorizon * 0.4);

                // === Stars (visible when sky is dark / looking up at night side) ===
                half3 stars = half3(0, 0, 0);
                if (_StarsIntensity > 0.001)
                {
                    float3 starPos = floor(viewDir * _StarsDensity);
                    float starHash = hash(starPos);
                    float starBrightness = step(0.98, starHash) * starHash;
                    // Fade stars near suns and horizon
                    float sunFade = saturate(1.0 - saturate(dot(viewDir, sunADir)) * 3.0)
                                  * saturate(1.0 - saturate(dot(viewDir, sunBDir)) * 3.0);
                    float upFade = saturate(y * 2.0);
                    stars = starBrightness * _StarsIntensity * sunFade * upFade;
                }

                // === Combine ===
                half3 finalColor = sky + sunA + sunB + atmosphere + stars;

                return half4(finalColor, 1.0);
            }
            ENDCG
        }
    }
    FallBack Off
}
