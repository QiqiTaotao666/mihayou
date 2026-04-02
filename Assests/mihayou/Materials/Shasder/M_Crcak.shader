Shader "QF/Env/0Ice/IceThickness_SuperHigh"
{
	Properties
	{
		[KeywordEnum(Subsurface,Cracks)] _ICE("ice mode", Float) = 0

		_TopColor("TopColor",color) = (1,1,1,1)
		_BottomColor("BottomColor",color) = (0.5,0.5,0.5,1)
		[MainTexture] _MainTex("MainTexture", 2D) = "white" {}
		_BrightPartColor("BrightPartColor", Color) = (1,1,1,1)
		
		_SpecMaskCubemask("SpecMaskCubemask(R:高光/G:不透明度/B:Cube遮罩)", 2D) = "yellow" {}

		_SpecularColor("SpecularColor", color) = (1,1,1,1)
		_SpecularGloss("SpecularGloss",range(2.0,256.0)) = 20.0
		_SpecularIntensity("SpecularIntensity",float) = 1.0
		_Opacity("Opacity(Mask强度,控制整体不透明度)",range(0.0,2.0)) = 1.0
		_NormalMap("NormalMap", 2D) = "bump" {}
		_NormalScale("NormalScale", range(0.0,2.0)) = 1.0

		[Toggle(_PLANAR_REFLECTION_ON)] _PlanarReflection("实时反射(Lod High以上生效)", Float) = 0.0
		_ReflectionCube("ReflectionCube",Cube) = "white"{}
		_ReflectionIntensity("ReflectionIntensity",range(0.5,1.5)) = 1
		_ReflectionBumpScale("ReflectionBumpScale",range(0.0,1)) = 0.8

		_FresnelBias("FresnelBias",range(0.0,1.0)) = 0.04
		_FresnelPower("FresnelPower",range(0.0,5.0)) = 8.0
		_UnRealFresnelScale("(非真实参数)FresnelScale",range(0.0,1.0)) = 1

		_Distortion("Distortion(冰层内部扭曲强度)", range(0.0,1.0)) = 0.2

		_DustColor("DustColor",color) = (1,1,1,1)
		_DustTex("DustTex(中低画质此图无效，注意效果差异)", 2D) = "black" {}
		_DustHeight("DustHeight",float) = 0.15
		_DustSecondNumStepU("DustSecondNumStepU",range(0.0,1.0)) = 0.0
		_DustSecondNumStepV("DustSecondNumStepV",range(0.0,1.0)) = 0.0

		[Header(_______Subsurface________________________)]
		[Space]
		_SubColor("SubColor",color) = (0.5,0.5,0.5,1)
		_TransmissionTex("TransmissionTex(R:Trickness贴图/G:程序生成)", 2D) = "red" {}
		_SubOpacity("SubOpacity(散射的光线量)",range(0.0,1.0)) = 0.0
		_TransmissionShadowScale("TransmissionShadowScale(TransmissionTex G通道缩放值)",float) = 1.0

		[Header(_______Cracks____________________________)]
		[Space]
		_CracksTex("CracksTex", 2D) = "black" {}
		_CracksColor("CracksColor",color) = (1,1,1,1)
		_CracksHeight("CracksHeight",range(0.0,0.2)) = 0.1
		_CracksDepthScatterng("CracksDepthScatterng",float) = 0.1
		_CracksDepthStepSize("CracksDepthStepSize",float) = 0.03
		_CracksDepthSmooth("CracksDepthSmooth",float) = 0.5
		_CracksWidth("CracksWidth",float) = 0.98

		_LowGlowCol("LowGlowCol",color) = (1,1,1,1)
		_LowGlow("LowGlow", 2D) = "black" {}
		_LowGlowMul("LowGlowMul", Float) = 1.0
		
		[Header(_______Weather________________________)]
		[Space]
		[Toggle(_TIRE_TRACK)] _TireTrack("_TireTrack 胎印", Float) = 0.0	
		_TireTrackMask("Tire Track Mask 胎印Mask",2D) = "white" {}

		[Header(_______Shadow_________________________)]
		[Space]
		[Toggle] _USEAdditionalShadow("USE Additional Shadow", Float) = 0.0

		[Header(_______Stencil________________________)]
		[Space]
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
		Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel" = "4.5" }
		LOD 500

		Pass
		{
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }

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
			ZWrite On
			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			#pragma multi_compile _ICE_SUBSURFACE _ICE_CRACKS

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

			// -------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing

			#pragma shader_feature_local _ _TIRE_TRACK
			#pragma shader_feature_local _ _PLANAR_REFLECTION_ON

			#pragma vertex vert
			#pragma fragment frag_superhigh

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Assets/mihayou/Shaders/AdditionalDirShadow.hlsl"

			// =============================================
			// Material Properties (CBUFFER for SRP Batcher)
			// =============================================
			CBUFFER_START(UnityPerMaterial)
				half4 _TopColor;
				half4 _BottomColor;
				half4 _BrightPartColor;

				float4 _MainTex_ST;

				half4 _SpecularColor;
				half _SpecularGloss;
				half _SpecularIntensity;
				half _Opacity;
				float4 _NormalMap_ST;
				half _NormalScale;
				half _ReflectionIntensity;
				half _ReflectionBumpScale;
				half _FresnelBias;
				half _FresnelPower;
				half _UnRealFresnelScale;

				half _Distortion;

				half4 _DustColor;
				float4 _DustTex_ST;
				half _DustHeight;
				half _DustSecondNumStepU;
				half _DustSecondNumStepV;

				half3 _CracksColor;
				half _CracksHeight;
				half _CracksDepthStepSize;
				half _CracksDepthSmooth;
				half _CracksDepthScatterng;
				half _CracksWidth;

				half3 _SubColor;
				half _SubOpacity;
				half _TransmissionShadowScale;

				half4 _LowGlowCol;
				float4 _LowGlow_ST;
				half _LowGlowMul;

				float _USEAdditionalShadow;
			CBUFFER_END

			// Textures & Samplers
			TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);
			TEXTURE2D(_SpecMaskCubemask); SAMPLER(sampler_SpecMaskCubemask);
			TEXTURE2D(_NormalMap);       SAMPLER(sampler_NormalMap);
			TEXTURECUBE(_ReflectionCube); SAMPLER(sampler_ReflectionCube);
			TEXTURE2D(_DustTex);         SAMPLER(sampler_DustTex);
			TEXTURE2D(_CracksTex);       SAMPLER(sampler_CracksTex);
			TEXTURE2D(_TransmissionTex); SAMPLER(sampler_TransmissionTex);
			TEXTURE2D(_LowGlow);         SAMPLER(sampler_LowGlow);
			TEXTURE2D(_TireTrackMask);   SAMPLER(sampler_TireTrackMask);

		#ifdef _PLANAR_REFLECTION_ON
			TEXTURE2D(_MirrorReflectionTex); SAMPLER(sampler_MirrorReflectionTex);
		#endif

			// =============================================
			// Helper Functions
			// =============================================

			half3 GetLM(half NoL, float2 UV, half occlusion, half3 mainLightColor)
			{
				half3 LM = half3(1, 1, 1);
			#if defined(LIGHTMAP_ON)
				half4 bakedColorTex = SAMPLE_TEXTURE2D(unity_Lightmap, samplerunity_Lightmap, UV);
				half3 lmGI = bakedColorTex.rgb * 5.0;
				#if defined(SHADOWS_SHADOWMASK)
					LM = (bakedColorTex.a * mainLightColor * saturate(NoL) * _BrightPartColor.rgb) + lmGI * occlusion;
				#else
					LM = lmGI * occlusion;
				#endif
			#else
				LM = mainLightColor * saturate(NoL) * _BrightPartColor.rgb * occlusion;
			#endif
				return LM;
			}

			half GetFresnel(half NoV, half bias, half power)
			{
				half facing = (1.0 - NoV);
				return saturate(bias + (1 - bias) * pow(facing, power));
			}

			// =============================================
			// Structs
			// =============================================
			struct appdata
			{
				half4 color : COLOR;
				float4 vertex : POSITION;
				half3 normal : NORMAL;
				half4 tangent : TANGENT;
				float2 texcoord : TEXCOORD0;
				float2 texcoord1 : TEXCOORD1;
				float2 texcoord2 : TEXCOORD2;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				half4 color : COLOR;
				float4 vertex : SV_POSITION;
				float4 texcoord : TEXCOORD0;     // xy: mainTex uv, zw: dustTex uv
				float4 texcoord1 : TEXCOORD1;    // xy: lightmap uv, zw: texcoord2
				float4 TtoW0 : TEXCOORD2;
				float4 TtoW1 : TEXCOORD3;
				float4 TtoW2 : TEXCOORD4;
				half4 normal : TEXCOORD5;        // xyz: obj normal, w: binormal.x
				half4 tangent : TEXCOORD6;       // xyz: obj tangent, w: binormal.y
				half fogFactor : TEXCOORD7;
			#if defined(_TIRE_TRACK) || defined(_PLANAR_REFLECTION_ON)
				half4 screenPos : TEXCOORD8;
			#endif
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			// =============================================
			// Vertex Shader
			// =============================================
			v2f vert(appdata v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				o.color = v.color;

				VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
				o.vertex = vertexInput.positionCS;

				float3 WPOS = vertexInput.positionWS;
				half3 WNormal = TransformObjectToWorldNormal(v.normal);
				half3 WTangent = TransformObjectToWorldDir(v.tangent.xyz);
				half3 WBinormal = cross(WNormal, WTangent) * v.tangent.w;

				o.texcoord.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.texcoord.zw = TRANSFORM_TEX(v.texcoord, _DustTex);

				o.TtoW0 = float4(WTangent.x, WBinormal.x, WNormal.x, WPOS.x);
				o.TtoW1 = float4(WTangent.y, WBinormal.y, WNormal.y, WPOS.y);
				o.TtoW2 = float4(WTangent.z, WBinormal.z, WNormal.z, WPOS.z);

				o.normal.xyz = v.normal;
				o.tangent.xyz = v.tangent.xyz;
				half3 binormal = cross(v.normal, v.tangent.xyz) * v.tangent.w;
				o.normal.w = binormal.x;
				o.tangent.w = binormal.y;
				o.color.a = (binormal.z + 1) / 2;

			#ifdef LIGHTMAP_ON
				o.texcoord1.xy = v.texcoord1 * unity_LightmapST.xy + unity_LightmapST.zw;
			#else
				o.texcoord1.xy = v.texcoord1;
			#endif
				o.texcoord1.zw = v.texcoord2;

				o.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

			#if defined(_TIRE_TRACK) || defined(_PLANAR_REFLECTION_ON)
				o.screenPos = ComputeScreenPos(o.vertex);
			#endif
				return o;
			}

			// =============================================
			// Fragment Shader
			// =============================================
			half4 frag_superhigh(v2f i) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);

				float3 WPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);

				// Light source (主光 / 额外方向光切换)
				half3 mainLightColor;
				half3 L;
				if (_USEAdditionalShadow > 0.5 && _AdditionalDirShadowEnabled > 0.5)
				{
					Light addLight = GetAdditionalDirLight(WPos);
					mainLightColor = addLight.color * addLight.shadowAttenuation;
					L = normalize(addLight.direction);
				}
				else
				{
					Light mainLight = GetMainLight();
					mainLightColor = mainLight.color;
					L = normalize(mainLight.direction);
				}

				float3 UNnorV = (GetCameraPositionWS() - WPos);
				half3 V = normalize(UNnorV);
				half3 TN = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.texcoord.xy * _NormalMap_ST.xy));
				TN.xy *= _NormalScale;
				half3 N = normalize(half3(dot(i.TtoW0.xyz, TN), dot(i.TtoW1.xyz, TN), dot(i.TtoW2.xyz, TN)));

				half occlusion = 1;

			#ifdef _TIRE_TRACK
			#endif

				half NoL = dot(N, L);
				half NoV = dot(N, V);
				half RoV = dot(normalize(reflect(-L, N)), V);

				half fFresnel = GetFresnel(NoV, _FresnelBias, _FresnelPower) * _UnRealFresnelScale;

			#ifdef _PLANAR_REFLECTION_ON
				half2 screenProjCoord = i.screenPos.xy / i.screenPos.w;
				half3 reflection = SAMPLE_TEXTURE2D(_MirrorReflectionTex, sampler_MirrorReflectionTex, screenProjCoord).rgb * _ReflectionIntensity;
			#else
				half3 reflNewst = reflect(-V, lerp(half3(0, 1, 0), N, _ReflectionBumpScale));
				half3 reflection = SAMPLE_TEXTURECUBE(_ReflectionCube, sampler_ReflectionCube, reflNewst).rgb * _ReflectionIntensity;
			#endif

				half3 lightMapCol = GetLM(NoL, i.texcoord1.xy, occlusion, mainLightColor);

				half3 SpecMaskCubemask = SAMPLE_TEXTURE2D(_SpecMaskCubemask, sampler_SpecMaskCubemask, i.texcoord.xy).rgb;
				half mask = saturate(SpecMaskCubemask.g * _Opacity);

				half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord.xy).rgb * i.color.rgb;
				half3 specular = mainLightColor * _SpecularColor.rgb * pow(max(0, RoV), _SpecularGloss) * SpecMaskCubemask.r * _SpecularIntensity;
				half specularmask = (specular.r + specular.g + specular.b) * 0.33;
				half4 col = half4(lightMapCol * albedo * _TopColor.rgb + specular, 1);
				col.rgb = lerp(col.rgb, reflection, fFresnel * SpecMaskCubemask.b);

				half3 binormal = half3(i.normal.w, i.tangent.w, i.color.a * 2 - 1);
				half3x3 rotation = half3x3(i.tangent.xyz, binormal, i.normal.xyz);
				half3 TV = normalize(mul(rotation, TransformWorldToObjectDir(UNnorV)));

			#ifdef _ICE_CRACKS
				float2 BaseUV = i.texcoord.xy + TN.xy * _Distortion;
				float2 NewUV = BaseUV;
				half2 OffsetUV = -TV.xy * 0.5;
				half2 DifUV = OffsetUV * _CracksHeight;
				half Move = 0.0;
				half Depth = 0.0;
				half DifLen = length(DifUV) / _CracksDepthStepSize;
				DifUV /= DifLen;

				Depth = SAMPLE_TEXTURE2D(_CracksTex, sampler_CracksTex, NewUV).r;
				half Distance = (_CracksWidth - Depth);
				Move = min(Distance, DifLen);
				DifLen -= Move;
				NewUV += DifUV * Move;

				Depth = SAMPLE_TEXTURE2D(_CracksTex, sampler_CracksTex, NewUV).r;
				Distance = (_CracksWidth - Depth);
				Move = min(Distance, DifLen);
				DifLen -= Move;
				NewUV += DifUV * Move;

				Depth = SAMPLE_TEXTURE2D(_CracksTex, sampler_CracksTex, NewUV).r;
				Distance = (_CracksWidth - Depth);
				Move = min(Distance, DifLen);
				DifLen -= Move;
				NewUV += DifUV * Move;

				half cracks = saturate(DifLen * _CracksDepthStepSize / max(length(NewUV - BaseUV), _CracksDepthScatterng));

				float2 DustBaseUV = i.texcoord.zw + TN.xy * _Distortion;
				half3 DustTex = half3(0, 0, 0);
				half3 Dust = half3(0, 0, 0);
				float2 DustUV = DustBaseUV - TV.xy * 0.5 * _DustHeight;
				DustTex = (DustTex + SAMPLE_TEXTURE2D(_DustTex, sampler_DustTex, DustUV + half2(_DustSecondNumStepU, _DustSecondNumStepV)).rgb) * _DustColor.rgb;
				DustUV = DustUV + (TV.xy * 0.5 * _DustHeight * 0.5);
				DustTex = (DustTex + SAMPLE_TEXTURE2D(_DustTex, sampler_DustTex, DustUV).rgb) * _DustColor.rgb;
				Dust = DustTex;

				half3 fog = lerp(_BottomColor.rgb * albedo, _CracksColor, cracks);
				fog += Dust;
				fog = lightMapCol * fog;
				col.rgb = lerp(fog, col.rgb, saturate(fFresnel + mask + specularmask));

			#elif _ICE_SUBSURFACE
				float2 DustBaseUV = i.texcoord.zw + TN.xy * _Distortion;
				half3 DustTex = half3(0, 0, 0);
				half3 Dust = half3(0, 0, 0);
				float2 DustUV = DustBaseUV - TV.xy * 0.5 * _DustHeight;
				DustTex = (DustTex + SAMPLE_TEXTURE2D(_DustTex, sampler_DustTex, DustUV + half2(_DustSecondNumStepU, _DustSecondNumStepV)).rgb) * _DustColor.rgb;
				DustUV = DustUV + (TV.xy * 0.5 * _DustHeight * 0.5);
				DustTex = (DustTex + SAMPLE_TEXTURE2D(_DustTex, sampler_DustTex, DustUV).rgb) * _DustColor.rgb;
				Dust = DustTex;

				half3 fogColor = _BottomColor.rgb * albedo;
				fogColor += Dust;
				fogColor = lightMapCol * fogColor;
				col.rgb = lerp(fogColor, col.rgb, saturate(fFresnel + mask + specularmask));

				half3 SubsurfaceColor = _SubColor;
				half3 OpacityMask = SAMPLE_TEXTURE2D(_TransmissionTex, sampler_TransmissionTex, i.texcoord1.zw).rgb;
				half OpacityVal = OpacityMask.r * _SubOpacity;
				half _TransmissionShadow = saturate((1 - OpacityMask.g) / max(0.01, _TransmissionShadowScale));
				half InScatter = pow(saturate(dot(L, -V)), 12) * lerp(3, 0.1, OpacityVal);
				half NormalContribution = saturate(RoV * OpacityVal + 1 - OpacityVal);
				half BackScatter = NormalContribution / (3.1415926 * 2);
				half3 Transmission = mainLightColor * lerp(BackScatter, 1, InScatter) * SubsurfaceColor * _TransmissionShadow;
				col.rgb += Transmission;
			#endif

				// Apply fog
				col.rgb = MixFog(col.rgb, i.fogFactor);

				return col;
			}

			ENDHLSL
		}

		// ------------------------------------------------------------------
		// ShadowCaster Pass
		// ------------------------------------------------------------------
		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			ZWrite On
			ZTest LEqual
			ColorMask 0

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			#pragma vertex ShadowPassVertex
			#pragma fragment ShadowPassFragment

			#pragma multi_compile_instancing

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
			ENDHLSL
		}

		// ------------------------------------------------------------------
		// AdditionalDirDepthOnly Pass (双主光阴影)
		// ------------------------------------------------------------------
		Pass
		{
			Name "AdditionalDirDepthOnly"
			Tags { "LightMode" = "AdditionalDirDepthOnly" }

			ZWrite On
			ColorMask 0

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			#pragma vertex DepthOnlyVertex
			#pragma fragment DepthOnlyFragment

			#pragma multi_compile_instancing

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
			ENDHLSL
		}

		// ------------------------------------------------------------------
		// DepthOnly Pass
		// ------------------------------------------------------------------
		Pass
		{
			Name "DepthOnly"
			Tags { "LightMode" = "DepthOnly" }

			ZWrite On
			ColorMask R

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			#pragma vertex DepthOnlyVertex
			#pragma fragment DepthOnlyFragment

			#pragma multi_compile_instancing

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
			ENDHLSL
		}

		// ------------------------------------------------------------------
		// DepthNormals Pass
		// ------------------------------------------------------------------
		Pass
		{
			Name "DepthNormals"
			Tags { "LightMode" = "DepthNormals" }

			ZWrite On

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			#pragma vertex DepthNormalsVertex
			#pragma fragment DepthNormalsFragment

			#pragma multi_compile_instancing

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"
			ENDHLSL
		}

		// ------------------------------------------------------------------
		// Meta Pass (for lightmapping)
		// ------------------------------------------------------------------
		Pass
		{
			Name "Meta"
			Tags { "LightMode" = "Meta" }

			Cull Off

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			#pragma vertex UniversalVertexMeta
			#pragma fragment UniversalFragmentMetaLit

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"
			ENDHLSL
		}
	}

	FallBack "Universal Render Pipeline/Lit"
}
