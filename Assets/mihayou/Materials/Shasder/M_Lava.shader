Shader "My/Lava"
{
    Properties
    {
        // === Lava Main ===
        _Tiling("Tiling", Float) = 1
        _Speed("Speed", Float) = 0
        _EdgeDistance("Edge Distance", Float) = 10
        [Space(10)][Header(Main)][Space(10)]
        [MainColor] _MainColor("Main Color", Color) = (1,1,1,1)
        _Albedo("Albedo", 2D) = "white" {}
        [Normal] _Normal("Normal", 2D) = "bump" {}
        [HDR] _EmissiveColor("Emissive Color", Color) = (1,1,1,1)
        _Emissive("Emissive", 2D) = "white" {}
        _EmissiveTiling("Emissive Tiling", Float) = 2.7
        _DepthContrast("Depth Contrast", Float) = 0
        [Toggle] _InvertDepth("Invert Depth", Float) = 1

        // === Layer Maps ===
        [Space(10)][Header(Layer Maps)][Space(10)]
        _LayerAlbedo("Layer Albedo", 2D) = "white" {}
        [Normal] _LayerNormal("Layer Normal", 2D) = "bump" {}
        _LayerNormalPower("Layer Normal Power", Range(0, 1)) = 1
        _LayerTiling("Layer Tiling", Float) = 1

        // === Distortion ===
        [Space(10)][Header(Distortion)][Space(10)]
        _DistortionPower("Distortion Power", Range(0, 1)) = 0
        [Normal] _Distortion("Distortion", 2D) = "bump" {}
        _DistorsionScale("Distorsion Scale", Float) = 1
        _DistortionSpeed("Distortion Speed", Float) = 0

        // === PBR Override ===
        [Space(10)][Header(PBR)][Space(10)]
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.25

        // CubeMap Reflection
        _EnvCubeMap("Environment CubeMap", Cube) = "" {}
        _EnvCubeMapIntensity("CubeMap Intensity", Range(0.0, 2.0)) = 0.0

        // Opacity
        _Opacity("Opacity", Range(0.0, 1.0)) = 1.0

        // Shadow
        [Toggle] _CastShadows("Cast Shadows", Float) = 1.0
        [Toggle] _USEAdditionalShadow("USE Additional Shadow", Float) = 0.0

        // Stencil
        _StencilRef("Stencil Ref", Range(0, 255)) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilFail("Stencil Fail", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilZFail("Stencil ZFail", Float) = 0
        _StencilReadMask("Stencil Read Mask", Range(0, 255)) = 255
        _StencilWriteMask("Stencil Write Mask", Range(0, 255)) = 255

        // Depth
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4

        // Blending state
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0

        _ReceiveShadows("Receive Shadows", Float) = 1.0
        [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0

        // ObsoleteProperties
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
        [HideInInspector] _Color("Base Color", Color) = (1, 1, 1, 1)

        [HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
    }

    SubShader
    {
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel"="4.5"}
        LOD 300

        // ------------------------------------------------------------------
        //  Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZWrite On
            ZTest[_ZTest]
            Cull[_Cull]

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
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            // Force emission always on for lava
            #define _EMISSION 1
            #define _NORMALMAP 1

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #define REQUIRE_DEPTH_TEXTURE 1

            #pragma vertex LavaLitPassVertex
            #pragma fragment LavaLitPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
            #include "Assets/mihayou/Shaders/AdditionalDirShadow.hlsl"

            // === Lava Textures ===
            sampler2D _Albedo;
            sampler2D _Normal;
            sampler2D _Distortion;
            sampler2D _LayerAlbedo;
            sampler2D _LayerNormal;
            sampler2D _Emissive;

            TEXTURECUBE(_EnvCubeMap);
            SAMPLER(sampler_EnvCubeMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainColor;
                float4 _EmissiveColor;
                float _Tiling;
                float _Speed;
                float _DistortionSpeed;
                float _DistorsionScale;
                float _DistortionPower;
                float _EdgeDistance;
                float _LayerTiling;
                float _LayerNormalPower;
                float _InvertDepth;
                float _DepthContrast;
                float _EmissiveTiling;
                float _Metallic;
                float _Smoothness;
                half _Opacity;
                float _USEAdditionalShadow;
                half _EnvCubeMapIntensity;
                half _Surface;
                half _Cutoff;
            CBUFFER_END

            struct LavaAttributes
            {
                float4 positionOS : POSITION;
                half3 normalOS : NORMAL;
                half4 tangentOS : TANGENT;
                float4 texcoord : TEXCOORD0;
                float4 texcoord1 : TEXCOORD1;
                float4 ase_color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct LavaVaryings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half4 tangentWS : TEXCOORD2;
                float4 lightmapUVOrVertexSH : TEXCOORD3;
                half4 fogFactorAndVertexLight : TEXCOORD4;
                float2 uv : TEXCOORD5;
                float4 ase_color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            LavaVaryings LavaLitPassVertex(LavaAttributes input)
            {
                LavaVaryings output = (LavaVaryings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                output.tangentWS = float4(normalInput.tangentWS, (input.tangentOS.w > 0.0 ? 1.0 : -1.0) * GetOddNegativeScale());
                output.uv = input.texcoord.xy;
                output.ase_color = input.ase_color;

                #if defined(LIGHTMAP_ON)
                    OUTPUT_LIGHTMAP_UV(input.texcoord1, unity_LightmapST, output.lightmapUVOrVertexSH.xy);
                #else
                    OUTPUT_SH(normalInput.normalWS.xyz, output.lightmapUVOrVertexSH.xyz);
                #endif

                output.fogFactorAndVertexLight = half4(0, 0, 0, 0);
                output.fogFactorAndVertexLight.x = ComputeFogFactor(vertexInput.positionCS.z);
                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    output.fogFactorAndVertexLight.yzw = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                #endif

                return output;
            }

            half4 LavaLitPassFragment(LavaVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // === Screen position & Depth Fade ===
                float4 ScreenPosNorm = float4(GetNormalizedScreenSpaceUV(input.positionCS), input.positionCS.zw);
                float screenDepth = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH(ScreenPosNorm.xy), _ZBufferParams);
                float distanceDepth = abs((screenDepth - LinearEyeDepth(ScreenPosNorm.z, _ZBufferParams)) / (_EdgeDistance));
                float saferPowerDepth = abs(distanceDepth);
                float DepthFade = saturate(pow(saferPowerDepth, 2.5));

                // === UV Panning ===
                float2 mainUV = input.uv * _Tiling;
                float2 panDir = float2(0.0, _Speed);
                float2 pannerMain = _Time.y * panDir + mainUV;

                // === Distortion ===
                float2 distUV = input.uv * _DistorsionScale;
                float2 distPanDir = float2(0.0, _DistortionSpeed);
                float2 pannerDist = _Time.y * distPanDir + distUV;
                float distPower = _DistortionPower * DepthFade;
                float3 unpackDist = UnpackNormalScale(tex2D(_Distortion, pannerDist), distPower);
                unpackDist.z = lerp(1, unpackDist.z, saturate(distPower));
                float2 distOffset = unpackDist.xy;

                float2 finalMainUV = pannerMain + distOffset;

                // === Layer UV ===
                float2 layerUV = input.uv * _LayerTiling;

                // === Layer blend factor ===
                float saferPowerEdge = abs(1.0 - DepthFade);
                float layerBlend = pow(saferPowerEdge, 20.0);

                // === Albedo: blend main + layer ===
                float mainAlbedoR = tex2D(_Albedo, finalMainUV).r;
                float4 mainColorContrib = _MainColor * (mainAlbedoR * (1.0 - DepthFade));
                float3 layerAlbedo = tex2D(_LayerAlbedo, layerUV).rgb;
                float3 finalAlbedo = lerp(mainColorContrib.rgb, layerAlbedo, layerBlend);

                // === Normal: blend main + layer ===
                float3 unpackMainNormal = UnpackNormalScale(tex2D(_Normal, finalMainUV), (1.0 - DepthFade));
                unpackMainNormal.z = lerp(1, unpackMainNormal.z, saturate(1.0 - DepthFade));
                float3 unpackLayerNormal = UnpackNormalScale(tex2D(_LayerNormal, layerUV), _LayerNormalPower);
                unpackLayerNormal.z = lerp(1, unpackLayerNormal.z, saturate(_LayerNormalPower));
                float3 finalNormalTS = lerp(unpackMainNormal, unpackLayerNormal, layerBlend);

                // === Emissive: Hex-tile sampling ===
                float2 emissiveUV = (pannerMain / float2(_EmissiveTiling, _EmissiveTiling)) + distOffset;
                // Hex-tile stochastic sampling
                float2 hexScaledUV = mul(float2x2(1, 0, -0.5773503, 1.154701), (emissiveUV * float2(3.464, 3.464)));
                float2 hexFrac = frac(hexScaledUV);
                float hexSign = ((1.0 - hexFrac.x) - hexFrac.y);
                float2 hexFloor = floor(hexScaledUV);
                float2 hexCenter1 = hexFloor + float2(1, 1);

                float2 hexCell0 = (hexSign > 0.0) ? hexFloor : hexCenter1;
                float hexW0 = (hexSign <= 0.0) ? (-hexSign) : hexSign;

                float2 hexCellA = (hexSign > 0.0) ? (hexFloor + float2(0, 1)) : (hexFloor + float2(1, 0));
                float hexWA = (hexSign <= 0.0) ? (1.0 - hexFrac.x) : hexFrac.y;

                float2 hexCellB = (hexSign > 0.0) ? (hexFloor + float2(1, 0)) : (hexFloor + float2(0, 1));
                float hexWB = (hexSign <= 0.0) ? (1.0 - hexFrac.y) : hexFrac.x;

                // Hash function for random offset per cell
                float3 hash0 = frac(hexCell0.xyx * float3(0.1031, 0.103, 0.0973));
                hash0 += dot(hash0, hash0.yzx + 33.33);
                hash0 = hash0 + dot(hash0, hash0.yzx + 33.33);
                float2 randOffset0 = frac(((hash0.xx + hash0.yz) * hash0.zy).xy);

                float3 hashA = frac(hexCellA.xyx * float3(0.1031, 0.103, 0.0973));
                hashA += dot(hashA, hashA.yzx + 33.33);
                hashA = hashA + dot(hashA, hashA.yzx + 33.33);
                float2 randOffsetA = frac(((hashA.xx + hashA.yz) * hashA.zy).xy);

                float3 hashB = frac(hexCellB.xyx * float3(0.1031, 0.103, 0.0973));
                hashB += dot(hashB, hashB.yzx + 33.33);
                hashB = hashB + dot(hashB, hashB.yzx + 33.33);
                float2 randOffsetB = frac(((hashB.xx + hashB.yz) * hashB.zy).xy);

                float2 emDdx = ddx(emissiveUV);
                float2 emDdy = ddy(emissiveUV);

                float4 emSample0 = tex2Dgrad(_Emissive, emissiveUV + randOffset0, emDdx, emDdy) * hexW0;
                float4 emSampleA = tex2Dgrad(_Emissive, emissiveUV + randOffsetA, emDdx, emDdy) * hexWA;
                float4 emSampleB = tex2Dgrad(_Emissive, emissiveUV + randOffsetB, emDdx, emDdy) * hexWB;
                float4 hexEmissive = emSample0 + emSampleA + emSampleB;

                float emissiveR = hexEmissive.r;
                float saferPowerEm = abs(emissiveR * emissiveR);
                float depthMask = DepthFade * ((_InvertDepth > 0.5) ? input.ase_color.g : (1.0 - input.ase_color.r));
                float saferPowerMask = abs(depthMask);
                float depthPow = pow(saferPowerMask, (1.0 - _DepthContrast));
                float3 emissionMain = _EmissiveColor.rgb * (pow(saferPowerEm, depthPow) * saturate(depthPow));
                float4 colorBlack = float4(0, 0, 0, 0);
                //float3 finalEmission = lerp(emissionMain, colorBlack.rgb, layerBlend);
                float3 finalEmission = saferPowerEm*_EmissiveColor.rgb;

                // === Build SurfaceData ===
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = finalAlbedo;
                surfaceData.metallic = _Metallic;
                surfaceData.specular = half3(0.0, 0.0, 0.0);
                surfaceData.smoothness = _Smoothness;
                surfaceData.normalTS = finalNormalTS;
                surfaceData.occlusion = 1.0;
                surfaceData.emission = finalEmission;
                surfaceData.alpha = 1.0;
                surfaceData.clearCoatMask = 0.0;
                surfaceData.clearCoatSmoothness = 0.0;

                // === Build InputData ===
                float renormFactor = 1.0 / max(FLT_MIN, length(input.normalWS));
                float3 NormalWS = input.normalWS * renormFactor;
                float3 TangentWS = input.tangentWS.xyz * renormFactor;
                float3 BitangentWS = cross(input.normalWS, input.tangentWS.xyz) * input.tangentWS.w * renormFactor;

                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                inputData.normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(finalNormalTS, half3x3(TangentWS, BitangentWS, NormalWS)));

                #if defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                #else
                    inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif

                inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
                #endif

                #if defined(LIGHTMAP_ON)
                    float3 SH = float3(0, 0, 0);
                #else
                    float3 SH = input.lightmapUVOrVertexSH.xyz;
                #endif
                inputData.bakedGI = SAMPLE_GI(input.lightmapUVOrVertexSH.xy, SH, inputData.normalWS);
                inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUVOrVertexSH.xy);
                inputData.normalizedScreenSpaceUV = ScreenPosNorm.xy;

                #ifdef _DBUFFER
                    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
                #endif

                // === DEBUG: 直接输出自发光 ===
                //return half4(emissionMain, 1.0);

                // === Lighting (dual system) ===
                half4 color = UniversalFragmentPBR(inputData, surfaceData);

                if (_USEAdditionalShadow > 0.5)
                {
                    color.rgb = CalculateAdditionalDirLightPBR(inputData, surfaceData);
                }

                // === CubeMap Reflection ===
                half3 reflectDir = reflect(-inputData.viewDirectionWS, inputData.normalWS);
                half mipLevel = (1.0 - surfaceData.smoothness) * 6.0;
                half3 envColor = SAMPLE_TEXTURECUBE_LOD(_EnvCubeMap, sampler_EnvCubeMap, reflectDir, mipLevel).rgb;
                color.rgb += envColor * _EnvCubeMapIntensity;

                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                color.a = OutputAlpha(color.a, _Surface);
                color.a *= _Opacity;
                return color;
            }
            ENDHLSL
        }


        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma shader_feature_local_fragment _ALPHATEST_ON

            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "AdditionalDirDepthOnly"
            Tags{"LightMode" = "AdditionalDirDepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma shader_feature_local_fragment _ALPHATEST_ON

            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma shader_feature_local_fragment _ALPHATEST_ON

            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LavaShaderGUI"
}
