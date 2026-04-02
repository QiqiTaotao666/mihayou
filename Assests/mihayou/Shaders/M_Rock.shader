Shader "My/ThrilLayerPBR"
{
    Properties
    {
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
 
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _SmoothnessTextureChannel("Smoothness texture channel", Float) = 0

        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic (R) Occlusion (G) Smoothness (A)", 2D) = "white" {}
        _SpecularIntensity("Specular Intensity", Range(0.0, 1.0)) = 0.5

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}



        [HDR] _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _SecondMap("Second Albedo", 2D) = "white" {}
        _SecondMetallicGlossMap("Second Metallic (R) Occlusion (G) Smoothness (A)", 2D) = "white" {}
        _SecondNoamalMap("Second Normal Map", 2D) = "bump" {}
        _SecondMapScale("SecondNormalScale", Float) = 1.0
        _SecondTilling("Second Tiling", Float) = 1.0
        _Secondsharpness("Second Sharpness", Float) = 1.0

        _TopMap("Top Albedo", 2D) = "white" {}
        _TopMetallicGlossMap("Top Metallic (R) Occlusion (G) Smoothness (A)", 2D) = "white" {}
        _TopNormalMap("Top Normal Map", 2D) = "bump" {}
        _TopMapScale("TopNormalScale", Float) = 1.0
        _TopTilling("Top Tiling", Float) = 1.0
        _Topsharpness("Top Sharpness", Float) = 1.0
        _TopHeightMin("Top Height Min", Float) = 0.0
        _TopHeightMax("Top Height Max", Float) = 1.0
        _TopUpMin("Top Up Min", Range(-1.0, 1.0)) = 0.25
        _TopUpMax("Top Up Max", Range(-1.0, 1.0)) = 1.0

        // SRP batching compatibility for Clear Coat (Not used in Lit)
        [HideInInspector] _ClearCoatMask("_ClearCoatMask", Float) = 0.0
        [HideInInspector] _ClearCoatSmoothness("_ClearCoatSmoothness", Float) = 0.0

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
        // Editmode props
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
        // Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
        // this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
        // material work with both Universal Render Pipeline and Builtin Unity Pipeline
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel"="4.5"}
        LOD 300

        // ------------------------------------------------------------------
        //  Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
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
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
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

            #pragma vertex CustomLitPassVertex
            #pragma fragment CustomLitPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
            #include "Assets/mihayou/Shaders/AdditionalDirShadow.hlsl"

            struct CustomAttributes
            {
                float4 positionOS           : POSITION;
                float3 normalOS             : NORMAL;
                float4 tangentOS            : TANGENT;
                float2 texcoord             : TEXCOORD0;
                float2 staticLightmapUV     : TEXCOORD1;
                float2 dynamicLightmapUV    : TEXCOORD2;
                float4 color                : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct CustomVaryings
            {
                float2 uv                       : TEXCOORD0;

            #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
                float3 positionWS               : TEXCOORD1;
            #endif

                float3 normalWS                 : TEXCOORD2;
            #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
                half4 tangentWS                 : TEXCOORD3;
            #endif
                half4 color                     : COLOR;

            #ifdef _ADDITIONAL_LIGHTS_VERTEX
                half4 fogFactorAndVertexLight   : TEXCOORD5;
            #else
                half fogFactor                  : TEXCOORD5;
            #endif

            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                float4 shadowCoord              : TEXCOORD6;
            #endif

            #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
                half3 viewDirTS                 : TEXCOORD7;
            #endif

                DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
            #ifdef DYNAMICLIGHTMAP_ON
                float2 dynamicLightmapUV        : TEXCOORD9;
            #endif

                float4 positionCS               : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            void InitializeInputData(CustomVaryings input, half3 normalTS, out InputData inputData)
            {
                inputData = (InputData)0;

            #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
                inputData.positionWS = input.positionWS;
            #endif

                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
            #if defined(_NORMALMAP) || defined(_DETAIL)
                float sgn = input.tangentWS.w;
                float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);

                #if defined(_NORMALMAP)
                inputData.tangentToWorld = tangentToWorld;
                #endif
                inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
            #else
                inputData.normalWS = input.normalWS;
            #endif

                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                inputData.viewDirectionWS = viewDirWS;

            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                inputData.shadowCoord = input.shadowCoord;
            #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
            #else
                inputData.shadowCoord = float4(0, 0, 0, 0);
            #endif
            #ifdef _ADDITIONAL_LIGHTS_VERTEX
                inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
                inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
            #else
                inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
            #endif

            #if defined(DYNAMICLIGHTMAP_ON)
                inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
            #else
                inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
            #endif

                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

                #if defined(DEBUG_DISPLAY)
                #if defined(DYNAMICLIGHTMAP_ON)
                inputData.dynamicLightmapUV = input.dynamicLightmapUV;
                #endif
                #if defined(LIGHTMAP_ON)
                inputData.staticLightmapUV = input.staticLightmapUV;
                #else
                inputData.vertexSH = input.vertexSH;
                #endif
                #endif
            }

            CustomVaryings CustomLitPassVertex(CustomAttributes input)
            {
                CustomVaryings output = (CustomVaryings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);

                half fogFactor = 0;
                #if !defined(_FOG_FRAGMENT)
                    fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                #endif

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.normalWS = normalInput.normalWS;
                output.color = input.color;
            #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
                real sign = input.tangentOS.w * GetOddNegativeScale();
                half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
            #endif
            #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
                output.tangentWS = tangentWS;
            #endif

            #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
                half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
                output.viewDirTS = viewDirTS;
            #endif

                OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
            #ifdef DYNAMICLIGHTMAP_ON
                output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
            #endif
                OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
            #ifdef _ADDITIONAL_LIGHTS_VERTEX
                output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
            #else
                output.fogFactor = fogFactor;
            #endif

            #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
                output.positionWS = vertexInput.positionWS;
            #endif

            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                output.shadowCoord = GetShadowCoord(vertexInput);
            #endif

                output.positionCS = vertexInput.positionCS;
                return output;
            }

            half _Opacity;
            half _SpecularIntensity;
            float _USEAdditionalShadow;
            float _SecondMapScale;
            float _SecondTilling;
            float _Secondsharpness;
            float _TopMapScale;
            float _TopTilling;
            float _Topsharpness;
            float _TopHeightMin;
            float _TopHeightMax;
            float _TopUpMin;
            float _TopUpMax;
            TEXTURE2D(_SecondMap);
            SAMPLER(sampler_SecondMap);
            TEXTURE2D(_SecondMetallicGlossMap);
            SAMPLER(sampler_SecondMetallicGlossMap);
            TEXTURE2D(_SecondNoamalMap);
            SAMPLER(sampler_SecondNoamalMap);
            TEXTURE2D(_TopMap);
            SAMPLER(sampler_TopMap);
            TEXTURE2D(_TopMetallicGlossMap);
            SAMPLER(sampler_TopMetallicGlossMap);
            TEXTURE2D(_TopNormalMap);
            SAMPLER(sampler_TopNormalMap);
            float4 _SecondMap_ST;
            float4 _SecondMetallicGlossMap_ST;
            float4 _SecondNoamalMap_ST;
            float4 _TopMap_ST;
            float4 _TopMetallicGlossMap_ST;
            float4 _TopNormalMap_ST;


            float SafeRangeWeight(float value, float minValue, float maxValue)
            {
                float safeMaxValue = max(maxValue, minValue + 1e-5);
                return smoothstep(minValue, safeMaxValue, value);
            }

            float3 GetTriplanarBlendWeights(float3 worldNormal, float sharpness)
            {
                float3 blendWeights = pow(abs(normalize(worldNormal)), sharpness);
                return blendWeights / max(blendWeights.x + blendWeights.y + blendWeights.z, 1e-5);
            }

            half GetTopLayerBlendWeight(half vertexColorR, float3 worldPos, float3 worldNormal)
            {
                half vertexWeight = saturate(vertexColorR);
                half heightWeight = SafeRangeWeight(worldPos.y, _TopHeightMin, _TopHeightMax);
                half upWeight = SafeRangeWeight(normalize(worldNormal).y, _TopUpMin, _TopUpMax);
                return saturate(vertexWeight * heightWeight * upWeight);
            }

            half4 SampleTriplanarTexture(TEXTURE2D_PARAM(tex, samplerTex), float3 worldPos, float3 worldNormal, float2 tiling, float2 offset, float sharpness)
            {
                float3 blendWeights = GetTriplanarBlendWeights(worldNormal, sharpness);
                float3 axisSign = sign(worldNormal);

                float2 uvX = worldPos.zy * tiling + offset;
                float2 uvY = worldPos.xz * tiling + offset;
                float2 uvZ = worldPos.xy * tiling + offset;

                uvX.x *= axisSign.x;
                uvY.x *= axisSign.y;
                uvZ.x *= -axisSign.z;

                half4 sampleX = SAMPLE_TEXTURE2D(tex, samplerTex, uvX);
                half4 sampleY = SAMPLE_TEXTURE2D(tex, samplerTex, uvY);
                half4 sampleZ = SAMPLE_TEXTURE2D(tex, samplerTex, uvZ);

                return sampleX * blendWeights.x + sampleY * blendWeights.y + sampleZ * blendWeights.z;
            }

            half3 SampleTriplanarNormal(TEXTURE2D_PARAM(normalTex, samplerNormalTex), float3 worldPos, float3 worldNormal, float2 tiling, float2 offset, float sharpness, float3 normalScale)
            {
                float3 blendWeights = GetTriplanarBlendWeights(worldNormal, sharpness);
                float3 axisSign = sign(worldNormal);

                float2 uvX = worldPos.zy * tiling + offset;
                float2 uvY = worldPos.xz * tiling + offset;
                float2 uvZ = worldPos.xy * tiling + offset;

                uvX.x *= axisSign.x;
                uvY.x *= axisSign.y;
                uvZ.x *= -axisSign.z;

                half4 sampleX = SAMPLE_TEXTURE2D(normalTex, samplerNormalTex, uvX);
                half4 sampleY = SAMPLE_TEXTURE2D(normalTex, samplerNormalTex, uvY);
                half4 sampleZ = SAMPLE_TEXTURE2D(normalTex, samplerNormalTex, uvZ);

                half3 normalX = half3(UnpackNormalScale(sampleX, normalScale.y).xy * float2(axisSign.x, 1.0) + worldNormal.zy, worldNormal.x).zyx;
                half3 normalY = half3(UnpackNormalScale(sampleY, normalScale.x).xy * float2(axisSign.y, 1.0) + worldNormal.xz, worldNormal.y).xzy;
                half3 normalZ = half3(UnpackNormalScale(sampleZ, normalScale.y).xy * float2(-axisSign.z, 1.0) + worldNormal.xy, worldNormal.z).xyz;

                return normalize(normalX * blendWeights.x + normalY * blendWeights.y + normalZ * blendWeights.z);
            }

            half3 SampleTriplanarNormalTS(TEXTURE2D_PARAM(normalTex, samplerNormalTex), float3 worldPos, float3 worldNormal, half4 tangentWS, float2 tiling, float2 offset, float sharpness, float3 normalScale)
            {
                half3 triplanarNormalWS = SampleTriplanarNormal(TEXTURE2D_ARGS(normalTex, samplerNormalTex), worldPos, worldNormal, tiling, offset, sharpness, normalScale);
                half3 normalWS = normalize(worldNormal);
                half3 tangent = normalize(tangentWS.xyz);
                half tangentSign = tangentWS.w;
                half3 bitangent = tangentSign * cross(normalWS, tangent);
                half3x3 tangentToWorld = half3x3(tangent, bitangent, normalWS);
                return normalize(TransformWorldToTangent(triplanarNormalWS, tangentToWorld));
            }

            half3 BlendNormalRNMCustom(half3 baseNormal, half3 detailNormal)
            {
                half3 n1 = baseNormal + half3(0.0h, 0.0h, 1.0h);
                half3 n2 = detailNormal * half3(-1.0h, -1.0h, 1.0h);
                return normalize(n1 * dot(n1, n2) / max(n1.z, 1e-5h) - n2);
            }

            half3 BlendNormalRNMCustom(half3 baseNormal, half3 detailNormal, half blendFactor)
            {
                half3 blendedNormal = BlendNormalRNMCustom(baseNormal, detailNormal);
                return normalize(lerp(baseNormal, blendedNormal, saturate(blendFactor)));
            }

            half4 CustomLitPassFragment(CustomVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                SurfaceData surfaceData = (SurfaceData)0;
                // Normal Map
                surfaceData.normalTS = SampleNormal(input.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);

                #ifdef _NORMALMAP
                    half3 secondNormalTS = SampleTriplanarNormalTS(
                        TEXTURE2D_ARGS(_SecondNoamalMap, sampler_SecondNoamalMap),
                        input.positionWS,
                        input.normalWS,
                        input.tangentWS,
                        float2(_SecondTilling, _SecondTilling),
                        _SecondNoamalMap_ST.zw,
                        _Secondsharpness,
                        float3(_SecondMapScale, _SecondMapScale, _SecondMapScale)
                    );
                    surfaceData.normalTS = BlendNormalRNMCustom(surfaceData.normalTS, secondNormalTS);

                    half3 topNormalTS = SampleTriplanarNormalTS(
                        TEXTURE2D_ARGS(_TopNormalMap, sampler_TopNormalMap),
                        input.positionWS,
                        input.normalWS,
                        input.tangentWS,
                        float2(_TopTilling, _TopTilling),
                        _TopNormalMap_ST.zw,
                        _Topsharpness,
                        float3(_TopMapScale, _TopMapScale, _TopMapScale)
                    );
                #endif

                // Albedo + Alpha
                half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                surfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);
                surfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
                surfaceData.albedo = AlphaModulate(surfaceData.albedo, surfaceData.alpha);

                // Second Map
                half4 secondMap = SampleTriplanarTexture(TEXTURE2D_ARGS(_SecondMap, sampler_SecondMap), input.positionWS, input.normalWS, float2(_SecondTilling, _SecondTilling), _SecondMap_ST.zw, _Secondsharpness);
                half4 secondMetallicGloss = SampleTriplanarTexture(TEXTURE2D_ARGS(_SecondMetallicGlossMap, sampler_SecondMetallicGlossMap), input.positionWS, input.normalWS, float2(_SecondTilling, _SecondTilling), _SecondMetallicGlossMap_ST.zw, _Secondsharpness);
                half4 topMap = SampleTriplanarTexture(TEXTURE2D_ARGS(_TopMap, sampler_TopMap), input.positionWS, input.normalWS, float2(_TopTilling, _TopTilling), _TopMap_ST.zw, _Topsharpness);
                half4 topMetallicGloss = SampleTriplanarTexture(TEXTURE2D_ARGS(_TopMetallicGlossMap, sampler_TopMetallicGlossMap), input.positionWS, input.normalWS, float2(_TopTilling, _TopTilling), _TopMetallicGlossMap_ST.zw, _Topsharpness);
                half topBlend = GetTopLayerBlendWeight(input.color.r, input.positionWS, input.normalWS);
                surfaceData.albedo *= secondMap.rgb;

                #ifdef _NORMALMAP
                    surfaceData.normalTS = BlendNormalRNMCustom(surfaceData.normalTS, topNormalTS, topBlend);
                #endif

                // Metallic + Smoothness
                #ifdef _METALLICSPECGLOSSMAP
                    half4 metallicGloss = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, input.uv);
                    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                        metallicGloss.a = albedoAlpha.a * _Smoothness;
                    #else
                        metallicGloss.a *= _Smoothness;
                    #endif
                #else
                    half4 metallicGloss = half4(_Metallic, 0, 0, 0);
                    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                        metallicGloss.a = albedoAlpha.a * _Smoothness;
                    #else
                        metallicGloss.a = _Smoothness;
                    #endif
                #endif
                surfaceData.metallic = metallicGloss.r * secondMetallicGloss.r;
                surfaceData.specular = half3(_SpecularIntensity, _SpecularIntensity, _SpecularIntensity);
                surfaceData.smoothness = metallicGloss.a * secondMetallicGloss.a;

                surfaceData.albedo = lerp(surfaceData.albedo, topMap.rgb, topBlend);
                surfaceData.metallic = lerp(surfaceData.metallic, topMetallicGloss.r, topBlend);
                surfaceData.smoothness = lerp(surfaceData.smoothness, topMetallicGloss.a, topBlend);

                // Occlusion (AO)
                surfaceData.occlusion = metallicGloss.g * secondMetallicGloss.g;
                surfaceData.occlusion = lerp(surfaceData.occlusion, topMetallicGloss.g, topBlend);

                // Emission
                surfaceData.emission = SampleEmission(input.uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));

                // Clear Coat
                surfaceData.clearCoatMask       = half(0.0);
                surfaceData.clearCoatSmoothness  = half(0.0);

                // InputData
                InputData inputData;
                InitializeInputData(input, surfaceData.normalTS, inputData);
                SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

            #ifdef _DBUFFER
                ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
            #endif

                half4 color = UniversalFragmentPBR(inputData, surfaceData);

                if (_USEAdditionalShadow > 0.5)
                {
                    color.rgb = CalculateAdditionalDirLightPBR(inputData, surfaceData);
                }

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

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
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

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
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

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }


        // This pass is used when drawing to a _CameraNormalsTexture texture
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

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
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
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }
    }



    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "ThrilLayerPBRShaderGUI"

}
