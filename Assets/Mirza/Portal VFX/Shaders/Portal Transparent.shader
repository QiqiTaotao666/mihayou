// Made with Amplify Shader Editor v1.9.6.3
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Portal Transparent"
{
	Properties
	{
		[HideInInspector] _EmissionColor("Emission Color", Color) = (1,1,1,1)
		[HideInInspector] _AlphaCutoff("Alpha Cutoff ", Range(0, 1)) = 0.5
		[HDR]_Colour("Colour", Color) = (1,1,1,1)
		_WaveCount("Wave Count", Range( 0 , 32)) = 0
		[HDR]_WaveColour("Wave Colour", Color) = (1,1,1,1)
		_WavePower("Wave Power", Float) = 1
		_WaveVertexOffset("Wave Vertex Offset", Float) = 0
		_WaveNormalStrength("Wave Normal Strength", Float) = 0
		Texture("Texture", 2D) = "white" {}
		[Toggle(_USETEXTURE_ON)] _UseTexture("Use Texture", Float) = 0
		[Toggle(_TEXTURESCREENUVS_ON)] _TextureScreenUVs("Texture Screen UVs", Float) = 0
		_TextureScale("Texture Scale", Float) = 1
		_TextureParallaxOffset("Texture Parallax Offset", Float) = 0
		_MaskRadius("Mask Radius", Range( 0 , 1)) = 0.9
		_MaskFeather("Mask Feather", Range( 0 , 1)) = 0
		_MaskPower("Mask Power", Float) = 1
		_AlphaClipThreshold("Alpha Clip Threshold", Range( 0 , 1)) = 0.5
		_NoiseScale("Noise Scale", Float) = 1
		_NoiseTiling("Noise Tiling", Vector) = (1,1,1,0)
		_NoiseAnimation("Noise Animation", Vector) = (0,0,0,0)
		_NoiseOffset("Noise Offset", Vector) = (0,0,0,0)
		_NoiseParallaxOffset("Noise Parallax Offset", Float) = 0
		[IntRange]_NoiseOctaves("Noise Octaves", Range( 0 , 5)) = 1
		_NoiseDilation("Noise Dilation", Range( 0 , 0.1)) = 0.01
		_NoisePower("Noise Power", Float) = 1
		_NoiseRemapFromMin("Noise Remap From Min", Range( 0 , 1)) = 0
		_NoiseRemapFromMax("Noise Remap From Max", Range( 0 , 1)) = 1
		_NoiseRemapToMin("Noise Remap To Min", Range( 0 , 1)) = 0
		_Alpha("Alpha", Range( 0 , 1)) = 1
		[IntRange]_BlurQuality("Blur Quality", Range( 1 , 12)) = 4
		_BlurRadius("Blur Radius", Range( 0 , 32)) = 8
		_DistortionNoise("Distortion Noise", Range( 0 , 0.1)) = 0.001
		_BlurNoisePower("Blur Noise Power", Float) = 0.1
		_BlurNoisePowerRemapMin("Blur Noise Power Remap Min", Range( 0 , 1)) = 0
		_BlurNoisePowerRemapMax("Blur Noise Power Remap Max", Range( 0 , 1)) = 1


		//_TessPhongStrength( "Tess Phong Strength", Range( 0, 1 ) ) = 0.5
		_TessValue( "Max Tessellation", Range( 1, 32 ) ) = 16
		//_TessMin( "Tess Min Distance", Float ) = 10
		//_TessMax( "Tess Max Distance", Float ) = 25
		//_TessEdgeLength ( "Tess Edge length", Range( 2, 50 ) ) = 16
		//_TessMaxDisp( "Tess Max Displacement", Float ) = 25

		[HideInInspector] _QueueOffset("_QueueOffset", Float) = 0
        [HideInInspector] _QueueControl("_QueueControl", Float) = -1

        [HideInInspector][NoScaleOffset] unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}

		[HideInInspector][ToggleOff] _ReceiveShadows("Receive Shadows", Float) = 1.0
	}

	SubShader
	{
		LOD 0

		

		Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" "UniversalMaterialType"="Unlit" }

		Cull Back
		AlphaToMask Off

		

		HLSLINCLUDE
		#pragma target 4.5
		#pragma prefer_hlslcc gles
		// ensure rendering platforms toggle list is visible

		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"

		#ifndef ASE_TESS_FUNCS
		#define ASE_TESS_FUNCS
		float4 FixedTess( float tessValue )
		{
			return tessValue;
		}

		float CalcDistanceTessFactor (float4 vertex, float minDist, float maxDist, float tess, float4x4 o2w, float3 cameraPos )
		{
			float3 wpos = mul(o2w,vertex).xyz;
			float dist = distance (wpos, cameraPos);
			float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
			return f;
		}

		float4 CalcTriEdgeTessFactors (float3 triVertexFactors)
		{
			float4 tess;
			tess.x = 0.5 * (triVertexFactors.y + triVertexFactors.z);
			tess.y = 0.5 * (triVertexFactors.x + triVertexFactors.z);
			tess.z = 0.5 * (triVertexFactors.x + triVertexFactors.y);
			tess.w = (triVertexFactors.x + triVertexFactors.y + triVertexFactors.z) / 3.0f;
			return tess;
		}

		float CalcEdgeTessFactor (float3 wpos0, float3 wpos1, float edgeLen, float3 cameraPos, float4 scParams )
		{
			float dist = distance (0.5 * (wpos0+wpos1), cameraPos);
			float len = distance(wpos0, wpos1);
			float f = max(len * scParams.y / (edgeLen * dist), 1.0);
			return f;
		}

		float DistanceFromPlane (float3 pos, float4 plane)
		{
			float d = dot (float4(pos,1.0f), plane);
			return d;
		}

		bool WorldViewFrustumCull (float3 wpos0, float3 wpos1, float3 wpos2, float cullEps, float4 planes[6] )
		{
			float4 planeTest;
			planeTest.x = (( DistanceFromPlane(wpos0, planes[0]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[0]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[0]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.y = (( DistanceFromPlane(wpos0, planes[1]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[1]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[1]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.z = (( DistanceFromPlane(wpos0, planes[2]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[2]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[2]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.w = (( DistanceFromPlane(wpos0, planes[3]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[3]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[3]) > -cullEps) ? 1.0f : 0.0f );
			return !all (planeTest);
		}

		float4 DistanceBasedTess( float4 v0, float4 v1, float4 v2, float tess, float minDist, float maxDist, float4x4 o2w, float3 cameraPos )
		{
			float3 f;
			f.x = CalcDistanceTessFactor (v0,minDist,maxDist,tess,o2w,cameraPos);
			f.y = CalcDistanceTessFactor (v1,minDist,maxDist,tess,o2w,cameraPos);
			f.z = CalcDistanceTessFactor (v2,minDist,maxDist,tess,o2w,cameraPos);

			return CalcTriEdgeTessFactors (f);
		}

		float4 EdgeLengthBasedTess( float4 v0, float4 v1, float4 v2, float edgeLength, float4x4 o2w, float3 cameraPos, float4 scParams )
		{
			float3 pos0 = mul(o2w,v0).xyz;
			float3 pos1 = mul(o2w,v1).xyz;
			float3 pos2 = mul(o2w,v2).xyz;
			float4 tess;
			tess.x = CalcEdgeTessFactor (pos1, pos2, edgeLength, cameraPos, scParams);
			tess.y = CalcEdgeTessFactor (pos2, pos0, edgeLength, cameraPos, scParams);
			tess.z = CalcEdgeTessFactor (pos0, pos1, edgeLength, cameraPos, scParams);
			tess.w = (tess.x + tess.y + tess.z) / 3.0f;
			return tess;
		}

		float4 EdgeLengthBasedTessCull( float4 v0, float4 v1, float4 v2, float edgeLength, float maxDisplacement, float4x4 o2w, float3 cameraPos, float4 scParams, float4 planes[6] )
		{
			float3 pos0 = mul(o2w,v0).xyz;
			float3 pos1 = mul(o2w,v1).xyz;
			float3 pos2 = mul(o2w,v2).xyz;
			float4 tess;

			if (WorldViewFrustumCull(pos0, pos1, pos2, maxDisplacement, planes))
			{
				tess = 0.0f;
			}
			else
			{
				tess.x = CalcEdgeTessFactor (pos1, pos2, edgeLength, cameraPos, scParams);
				tess.y = CalcEdgeTessFactor (pos2, pos0, edgeLength, cameraPos, scParams);
				tess.z = CalcEdgeTessFactor (pos0, pos1, edgeLength, cameraPos, scParams);
				tess.w = (tess.x + tess.y + tess.z) / 3.0f;
			}
			return tess;
		}
		#endif //ASE_TESS_FUNCS
		ENDHLSL

		
		Pass
		{
			
			Name "Forward"
			Tags { "LightMode"="UniversalForwardOnly" }

			Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
			ZWrite Off
			ZTest LEqual
			Offset 0 , 0
			ColorMask RGBA

			

			HLSLPROGRAM

			
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #define ASE_FOG 1
            #define ASE_FIXED_TESSELLATION
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_TESSELLATION 1
            #pragma require tessellation tessHW
            #pragma hull HullFunction
            #pragma domain DomainFunction
            #define _ALPHATEST_ON 1
            #define ASE_SRP_VERSION 140011
            #define ASE_USING_SAMPLING_MACROS 1


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
			#pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3

			
            #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS
		

			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
			#pragma multi_compile_fragment _ DEBUG_DISPLAY

			#pragma vertex vert
			#pragma fragment frag

			#define SHADERPASS SHADERPASS_UNLIT

			

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			

			
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#include "Portals.cginc"
			#include "../../VFXToolkit/Shaders/_Includes/Blur.cginc"
			#include "../../VFXToolkit/Shaders/_Includes/Noise.cginc"
			#define ASE_NEEDS_VERT_NORMAL
			#define ASE_NEEDS_FRAG_SCREEN_POSITION
			#define ASE_NEEDS_FRAG_WORLD_POSITION
			#pragma shader_feature_local _USETEXTURE_ON
			#pragma shader_feature_local _TEXTURESCREENUVS_ON


			struct VertexInput
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_tangent : TANGENT;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 positionCS : SV_POSITION;
				float4 clipPosV : TEXCOORD0;
				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					float3 positionWS : TEXCOORD1;
				#endif
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD2;
				#endif
				#ifdef ASE_FOG
					float fogFactor : TEXCOORD3;
				#endif
				float4 ase_texcoord4 : TEXCOORD4;
				float4 ase_texcoord5 : TEXCOORD5;
				float4 ase_texcoord6 : TEXCOORD6;
				float4 ase_texcoord7 : TEXCOORD7;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _CameraOpaqueTexture_TexelSize;
			float4 Texture_ST;
			float4 Texture_TexelSize;
			float4 _NoiseAnimation;
			float4 _NoiseOffset;
			float4 _Colour;
			float4 _WaveColour;
			float3 _NoiseTiling;
			float _MaskRadius;
			float _BlurNoisePowerRemapMin;
			float _MaskFeather;
			float _MaskPower;
			float _TextureScale;
			float _TextureParallaxOffset;
			float _BlurNoisePower;
			float _BlurNoisePowerRemapMax;
			float _BlurRadius;
			float _WaveCount;
			float _Alpha;
			float _WaveNormalStrength;
			float _DistortionNoise;
			float _NoiseRemapToMin;
			float _NoiseRemapFromMax;
			float _NoiseRemapFromMin;
			float _NoisePower;
			float _NoiseDilation;
			float _NoiseOctaves;
			float _NoiseScale;
			float _NoiseParallaxOffset;
			float _WaveVertexOffset;
			float _WavePower;
			float _BlurQuality;
			float _AlphaClipThreshold;
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			TEXTURE2D(_CameraOpaqueTexture);
			SAMPLER(sampler_CameraOpaqueTexture);
			TEXTURE2D(Texture);
			SAMPLER(samplerTexture);


			float3 PerturbNormal107_g76( float3 surf_pos, float3 surf_norm, float height, float scale )
			{
				// "Bump Mapping Unparametrized Surfaces on the GPU" by Morten S. Mikkelsen
				float3 vSigmaS = ddx( surf_pos );
				float3 vSigmaT = ddy( surf_pos );
				float3 vN = surf_norm;
				float3 vR1 = cross( vSigmaT , vN );
				float3 vR2 = cross( vN , vSigmaS );
				float fDet = dot( vSigmaS , vR1 );
				float dBs = ddx( height );
				float dBt = ddy( height );
				float3 vSurfGrad = scale * 0.05 * sign( fDet ) * ( dBs * vR1 + dBt * vR2 );
				return normalize ( abs( fDet ) * vN - vSurfGrad );
			}
			

			VertexOutput VertexFunction( VertexInput v  )
			{
				VertexOutput o = (VertexOutput)0;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float localWaves321 = ( 0.0 );
				float3 ase_worldPos = TransformObjectToWorld( (v.positionOS).xyz );
				float3 worldPosition321 = ase_worldPos;
				int count321 = (int)_WaveCount;
				float output321 = 0.0;
				Waves( worldPosition321 , count321 , output321 );
				float Waves330 = pow( output321 , _WavePower );
				float3 Wave_Vertex_Offset336 = ( Waves330 * _WaveVertexOffset * v.normalOS );
				
				float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
				o.ase_texcoord5.xyz = ase_worldTangent;
				float3 ase_worldNormal = TransformObjectToWorldNormal(v.normalOS);
				o.ase_texcoord6.xyz = ase_worldNormal;
				float ase_vertexTangentSign = v.ase_tangent.w * ( unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0 );
				float3 ase_worldBitangent = cross( ase_worldNormal, ase_worldTangent ) * ase_vertexTangentSign;
				o.ase_texcoord7.xyz = ase_worldBitangent;
				
				o.ase_texcoord4.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord4.zw = 0;
				o.ase_texcoord5.w = 0;
				o.ase_texcoord6.w = 0;
				o.ase_texcoord7.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = Wave_Vertex_Offset336;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.positionOS.xyz = vertexValue;
				#else
					v.positionOS.xyz += vertexValue;
				#endif

				v.normalOS = v.normalOS;

				VertexPositionInputs vertexInput = GetVertexPositionInputs( v.positionOS.xyz );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					o.positionWS = vertexInput.positionWS;
				#endif

				#ifdef ASE_FOG
					o.fogFactor = ComputeFogFactor( vertexInput.positionCS.z );
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					o.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				o.positionCS = vertexInput.positionCS;
				o.clipPosV = vertexInput.positionCS;
				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_tangent : TANGENT;

				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.positionOS;
				o.normalOS = v.normalOS;
				o.ase_texcoord = v.ase_texcoord;
				o.ase_tangent = v.ase_tangent;
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.positionOS = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
				o.ase_tangent = patch[0].ase_tangent * bary.x + patch[1].ase_tangent * bary.y + patch[2].ase_tangent * bary.z;
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.positionOS.xyz - patch[i].normalOS * (dot(o.positionOS.xyz, patch[i].normalOS) - dot(patch[i].vertex.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				o.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag ( VertexOutput IN
				#ifdef _WRITE_RENDERING_LAYERS
				, out float4 outRenderingLayers : SV_Target1
				#endif
				 ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID( IN );
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( IN );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					float3 WorldPosition = IN.positionWS;
				#endif

				float4 ShadowCoords = float4( 0, 0, 0, 0 );

				float4 ClipPos = IN.clipPosV;
				float4 ScreenPos = ComputeScreenPos( IN.clipPosV );

				#if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = IN.shadowCoord;
					#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
					#endif
				#endif

				float localGaussianBlur_float1_g55 = ( 0.0 );
				texture2D tex1_g55 =(texture2D)_CameraOpaqueTexture;
				float4 ase_screenPosNorm = ScreenPos / ScreenPos.w;
				ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
				float localSimplexNoise_Caustics_float2_g70 = ( 0.0 );
				float3 ase_worldTangent = IN.ase_texcoord5.xyz;
				float3 ase_worldNormal = IN.ase_texcoord6.xyz;
				float3 ase_worldBitangent = IN.ase_texcoord7.xyz;
				float3 tanToWorld0 = float3( ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x );
				float3 tanToWorld1 = float3( ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y );
				float3 tanToWorld2 = float3( ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z );
				float3 ase_worldViewDir = ( _WorldSpaceCameraPos.xyz - WorldPosition );
				ase_worldViewDir = normalize(ase_worldViewDir);
				float3 ase_tanViewDir =  tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y  + tanToWorld2 * ase_worldViewDir.z;
				ase_tanViewDir = normalize(ase_tanViewDir);
				float3x3 ase_worldToTangent = float3x3(ase_worldTangent,ase_worldBitangent,ase_worldNormal);
				float3 worldToTangentDir18_g71 = mul( ase_worldToTangent, ase_worldNormal);
				float dotResult15_g71 = dot( ase_tanViewDir , worldToTangentDir18_g71 );
				float2 texCoord35 = IN.ase_texcoord4.xy * float2( 1,1 ) + ( -( ase_tanViewDir / dotResult15_g71 ) * _NoiseParallaxOffset ).xy;
				float4 temp_output_10_0_g68 = ( float4( ( float3( texCoord35 ,  0.0 ) * _NoiseScale * _NoiseTiling ) , 0.0 ) - ( _NoiseOffset + ( _NoiseAnimation * _TimeParameters.x ) ) );
				float3 position2_g70 = (temp_output_10_0_g68).xyz;
				float angle2_g70 = (temp_output_10_0_g68).w;
				float octaves2_g70 = _NoiseOctaves;
				float gradientStrength2_g70 = _NoiseDilation;
				float noise2_g70 = 0.0;
				float3 gradient2_g70 = float3( 0,0,0 );
				SimplexNoise_Caustics_float( position2_g70 , angle2_g70 , octaves2_g70 , gradientStrength2_g70 , noise2_g70 , gradient2_g70 );
				float3 temp_output_51_3 = gradient2_g70;
				float3 temp_cast_4 = (_NoisePower).xxx;
				float3 temp_cast_5 = (_NoiseRemapFromMin).xxx;
				float3 temp_cast_6 = (_NoiseRemapFromMax).xxx;
				float3 temp_cast_7 = (_NoiseRemapToMin).xxx;
				float3 Noise_Gradient129 = ( (temp_cast_7 + (pow( abs( temp_output_51_3 ) , temp_cast_4 ) - temp_cast_5) * (float3( 1,1,1 ) - temp_cast_7) / (temp_cast_6 - temp_cast_5)) * sign( temp_output_51_3 ) );
				float Noise_Depth_Fade306 = 1.0;
				float3 UV_Distortion228 = ( Noise_Gradient129 * _DistortionNoise * Noise_Depth_Fade306 );
				float3 surf_pos107_g76 = WorldPosition;
				float3 surf_norm107_g76 = ase_worldNormal;
				float localWaves321 = ( 0.0 );
				float3 worldPosition321 = WorldPosition;
				int count321 = (int)_WaveCount;
				float output321 = 0.0;
				Waves( worldPosition321 , count321 , output321 );
				float Waves330 = pow( output321 , _WavePower );
				float height107_g76 = Waves330;
				float scale107_g76 = _WaveNormalStrength;
				float3 localPerturbNormal107_g76 = PerturbNormal107_g76( surf_pos107_g76 , surf_norm107_g76 , height107_g76 , scale107_g76 );
				float3 worldToTangentDir42_g76 = mul( ase_worldToTangent, localPerturbNormal107_g76);
				float3 Wave_Normals357 = worldToTangentDir42_g76;
				float4 Scene_UV127 = ( ase_screenPosNorm + float4( UV_Distortion228 , 0.0 ) + float4( Wave_Normals357 , 0.0 ) );
				float2 uv1_g55 = Scene_UV127.xy;
				float2 appendResult125 = (float2(_CameraOpaqueTexture_TexelSize.x , _CameraOpaqueTexture_TexelSize.y));
				float2 texelSize1_g55 = appendResult125;
				SamplerState samplerState1_g55 = sampler_CameraOpaqueTexture;
				float blurQuality1_g55 = _BlurQuality;
				float Noise39 = (_NoiseRemapToMin + (pow( noise2_g70 , _NoisePower ) - _NoiseRemapFromMin) * (1.0 - _NoiseRemapToMin) / (_NoiseRemapFromMax - _NoiseRemapFromMin));
				float smoothstepResult22_g54 = smoothstep( _BlurNoisePowerRemapMin , _BlurNoisePowerRemapMax , pow( Noise39 , _BlurNoisePower ));
				float temp_output_146_0 = ( _BlurRadius * smoothstepResult22_g54 * Noise_Depth_Fade306 );
				float2 temp_cast_12 = (temp_output_146_0).xx;
				float2 blurRadiusXY1_g55 = temp_cast_12;
				float4 output1_g55 = float4( 0,0,0,0 );
				GaussianBlur_float( tex1_g55 , uv1_g55 , texelSize1_g55 , samplerState1_g55 , blurQuality1_g55 , blurRadiusXY1_g55 , output1_g55 );
				float3 Blurred_Camera_Texture123 = (output1_g55).xyz;
				float localGaussianBlur_float1_g57 = ( 0.0 );
				texture2D tex1_g57 =(texture2D)Texture;
				float2 texCoord216 = IN.ase_texcoord4.xy * float2( 1,1 ) + float2( 0,0 );
				float3 worldToTangentDir18_g53 = mul( ase_worldToTangent, ase_worldNormal);
				float dotResult15_g53 = dot( ase_tanViewDir , worldToTangentDir18_g53 );
				float2 Parallax_Offset231 = (( -( ase_tanViewDir / dotResult15_g53 ) * _TextureParallaxOffset )).xy;
				#ifdef _TEXTURESCREENUVS_ON
				float4 staticSwitch362 = ase_screenPosNorm;
				#else
				float4 staticSwitch362 = float4( ( texCoord216 + Parallax_Offset231 ), 0.0 , 0.0 );
				#endif
				float2 temp_output_222_0 = ( _TextureScale * Texture_ST.xy );
				float4 Texture_UV213 = ( ( staticSwitch362 * float4( temp_output_222_0, 0.0 , 0.0 ) ) + float4( ( ( 1.0 - temp_output_222_0 ) / float2( 2,2 ) ), 0.0 , 0.0 ) + float4( Texture_ST.zw, 0.0 , 0.0 ) + float4( UV_Distortion228 , 0.0 ) + float4( Wave_Normals357 , 0.0 ) );
				float2 uv1_g57 = Texture_UV213.xy;
				float2 appendResult241 = (float2(Texture_TexelSize.x , Texture_TexelSize.y));
				float2 texelSize1_g57 = appendResult241;
				SamplerState samplerState1_g57 = samplerTexture;
				float blurQuality1_g57 = _BlurQuality;
				float2 temp_cast_20 = (temp_output_146_0).xx;
				float2 blurRadiusXY1_g57 = temp_cast_20;
				float4 output1_g57 = float4( 0,0,0,0 );
				GaussianBlur_float( tex1_g57 , uv1_g57 , texelSize1_g57 , samplerState1_g57 , blurQuality1_g57 , blurRadiusXY1_g57 , output1_g57 );
				float3 Blurred_Texture237 = (output1_g57).xyz;
				#ifdef _USETEXTURE_ON
				float3 staticSwitch280 = Blurred_Texture237;
				#else
				float3 staticSwitch280 = Blurred_Camera_Texture123;
				#endif
				float4 temp_output_22_0_g62 = _Colour;
				float3 Selected_Blurred_Texture278 = ( staticSwitch280 * ( (temp_output_22_0_g62).rgb * (temp_output_22_0_g62).a ) );
				float3 lerpResult322 = lerp( Selected_Blurred_Texture278 , _WaveColour.rgb , ( _WaveColour.a * Waves330 ));
				float3 Colour326 = lerpResult322;
				
				float2 texCoord11_g26 = IN.ase_texcoord4.xy * float2( 2,2 ) + float2( -1,-1 );
				float temp_output_7_0_g26 = ( 1.0 - length( texCoord11_g26 ) );
				float temp_output_6_0_g26 = ( 1.0 - _MaskRadius );
				float temp_output_1_0_g28 = temp_output_6_0_g26;
				float lerpResult5_g26 = lerp( temp_output_6_0_g26 , 1.0 , _MaskFeather);
				float smoothstepResult22_g29 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g26 - temp_output_1_0_g28 ) / ( lerpResult5_g26 - temp_output_1_0_g28 ) ) ) , _MaskPower ));
				float Mask22 = smoothstepResult22_g29;
				float Alpha77 = ( Mask22 * _Alpha );
				
				float3 BakedAlbedo = 0;
				float3 BakedEmission = 0;
				float3 Color = Colour326;
				float Alpha = Alpha77;
				float AlphaClipThreshold = _AlphaClipThreshold;
				float AlphaClipThresholdShadow = 0.5;

				#ifdef _ALPHATEST_ON
					clip( Alpha - AlphaClipThreshold );
				#endif

				#if defined(_DBUFFER)
					ApplyDecalToBaseColor(IN.positionCS, Color);
				#endif

				#ifdef LOD_FADE_CROSSFADE
					LODFadeCrossFade( IN.positionCS );
				#endif

				#ifdef ASE_FOG
					Color = MixFog( Color, IN.fogFactor );
				#endif

				#ifdef _WRITE_RENDERING_LAYERS
					uint renderingLayers = GetMeshRenderingLayer();
					outRenderingLayers = float4( EncodeMeshRenderingLayer( renderingLayers ), 0, 0, 0 );
				#endif

				return half4( Color, Alpha );
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "ShadowCaster"
			Tags { "LightMode"="ShadowCaster" }

			ZWrite On
			ZTest LEqual
			AlphaToMask Off
			ColorMask 0

			HLSLPROGRAM

			
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #define ASE_FOG 1
            #define ASE_FIXED_TESSELLATION
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_TESSELLATION 1
            #pragma require tessellation tessHW
            #pragma hull HullFunction
            #pragma domain DomainFunction
            #define _ALPHATEST_ON 1
            #define ASE_SRP_VERSION 140011
            #define ASE_USING_SAMPLING_MACROS 1


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

			#pragma vertex vert
			#pragma fragment frag

			#define SHADERPASS SHADERPASS_SHADOWCASTER

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#include "Portals.cginc"
			#define ASE_NEEDS_VERT_NORMAL


			struct VertexInput
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 positionCS : SV_POSITION;
				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					float3 positionWS : TEXCOORD0;
				#endif
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD1;
				#endif
				float4 ase_texcoord2 : TEXCOORD2;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _CameraOpaqueTexture_TexelSize;
			float4 Texture_ST;
			float4 Texture_TexelSize;
			float4 _NoiseAnimation;
			float4 _NoiseOffset;
			float4 _Colour;
			float4 _WaveColour;
			float3 _NoiseTiling;
			float _MaskRadius;
			float _BlurNoisePowerRemapMin;
			float _MaskFeather;
			float _MaskPower;
			float _TextureScale;
			float _TextureParallaxOffset;
			float _BlurNoisePower;
			float _BlurNoisePowerRemapMax;
			float _BlurRadius;
			float _WaveCount;
			float _Alpha;
			float _WaveNormalStrength;
			float _DistortionNoise;
			float _NoiseRemapToMin;
			float _NoiseRemapFromMax;
			float _NoiseRemapFromMin;
			float _NoisePower;
			float _NoiseDilation;
			float _NoiseOctaves;
			float _NoiseScale;
			float _NoiseParallaxOffset;
			float _WaveVertexOffset;
			float _WavePower;
			float _BlurQuality;
			float _AlphaClipThreshold;
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			

			
			float3 _LightDirection;
			float3 _LightPosition;

			VertexOutput VertexFunction( VertexInput v )
			{
				VertexOutput o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );

				float localWaves321 = ( 0.0 );
				float3 ase_worldPos = TransformObjectToWorld( (v.positionOS).xyz );
				float3 worldPosition321 = ase_worldPos;
				int count321 = (int)_WaveCount;
				float output321 = 0.0;
				Waves( worldPosition321 , count321 , output321 );
				float Waves330 = pow( output321 , _WavePower );
				float3 Wave_Vertex_Offset336 = ( Waves330 * _WaveVertexOffset * v.normalOS );
				
				o.ase_texcoord2.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord2.zw = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = Wave_Vertex_Offset336;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.positionOS.xyz = vertexValue;
				#else
					v.positionOS.xyz += vertexValue;
				#endif

				v.normalOS = v.normalOS;

				float3 positionWS = TransformObjectToWorld( v.positionOS.xyz );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					o.positionWS = positionWS;
				#endif

				float3 normalWS = TransformObjectToWorldDir( v.normalOS );

				#if _CASTING_PUNCTUAL_LIGHT_SHADOW
					float3 lightDirectionWS = normalize(_LightPosition - positionWS);
				#else
					float3 lightDirectionWS = _LightDirection;
				#endif

				float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

				#if UNITY_REVERSED_Z
					positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
				#else
					positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = positionCS;
					o.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				o.positionCS = positionCS;

				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;

				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.positionOS;
				o.normalOS = v.normalOS;
				o.ase_texcoord = v.ase_texcoord;
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.positionOS = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.positionOS.xyz - patch[i].normalOS * (dot(o.positionOS.xyz, patch[i].normalOS) - dot(patch[i].vertex.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				o.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag(VertexOutput IN  ) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID( IN );
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( IN );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					float3 WorldPosition = IN.positionWS;
				#endif

				float4 ShadowCoords = float4( 0, 0, 0, 0 );

				#if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = IN.shadowCoord;
					#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
					#endif
				#endif

				float2 texCoord11_g26 = IN.ase_texcoord2.xy * float2( 2,2 ) + float2( -1,-1 );
				float temp_output_7_0_g26 = ( 1.0 - length( texCoord11_g26 ) );
				float temp_output_6_0_g26 = ( 1.0 - _MaskRadius );
				float temp_output_1_0_g28 = temp_output_6_0_g26;
				float lerpResult5_g26 = lerp( temp_output_6_0_g26 , 1.0 , _MaskFeather);
				float smoothstepResult22_g29 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g26 - temp_output_1_0_g28 ) / ( lerpResult5_g26 - temp_output_1_0_g28 ) ) ) , _MaskPower ));
				float Mask22 = smoothstepResult22_g29;
				float Alpha77 = ( Mask22 * _Alpha );
				

				float Alpha = Alpha77;
				float AlphaClipThreshold = _AlphaClipThreshold;
				float AlphaClipThresholdShadow = 0.5;

				#ifdef _ALPHATEST_ON
					#ifdef _ALPHATEST_SHADOW_ON
						clip(Alpha - AlphaClipThresholdShadow);
					#else
						clip(Alpha - AlphaClipThreshold);
					#endif
				#endif

				#ifdef LOD_FADE_CROSSFADE
					LODFadeCrossFade( IN.positionCS );
				#endif

				return 0;
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "DepthOnly"
			Tags { "LightMode"="DepthOnly" }

			ZWrite On
			ColorMask R
			AlphaToMask Off

			HLSLPROGRAM

			
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #define ASE_FOG 1
            #define ASE_FIXED_TESSELLATION
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_TESSELLATION 1
            #pragma require tessellation tessHW
            #pragma hull HullFunction
            #pragma domain DomainFunction
            #define _ALPHATEST_ON 1
            #define ASE_SRP_VERSION 140011
            #define ASE_USING_SAMPLING_MACROS 1


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma vertex vert
			#pragma fragment frag

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#include "Portals.cginc"
			#define ASE_NEEDS_VERT_NORMAL


			struct VertexInput
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 positionCS : SV_POSITION;
				float4 clipPosV : TEXCOORD0;
				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
				float3 positionWS : TEXCOORD1;
				#endif
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
				float4 shadowCoord : TEXCOORD2;
				#endif
				float4 ase_texcoord3 : TEXCOORD3;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _CameraOpaqueTexture_TexelSize;
			float4 Texture_ST;
			float4 Texture_TexelSize;
			float4 _NoiseAnimation;
			float4 _NoiseOffset;
			float4 _Colour;
			float4 _WaveColour;
			float3 _NoiseTiling;
			float _MaskRadius;
			float _BlurNoisePowerRemapMin;
			float _MaskFeather;
			float _MaskPower;
			float _TextureScale;
			float _TextureParallaxOffset;
			float _BlurNoisePower;
			float _BlurNoisePowerRemapMax;
			float _BlurRadius;
			float _WaveCount;
			float _Alpha;
			float _WaveNormalStrength;
			float _DistortionNoise;
			float _NoiseRemapToMin;
			float _NoiseRemapFromMax;
			float _NoiseRemapFromMin;
			float _NoisePower;
			float _NoiseDilation;
			float _NoiseOctaves;
			float _NoiseScale;
			float _NoiseParallaxOffset;
			float _WaveVertexOffset;
			float _WavePower;
			float _BlurQuality;
			float _AlphaClipThreshold;
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			

			
			VertexOutput VertexFunction( VertexInput v  )
			{
				VertexOutput o = (VertexOutput)0;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float localWaves321 = ( 0.0 );
				float3 ase_worldPos = TransformObjectToWorld( (v.positionOS).xyz );
				float3 worldPosition321 = ase_worldPos;
				int count321 = (int)_WaveCount;
				float output321 = 0.0;
				Waves( worldPosition321 , count321 , output321 );
				float Waves330 = pow( output321 , _WavePower );
				float3 Wave_Vertex_Offset336 = ( Waves330 * _WaveVertexOffset * v.normalOS );
				
				o.ase_texcoord3.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord3.zw = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = Wave_Vertex_Offset336;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.positionOS.xyz = vertexValue;
				#else
					v.positionOS.xyz += vertexValue;
				#endif

				v.normalOS = v.normalOS;

				VertexPositionInputs vertexInput = GetVertexPositionInputs( v.positionOS.xyz );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					o.positionWS = vertexInput.positionWS;
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					o.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				o.positionCS = vertexInput.positionCS;
				o.clipPosV = vertexInput.positionCS;
				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;

				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.positionOS;
				o.normalOS = v.normalOS;
				o.ase_texcoord = v.ase_texcoord;
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.positionOS = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.positionOS.xyz - patch[i].normalOS * (dot(o.positionOS.xyz, patch[i].normalOS) - dot(patch[i].vertex.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				o.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag(VertexOutput IN  ) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(IN);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( IN );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
				float3 WorldPosition = IN.positionWS;
				#endif

				float4 ShadowCoords = float4( 0, 0, 0, 0 );

				float4 ClipPos = IN.clipPosV;
				float4 ScreenPos = ComputeScreenPos( IN.clipPosV );

				#if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = IN.shadowCoord;
					#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
					#endif
				#endif

				float2 texCoord11_g26 = IN.ase_texcoord3.xy * float2( 2,2 ) + float2( -1,-1 );
				float temp_output_7_0_g26 = ( 1.0 - length( texCoord11_g26 ) );
				float temp_output_6_0_g26 = ( 1.0 - _MaskRadius );
				float temp_output_1_0_g28 = temp_output_6_0_g26;
				float lerpResult5_g26 = lerp( temp_output_6_0_g26 , 1.0 , _MaskFeather);
				float smoothstepResult22_g29 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g26 - temp_output_1_0_g28 ) / ( lerpResult5_g26 - temp_output_1_0_g28 ) ) ) , _MaskPower ));
				float Mask22 = smoothstepResult22_g29;
				float Alpha77 = ( Mask22 * _Alpha );
				

				float Alpha = Alpha77;
				float AlphaClipThreshold = _AlphaClipThreshold;

				#ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
				#endif

				#ifdef LOD_FADE_CROSSFADE
					LODFadeCrossFade( IN.positionCS );
				#endif
				return 0;
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "SceneSelectionPass"
			Tags { "LightMode"="SceneSelectionPass" }

			Cull Off
			AlphaToMask Off

			HLSLPROGRAM

			
            #define ASE_FOG 1
            #define ASE_FIXED_TESSELLATION
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_TESSELLATION 1
            #pragma require tessellation tessHW
            #pragma hull HullFunction
            #pragma domain DomainFunction
            #define _ALPHATEST_ON 1
            #define ASE_SRP_VERSION 140011
            #define ASE_USING_SAMPLING_MACROS 1


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma vertex vert
			#pragma fragment frag

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT
			#define SHADERPASS SHADERPASS_DEPTHONLY

			

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			

			
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#include "Portals.cginc"
			#define ASE_NEEDS_VERT_NORMAL


			struct VertexInput
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 positionCS : SV_POSITION;
				float4 ase_texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _CameraOpaqueTexture_TexelSize;
			float4 Texture_ST;
			float4 Texture_TexelSize;
			float4 _NoiseAnimation;
			float4 _NoiseOffset;
			float4 _Colour;
			float4 _WaveColour;
			float3 _NoiseTiling;
			float _MaskRadius;
			float _BlurNoisePowerRemapMin;
			float _MaskFeather;
			float _MaskPower;
			float _TextureScale;
			float _TextureParallaxOffset;
			float _BlurNoisePower;
			float _BlurNoisePowerRemapMax;
			float _BlurRadius;
			float _WaveCount;
			float _Alpha;
			float _WaveNormalStrength;
			float _DistortionNoise;
			float _NoiseRemapToMin;
			float _NoiseRemapFromMax;
			float _NoiseRemapFromMin;
			float _NoisePower;
			float _NoiseDilation;
			float _NoiseOctaves;
			float _NoiseScale;
			float _NoiseParallaxOffset;
			float _WaveVertexOffset;
			float _WavePower;
			float _BlurQuality;
			float _AlphaClipThreshold;
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			

			
			int _ObjectId;
			int _PassValue;

			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			VertexOutput VertexFunction(VertexInput v  )
			{
				VertexOutput o;
				ZERO_INITIALIZE(VertexOutput, o);

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float localWaves321 = ( 0.0 );
				float3 ase_worldPos = TransformObjectToWorld( (v.positionOS).xyz );
				float3 worldPosition321 = ase_worldPos;
				int count321 = (int)_WaveCount;
				float output321 = 0.0;
				Waves( worldPosition321 , count321 , output321 );
				float Waves330 = pow( output321 , _WavePower );
				float3 Wave_Vertex_Offset336 = ( Waves330 * _WaveVertexOffset * v.normalOS );
				
				o.ase_texcoord.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord.zw = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = Wave_Vertex_Offset336;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.positionOS.xyz = vertexValue;
				#else
					v.positionOS.xyz += vertexValue;
				#endif

				v.normalOS = v.normalOS;

				float3 positionWS = TransformObjectToWorld( v.positionOS.xyz );

				o.positionCS = TransformWorldToHClip(positionWS);

				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;

				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.positionOS;
				o.normalOS = v.normalOS;
				o.ase_texcoord = v.ase_texcoord;
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.positionOS = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.positionOS.xyz - patch[i].normalOS * (dot(o.positionOS.xyz, patch[i].normalOS) - dot(patch[i].vertex.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				o.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag(VertexOutput IN ) : SV_TARGET
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				float2 texCoord11_g26 = IN.ase_texcoord.xy * float2( 2,2 ) + float2( -1,-1 );
				float temp_output_7_0_g26 = ( 1.0 - length( texCoord11_g26 ) );
				float temp_output_6_0_g26 = ( 1.0 - _MaskRadius );
				float temp_output_1_0_g28 = temp_output_6_0_g26;
				float lerpResult5_g26 = lerp( temp_output_6_0_g26 , 1.0 , _MaskFeather);
				float smoothstepResult22_g29 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g26 - temp_output_1_0_g28 ) / ( lerpResult5_g26 - temp_output_1_0_g28 ) ) ) , _MaskPower ));
				float Mask22 = smoothstepResult22_g29;
				float Alpha77 = ( Mask22 * _Alpha );
				

				surfaceDescription.Alpha = Alpha77;
				surfaceDescription.AlphaClipThreshold = _AlphaClipThreshold;

				#if _ALPHATEST_ON
					float alphaClipThreshold = 0.01f;
					#if ALPHA_CLIP_THRESHOLD
						alphaClipThreshold = surfaceDescription.AlphaClipThreshold;
					#endif
					clip(surfaceDescription.Alpha - alphaClipThreshold);
				#endif

				half4 outColor = half4(_ObjectId, _PassValue, 1.0, 1.0);
				return outColor;
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "ScenePickingPass"
			Tags { "LightMode"="Picking" }

			AlphaToMask Off

			HLSLPROGRAM

			
            #define ASE_FOG 1
            #define ASE_FIXED_TESSELLATION
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_TESSELLATION 1
            #pragma require tessellation tessHW
            #pragma hull HullFunction
            #pragma domain DomainFunction
            #define _ALPHATEST_ON 1
            #define ASE_SRP_VERSION 140011
            #define ASE_USING_SAMPLING_MACROS 1


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma vertex vert
			#pragma fragment frag

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT

			#define SHADERPASS SHADERPASS_DEPTHONLY

			

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			

			
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#include "Portals.cginc"
			#define ASE_NEEDS_VERT_NORMAL


			struct VertexInput
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 positionCS : SV_POSITION;
				float4 ase_texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _CameraOpaqueTexture_TexelSize;
			float4 Texture_ST;
			float4 Texture_TexelSize;
			float4 _NoiseAnimation;
			float4 _NoiseOffset;
			float4 _Colour;
			float4 _WaveColour;
			float3 _NoiseTiling;
			float _MaskRadius;
			float _BlurNoisePowerRemapMin;
			float _MaskFeather;
			float _MaskPower;
			float _TextureScale;
			float _TextureParallaxOffset;
			float _BlurNoisePower;
			float _BlurNoisePowerRemapMax;
			float _BlurRadius;
			float _WaveCount;
			float _Alpha;
			float _WaveNormalStrength;
			float _DistortionNoise;
			float _NoiseRemapToMin;
			float _NoiseRemapFromMax;
			float _NoiseRemapFromMin;
			float _NoisePower;
			float _NoiseDilation;
			float _NoiseOctaves;
			float _NoiseScale;
			float _NoiseParallaxOffset;
			float _WaveVertexOffset;
			float _WavePower;
			float _BlurQuality;
			float _AlphaClipThreshold;
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			

			
			float4 _SelectionID;

			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			VertexOutput VertexFunction(VertexInput v  )
			{
				VertexOutput o;
				ZERO_INITIALIZE(VertexOutput, o);

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float localWaves321 = ( 0.0 );
				float3 ase_worldPos = TransformObjectToWorld( (v.positionOS).xyz );
				float3 worldPosition321 = ase_worldPos;
				int count321 = (int)_WaveCount;
				float output321 = 0.0;
				Waves( worldPosition321 , count321 , output321 );
				float Waves330 = pow( output321 , _WavePower );
				float3 Wave_Vertex_Offset336 = ( Waves330 * _WaveVertexOffset * v.normalOS );
				
				o.ase_texcoord.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord.zw = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = Wave_Vertex_Offset336;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.positionOS.xyz = vertexValue;
				#else
					v.positionOS.xyz += vertexValue;
				#endif

				v.normalOS = v.normalOS;

				float3 positionWS = TransformObjectToWorld( v.positionOS.xyz );
				o.positionCS = TransformWorldToHClip(positionWS);
				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;

				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.positionOS;
				o.normalOS = v.normalOS;
				o.ase_texcoord = v.ase_texcoord;
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.positionOS = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.positionOS.xyz - patch[i].normalOS * (dot(o.positionOS.xyz, patch[i].normalOS) - dot(patch[i].vertex.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				o.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag(VertexOutput IN ) : SV_TARGET
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				float2 texCoord11_g26 = IN.ase_texcoord.xy * float2( 2,2 ) + float2( -1,-1 );
				float temp_output_7_0_g26 = ( 1.0 - length( texCoord11_g26 ) );
				float temp_output_6_0_g26 = ( 1.0 - _MaskRadius );
				float temp_output_1_0_g28 = temp_output_6_0_g26;
				float lerpResult5_g26 = lerp( temp_output_6_0_g26 , 1.0 , _MaskFeather);
				float smoothstepResult22_g29 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g26 - temp_output_1_0_g28 ) / ( lerpResult5_g26 - temp_output_1_0_g28 ) ) ) , _MaskPower ));
				float Mask22 = smoothstepResult22_g29;
				float Alpha77 = ( Mask22 * _Alpha );
				

				surfaceDescription.Alpha = Alpha77;
				surfaceDescription.AlphaClipThreshold = _AlphaClipThreshold;

				#if _ALPHATEST_ON
					float alphaClipThreshold = 0.01f;
					#if ALPHA_CLIP_THRESHOLD
						alphaClipThreshold = surfaceDescription.AlphaClipThreshold;
					#endif
					clip(surfaceDescription.Alpha - alphaClipThreshold);
				#endif

				half4 outColor = 0;
				outColor = _SelectionID;

				return outColor;
			}

			ENDHLSL
		}

		
		Pass
		{
			
			Name "DepthNormals"
			Tags { "LightMode"="DepthNormalsOnly" }

			ZTest LEqual
			ZWrite On

			HLSLPROGRAM

			
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #define ASE_FOG 1
            #define ASE_FIXED_TESSELLATION
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_TESSELLATION 1
            #pragma require tessellation tessHW
            #pragma hull HullFunction
            #pragma domain DomainFunction
            #define _ALPHATEST_ON 1
            #define ASE_SRP_VERSION 140011
            #define ASE_USING_SAMPLING_MACROS 1


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

        	#pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

			
            #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS
		

			#pragma vertex vert
			#pragma fragment frag

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT
			#define VARYINGS_NEED_NORMAL_WS

			#define SHADERPASS SHADERPASS_DEPTHNORMALSONLY

			

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			

			
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#include "Portals.cginc"
			#define ASE_NEEDS_VERT_NORMAL


			struct VertexInput
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 positionCS : SV_POSITION;
				float4 clipPosV : TEXCOORD0;
				float3 normalWS : TEXCOORD1;
				float4 ase_texcoord2 : TEXCOORD2;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _CameraOpaqueTexture_TexelSize;
			float4 Texture_ST;
			float4 Texture_TexelSize;
			float4 _NoiseAnimation;
			float4 _NoiseOffset;
			float4 _Colour;
			float4 _WaveColour;
			float3 _NoiseTiling;
			float _MaskRadius;
			float _BlurNoisePowerRemapMin;
			float _MaskFeather;
			float _MaskPower;
			float _TextureScale;
			float _TextureParallaxOffset;
			float _BlurNoisePower;
			float _BlurNoisePowerRemapMax;
			float _BlurRadius;
			float _WaveCount;
			float _Alpha;
			float _WaveNormalStrength;
			float _DistortionNoise;
			float _NoiseRemapToMin;
			float _NoiseRemapFromMax;
			float _NoiseRemapFromMin;
			float _NoisePower;
			float _NoiseDilation;
			float _NoiseOctaves;
			float _NoiseScale;
			float _NoiseParallaxOffset;
			float _WaveVertexOffset;
			float _WavePower;
			float _BlurQuality;
			float _AlphaClipThreshold;
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			

			
			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			VertexOutput VertexFunction(VertexInput v  )
			{
				VertexOutput o;
				ZERO_INITIALIZE(VertexOutput, o);

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float localWaves321 = ( 0.0 );
				float3 ase_worldPos = TransformObjectToWorld( (v.positionOS).xyz );
				float3 worldPosition321 = ase_worldPos;
				int count321 = (int)_WaveCount;
				float output321 = 0.0;
				Waves( worldPosition321 , count321 , output321 );
				float Waves330 = pow( output321 , _WavePower );
				float3 Wave_Vertex_Offset336 = ( Waves330 * _WaveVertexOffset * v.normalOS );
				
				o.ase_texcoord2.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord2.zw = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = Wave_Vertex_Offset336;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.positionOS.xyz = vertexValue;
				#else
					v.positionOS.xyz += vertexValue;
				#endif

				v.normalOS = v.normalOS;

				VertexPositionInputs vertexInput = GetVertexPositionInputs( v.positionOS.xyz );

				o.positionCS = vertexInput.positionCS;
				o.clipPosV = vertexInput.positionCS;
				o.normalWS = TransformObjectToWorldNormal( v.normalOS );
				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;

				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.positionOS;
				o.normalOS = v.normalOS;
				o.ase_texcoord = v.ase_texcoord;
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.positionOS = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.positionOS.xyz - patch[i].normalOS * (dot(o.positionOS.xyz, patch[i].normalOS) - dot(patch[i].vertex.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				o.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			void frag( VertexOutput IN
				, out half4 outNormalWS : SV_Target0
			#ifdef _WRITE_RENDERING_LAYERS
				, out float4 outRenderingLayers : SV_Target1
			#endif
				 )
			{
				float4 ClipPos = IN.clipPosV;
				float4 ScreenPos = ComputeScreenPos( IN.clipPosV );

				float2 texCoord11_g26 = IN.ase_texcoord2.xy * float2( 2,2 ) + float2( -1,-1 );
				float temp_output_7_0_g26 = ( 1.0 - length( texCoord11_g26 ) );
				float temp_output_6_0_g26 = ( 1.0 - _MaskRadius );
				float temp_output_1_0_g28 = temp_output_6_0_g26;
				float lerpResult5_g26 = lerp( temp_output_6_0_g26 , 1.0 , _MaskFeather);
				float smoothstepResult22_g29 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g26 - temp_output_1_0_g28 ) / ( lerpResult5_g26 - temp_output_1_0_g28 ) ) ) , _MaskPower ));
				float Mask22 = smoothstepResult22_g29;
				float Alpha77 = ( Mask22 * _Alpha );
				

				float Alpha = Alpha77;
				float AlphaClipThreshold = _AlphaClipThreshold;

				#if _ALPHATEST_ON
					clip( Alpha - AlphaClipThreshold );
				#endif

				#ifdef LOD_FADE_CROSSFADE
					LODFadeCrossFade( IN.positionCS );
				#endif

				#if defined(_GBUFFER_NORMALS_OCT)
					float3 normalWS = normalize(IN.normalWS);
					float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms
					float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
					half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
					outNormalWS = half4(packedNormalWS, 0.0);
				#else
					float3 normalWS = IN.normalWS;
					outNormalWS = half4(NormalizeNormalPerPixel(normalWS), 0.0);
				#endif

				#ifdef _WRITE_RENDERING_LAYERS
					uint renderingLayers = GetMeshRenderingLayer();
					outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
				#endif
			}

			ENDHLSL
		}

	
	}
	
	CustomEditor "UnityEditor.ShaderGraphUnlitGUI"
	FallBack "Hidden/Shader Graph/FallbackError"
	
	Fallback Off
}
/*ASEBEGIN
Version=19603
Node;AmplifyShaderEditor.RangedFloatNode;12;-1664,-128;Inherit;False;Property;_MaskRadius;Mask Radius;11;0;Create;True;0;0;0;False;0;False;0.9;0.9;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;13;-1664,-48;Inherit;False;Property;_MaskFeather;Mask Feather;12;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.WorldPosInputsNode;327;-1664,-896;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.RangedFloatNode;328;-1664,-752;Inherit;False;Property;_WaveCount;Wave Count;1;0;Create;True;0;0;0;False;0;False;0;2;0;32;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;32;-1280,-128;Inherit;False;Radial Gradient 2;-1;;26;969db7e12a1ad8c4c8b8d89670372700;1,12,0;3;10;FLOAT2;0,0;False;8;FLOAT;0.5;False;9;FLOAT;0.1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;19;-1280,32;Inherit;False;Property;_MaskPower;Mask Power;13;0;Create;True;0;0;0;False;0;False;1;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.CustomExpressionNode;321;-1280,-896;Inherit;False;Waves;7;File;3;True;worldPosition;FLOAT3;0,0,0;In;;Inherit;False;True;count;INT;0;In;;Inherit;False;True;output;FLOAT;0;Out;;Inherit;False;Waves;False;False;0;56ba52d47988d6b4393bae4da2622fcf;False;4;0;FLOAT;0;False;1;FLOAT3;0,0,0;False;2;INT;0;False;3;FLOAT;0;False;2;FLOAT;0;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;360;-1280,-768;Inherit;False;Property;_WavePower;Wave Power;3;0;Create;True;0;0;0;False;0;False;1;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;86;-1024,-128;Inherit;False;Power Smoothstep;-1;;29;eaa8bfb6a4986cb418a1675cea297eed;0;4;20;FLOAT;1;False;4;FLOAT;1;False;7;FLOAT;0;False;23;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.PowerNode;359;-896,-896;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;22;-640,-128;Inherit;False;Mask;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;330;-640,-896;Inherit;False;Waves;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;73;-1664,1408;Inherit;False;22;Mask;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;85;-1664,1488;Inherit;False;Property;_Alpha;Alpha;36;0;Create;True;0;0;0;False;0;False;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;334;-256,2896;Inherit;False;Property;_WaveVertexOffset;Wave Vertex Offset;4;0;Create;True;0;0;0;False;0;False;0;0.1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.NormalVertexDataNode;333;-256,2976;Inherit;False;0;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.GetLocalVarNode;332;-256,2816;Inherit;False;330;Waves;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;144;-1280,1408;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;335;128,2816;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;77;-1024,1408;Inherit;False;Alpha;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;336;384,2816;Inherit;False;Wave Vertex Offset;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.OneMinusNode;220;-2944,-1280;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;221;-2784,-1280;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;2,2;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;223;-2944,-1408;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT2;0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleAddOpNode;226;-2432,-1408;Inherit;False;5;5;0;FLOAT4;0,0,0,0;False;1;FLOAT2;0.5,0.5;False;2;FLOAT2;0,0;False;3;FLOAT3;0,0,0;False;4;FLOAT3;0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.WireNode;227;-2704,-1168;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.FunctionNode;215;-3328,-1792;Inherit;False;Parallax Offset;-1;;53;66d259709a71255489a93d3df825942b;3,20,1,16,0,9,0;1;13;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ComponentMaskNode;218;-3072,-1792;Inherit;False;True;True;False;True;1;0;FLOAT3;0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;231;-2816,-1792;Inherit;False;Parallax Offset;-1;True;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;213;-2176,-1408;Inherit;False;Texture UV;-1;True;1;0;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RangedFloatNode;214;-3712,-1792;Inherit;False;Property;_TextureParallaxOffset;Texture Parallax Offset;10;0;Create;True;0;0;0;False;0;False;0;0.65;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;138;-3200,-2304;Inherit;False;3;3;0;FLOAT4;0,0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.TexturePropertyNode;115;-1664,-4224;Inherit;True;Global;_CameraOpaqueTexture;_CameraOpaqueTexture;48;0;Create;True;0;0;0;True;0;False;None;;False;white;Auto;Texture2D;-1;0;2;SAMPLER2D;0;SAMPLERSTATE;1
Node;AmplifyShaderEditor.TexturePropertyNode;212;-1664,-3968;Inherit;True;Property;Texture;Texture;6;0;Create;True;0;0;0;False;0;False;None;bd9dce1b91b94f84a92f86db5eac9373;False;white;Auto;Texture2D;-1;0;2;SAMPLER2D;0;SAMPLERSTATE;1
Node;AmplifyShaderEditor.RegisterLocalVarNode;211;-1280,-3968;Inherit;False;Texture;-1;True;1;0;SAMPLER2D;;False;1;SAMPLER2D;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;116;-1280,-4224;Inherit;False;_CameraOpaqueTexture;-1;True;1;0;SAMPLER2D;;False;1;SAMPLER2D;0
Node;AmplifyShaderEditor.RangedFloatNode;247;-1664,-1520;Inherit;False;Property;_BlurNoisePowerRemapMax1;Blur Noise Power Remap Max;46;0;Create;True;0;0;0;False;0;False;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;118;-1664,-3584;Inherit;False;116;_CameraOpaqueTexture;1;0;OBJECT;;False;1;SAMPLER2D;0
Node;AmplifyShaderEditor.TexelSizeNode;124;-1664,-3328;Inherit;False;-1;1;0;SAMPLER2D;0;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;125;-1408,-3328;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SamplerStateNode;120;-1664,-3152;Inherit;False;0;0;0;1;-1;None;1;0;SAMPLER2D;0;False;1;SAMPLERSTATE;0
Node;AmplifyShaderEditor.GetLocalVarNode;150;-1664,-2912;Inherit;False;39;Noise;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;153;-1280,-2912;Inherit;False;Power Smoothstep;-1;;54;eaa8bfb6a4986cb418a1675cea297eed;0;4;20;FLOAT;1;False;4;FLOAT;1;False;7;FLOAT;0;False;23;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;152;-1664,-2832;Inherit;False;Property;_BlurNoisePower;Blur Noise Power;42;0;Create;True;0;0;0;False;0;False;0.1;0.4;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;154;-1664,-2752;Inherit;False;Property;_BlurNoisePowerRemapMin;Blur Noise Power Remap Min;45;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;155;-1664,-2672;Inherit;False;Property;_BlurNoisePowerRemapMax;Blur Noise Power Remap Max;47;0;Create;True;0;0;0;False;0;False;1;0.5;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;122;-1664,-2992;Inherit;False;Property;_BlurRadius;Blur Radius;39;0;Create;True;0;0;0;False;0;False;8;10;0;32;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;117;-512,-3456;Inherit;False;Gaussian Blur;-1;;55;40d140c78ce149b4dbebef34d705ea94;0;6;2;SAMPLER2D;0;False;4;FLOAT2;0,0;False;3;FLOAT2;0,0;False;10;SAMPLERSTATE;;False;7;FLOAT;8;False;6;FLOAT;1;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;146;-896,-3072;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode;204;-128,-3456;Inherit;False;True;True;True;False;1;0;FLOAT4;0,0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.TexelSizeNode;240;-1664,-2176;Inherit;False;-1;1;0;SAMPLER2D;0;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;241;-1408,-2176;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SamplerStateNode;242;-1664,-2000;Inherit;False;0;0;0;1;-1;None;1;0;SAMPLER2D;0;False;1;SAMPLERSTATE;0
Node;AmplifyShaderEditor.GetLocalVarNode;243;-1664,-1760;Inherit;False;39;Noise;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode;253;-128,-2304;Inherit;False;True;True;True;False;1;0;FLOAT4;0,0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.FunctionNode;244;-1280,-1760;Inherit;False;Power Smoothstep;-1;;56;eaa8bfb6a4986cb418a1675cea297eed;0;4;20;FLOAT;1;False;4;FLOAT;1;False;7;FLOAT;0;False;23;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;250;-512,-2304;Inherit;False;Gaussian Blur;-1;;57;40d140c78ce149b4dbebef34d705ea94;0;6;2;SAMPLER2D;0;False;4;FLOAT2;0,0;False;3;FLOAT2;0,0;False;10;SAMPLERSTATE;;False;7;FLOAT;8;False;6;FLOAT;1;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;251;-896,-1920;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;245;-1664,-1680;Inherit;False;Property;_BlurNoisePower1;Blur Noise Power;43;0;Create;True;0;0;0;False;0;False;0.1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;246;-1664,-1600;Inherit;False;Property;_BlurNoisePowerRemapMin1;Blur Noise Power Remap Min;44;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;248;-1664,-1840;Inherit;False;Property;_BlurRadius1;Blur Radius;40;0;Create;True;0;0;0;False;0;False;8;8;0;32;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;249;-1664,-1920;Inherit;False;Property;_BlurQuality1;Blur Quality;38;1;[IntRange];Create;True;0;0;0;False;0;False;4;0;1;12;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;121;-1664,-3072;Inherit;False;Property;_BlurQuality;Blur Quality;37;1;[IntRange];Create;True;0;0;0;False;0;False;4;8;1;12;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;239;-1664,-2432;Inherit;False;211;Texture;1;0;OBJECT;;False;1;SAMPLER2D;0
Node;AmplifyShaderEditor.GetLocalVarNode;128;-1664,-3456;Inherit;False;127;Scene UV;1;0;OBJECT;;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;237;128,-2304;Inherit;False;Blurred Texture;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;123;128,-3456;Inherit;False;Blurred Camera Texture;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;292;-1664,-1280;Inherit;False;123;Blurred Camera Texture;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.StaticSwitch;280;-1280,-1280;Inherit;False;Property;_UseTexture;Use Texture;7;0;Create;True;0;0;0;False;0;False;0;0;0;True;;Toggle;2;Key0;Key1;Create;True;True;All;9;1;FLOAT3;0,0,0;False;0;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;4;FLOAT3;0,0,0;False;5;FLOAT3;0,0,0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.FunctionNode;296;-1024,-1152;Inherit;False;Colour RGB x A;-1;;62;034d6205f93eb7e4f9100dabf18de7c4;0;1;22;COLOR;1,1,1,0.5019608;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;294;-640,-1280;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ColorNode;166;-1280,-1152;Inherit;False;Property;_Colour;Colour;0;1;[HDR];Create;True;0;0;0;False;0;False;1,1,1,1;1,1,1,1;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.DepthFade;300;-3584,-3200;Inherit;False;True;True;True;2;1;FLOAT3;0,0,0;False;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;304;-3072,-3200;Inherit;False;Power Smoothstep;-1;;63;eaa8bfb6a4986cb418a1675cea297eed;0;4;20;FLOAT;1;False;4;FLOAT;1;False;7;FLOAT;0;False;23;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;299;-3968,-3200;Inherit;False;Property;_NoiseDepthFadeDistance;Noise Depth Fade Distance;29;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;301;-3584,-3104;Inherit;False;Property;_NoiseDepthFadePower;Noise Depth Fade Power;30;0;Create;True;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;303;-3584,-2944;Inherit;False;Property;_NoiseDepthFadeRemapMax;Noise Depth Fade Remap Max;32;0;Create;True;0;0;0;False;0;False;1;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;306;-2688,-3200;Inherit;False;Noise Depth Fade;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;142;-3200,-2688;Inherit;False;3;3;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;143;-3584,-2608;Inherit;False;Property;_DistortionNoise;Distortion Noise;41;0;Create;True;0;0;0;False;0;False;0.001;0.002;0;0.1;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;140;-3584,-2688;Inherit;False;129;Noise Gradient;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;228;-2944,-2688;Inherit;False;UV Distortion;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;307;-3584,-2528;Inherit;False;306;Noise Depth Fade;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;302;-3584,-3024;Inherit;False;Property;_NoiseDepthFadeRemapMin;Noise Depth Fade Remap Min;31;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;309;-1280,-1600;Inherit;False;306;Noise Depth Fade;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;308;-1280,-2752;Inherit;False;306;Noise Depth Fade;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;310;-2944,-3328;Inherit;False;Constant;_Float0;Float 0;54;0;Create;True;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;278;-384,-1280;Inherit;False;Selected Blurred Texture;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.FunctionNode;100;-1280,128;Inherit;False;Radial Gradient 2;-1;;64;969db7e12a1ad8c4c8b8d89670372700;1,12,0;3;10;FLOAT2;0,0;False;8;FLOAT;0.5;False;9;FLOAT;0.1;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;102;-1024,128;Inherit;False;Power Smoothstep;-1;;67;eaa8bfb6a4986cb418a1675cea297eed;0;4;20;FLOAT;1;False;4;FLOAT;1;False;7;FLOAT;0;False;23;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;105;-640,128;Inherit;False;Mask Inner;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;35;-1664,512;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;36;-1664,656;Inherit;False;Property;_NoiseScale;Noise Scale;18;0;Create;True;0;0;0;False;0;False;1;2;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.Vector3Node;44;-1664,720;Inherit;False;Property;_NoiseTiling;Noise Tiling;19;0;Create;True;0;0;0;False;0;False;1,1,1;1,0.8,1;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.Vector4Node;37;-1664,880;Inherit;False;Property;_NoiseAnimation;Noise Animation;20;0;Create;True;0;0;0;False;0;False;0,0,0,0;0,0.2,0,3;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector4Node;48;-1664,1072;Inherit;False;Property;_NoiseOffset;Noise Offset;21;0;Create;True;0;0;0;False;0;False;0,0,0,0;0,5,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.FunctionNode;34;-1280,656;Inherit;False;Scale Tiling Offset Animation;-1;;68;650501f4d90f3194eb72a847e06cc2e3;1,21,0;6;4;FLOAT3;0,0,0;False;7;FLOAT;1;False;8;FLOAT3;1,1,1;False;9;FLOAT4;0,0,0,0;False;19;INT;0;False;12;FLOAT4;0,0,0,0;False;2;FLOAT3;0;FLOAT;15
Node;AmplifyShaderEditor.RangedFloatNode;53;-1280,976;Inherit;False;Property;_NoiseDilation;Noise Dilation;24;0;Create;True;0;0;0;False;0;False;0.01;0.02;0;0.1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;52;-1280,912;Inherit;False;Property;_NoiseOctaves;Noise Octaves;23;1;[IntRange];Create;True;0;0;0;False;0;False;1;1;0;5;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;51;-768,656;Inherit;False;Simplex Noise Caustics;-1;;70;477e7c249263854458b4f42934448d42;0;4;4;FLOAT3;0,0,0;False;6;FLOAT;0;False;7;FLOAT;1;False;9;FLOAT;0.01;False;2;FLOAT;0;FLOAT3;3
Node;AmplifyShaderEditor.RangedFloatNode;55;-768,816;Inherit;False;Property;_NoisePower;Noise Power;25;0;Create;True;0;0;0;False;0;False;1;2;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;60;-768,912;Inherit;False;Property;_NoiseRemapFromMin;Noise Remap From Min;26;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;61;-768,976;Inherit;False;Property;_NoiseRemapFromMax;Noise Remap From Max;27;0;Create;True;0;0;0;False;0;False;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;62;-768,1072;Inherit;False;Property;_NoiseRemapToMin;Noise Remap To Min;28;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.PowerNode;54;-256,656;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.AbsOpNode;130;-384,784;Inherit;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SignOpNode;132;-384,848;Inherit;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.TFHCRemapNode;59;0,656;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.PowerNode;131;0,816;Inherit;False;False;2;0;FLOAT3;0,0,0;False;1;FLOAT;1;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;39;256,656;Inherit;False;Noise;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;133;256,912;Inherit;False;5;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;1,1,1;False;3;FLOAT3;0,0,0;False;4;FLOAT3;1,1,1;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;50;-2304,512;Inherit;False;Property;_NoiseParallaxOffset;Noise Parallax Offset;22;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;49;-2048,512;Inherit;False;Parallax Offset;-1;;71;66d259709a71255489a93d3df825942b;3,20,1,16,0,9,0;1;13;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;129;912,912;Inherit;False;Noise Gradient;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;134;640,912;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.WireNode;136;368,1136;Inherit;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;98;-1664,128;Inherit;False;Property;_InnerMaskRadius;Inner Mask Radius;14;0;Create;True;0;0;0;False;0;False;0;0;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;99;-1664,208;Inherit;False;Property;_InnerMaskFeather;Inner Mask Feather;15;0;Create;True;0;0;0;False;0;False;0.5;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;101;-1280,288;Inherit;False;Property;_InnerMaskPower;Inner Mask Power;16;0;Create;True;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;323;-1664,-640;Inherit;False;278;Selected Blurred Texture;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ColorNode;329;-1664,-560;Inherit;False;Property;_WaveColour;Wave Colour;2;1;[HDR];Create;True;0;0;0;False;0;False;1,1,1,1;4,0.5188135,0,1;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.LerpOp;322;-1024,-640;Inherit;False;3;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;326;-768,-640;Inherit;False;Colour;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;325;-1280,-512;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;276;-1408,3776;Inherit;False;192;Intersection Highlight 1;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;171;-1280,1664;Inherit;False;Normal From Height;-1;;72;1942fe2c5f1a1f94881a33d532e4afeb;0;2;20;FLOAT;0;False;110;FLOAT;1;False;2;FLOAT3;40;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;172;-1664,1664;Inherit;False;39;Noise;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;173;-1664,1728;Inherit;False;Property;_NoiseNormalStrength;Noise Normal Strength;35;0;Create;True;0;0;0;False;0;False;1;0;0;10;0;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;189;-896,1664;Inherit;False;Normals;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;265;-896,1728;Inherit;False;World Normals;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DepthFade;273;-1664,2304;Inherit;False;True;True;True;2;1;FLOAT3;0,0,0;False;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;197;-1664,2176;Inherit;False;Property;_IntersectionHighlight1RemapMax;Intersection Highlight 1 Remap Max;53;0;Create;True;0;0;0;False;0;False;1;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;196;-1664,2080;Inherit;False;Property;_IntersectionHighlight1RemapMin;Intersection Highlight 1 Remap Min;52;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;195;-1664,2016;Inherit;False;Property;_IntersectionHighlight1Power;Intersection Highlight 1 Power;51;0;Create;True;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;193;-2048,1920;Inherit;False;Property;_IntersectionHighlight1Distance;Intersection Highlight 1 Distance;50;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;194;-1152,1920;Inherit;False;Power Smoothstep;-1;;73;eaa8bfb6a4986cb418a1675cea297eed;0;4;20;FLOAT;1;False;4;FLOAT;1;False;7;FLOAT;0;False;23;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;210;-768,1920;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;266;-1152,2304;Inherit;False;Power Smoothstep;-1;;74;eaa8bfb6a4986cb418a1675cea297eed;0;4;20;FLOAT;1;False;4;FLOAT;1;False;7;FLOAT;0;False;23;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;271;-768,2304;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;267;-1664,2400;Inherit;False;Property;_IntersectionHighlight2Power;Intersection Highlight 2 Power;56;0;Create;True;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;268;-1664,2464;Inherit;False;Property;_IntersectionHighlight2RemapMin;Intersection Highlight 2 Remap Min;57;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;270;-1664,2560;Inherit;False;Property;_IntersectionHighlight2RemapMax;Intersection Highlight 2 Remap Max;58;0;Create;True;0;0;0;False;0;False;1;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;269;-2048,2304;Inherit;False;Property;_IntersectionHighlight2Distance;Intersection Highlight 2 Distance;55;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;272;-512,2304;Inherit;False;Intersection Highlight 2;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;192;-512,1920;Inherit;False;Intersection Highlight 1;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;256;-1664,2816;Inherit;False;192;Intersection Highlight 1;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;258;-1280,2816;Inherit;False;Normal From Height;-1;;75;1942fe2c5f1a1f94881a33d532e4afeb;0;2;20;FLOAT;0;False;110;FLOAT;1;False;2;FLOAT3;40;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;257;-896,2816;Inherit;False;Intersection Highlight Height Normals;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;259;-1664,2880;Inherit;False;Property;_IntersectionHighlightHeightNormalStrength;Intersection Highlight Height Normal Strength;59;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;208;-1408,3456;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;275;-1792,3328;Inherit;False;Property;_IntersectionHighlight2Colour;Intersection Highlight 2 Colour;54;1;[HDR];Create;True;0;0;0;False;0;False;1,1,1,1;1,1,1,1;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.LerpOp;274;-1152,3328;Inherit;False;3;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;205;-1792,3520;Inherit;False;272;Intersection Highlight 2;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;207;-1408,3584;Inherit;False;Property;_IntersectionHighlight1Colour;Intersection Highlight 1 Colour;49;1;[HDR];Create;True;0;0;0;False;0;False;1,1,1,1;1,1,1,1;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.LerpOp;203;-768,3328;Inherit;False;3;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;277;-1024,3712;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;209;-512,3328;Inherit;False;Colour 1;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;199;-1792,3200;Inherit;False;278;Selected Blurred Texture;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;174;256,1888;Inherit;False;Property;_Metallic;Metallic;33;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;175;256,1952;Inherit;False;Property;_Smoothness;Smoothness;34;0;Create;True;0;0;0;False;0;False;0.5;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;264;256,2112;Inherit;False;Property;_AlphaClipThreshold;Alpha Clip Threshold;17;0;Create;True;0;0;0;False;0;False;0.5;0.01;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;190;256,1728;Inherit;False;189;Normals;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ColorNode;298;256,1536;Inherit;False;Constant;_Color0;Color 0;50;0;Create;True;0;0;0;False;0;False;0,0,0,0;0,0,0,0;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.GetLocalVarNode;78;256,2048;Inherit;False;77;Alpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;337;256,2192;Inherit;False;336;Wave Vertex Offset;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;331;-1664,-368;Inherit;False;330;Waves;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;126;256,1792;Inherit;False;326;Colour;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;293;-1664,-1200;Inherit;False;237;Blurred Texture;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;353;-3712,-1664;Inherit;False;330;Waves;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;355;-3328,-1664;Inherit;False;Normal From Height;-1;;76;1942fe2c5f1a1f94881a33d532e4afeb;0;2;20;FLOAT;0;False;110;FLOAT;1;False;2;FLOAT3;40;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;356;-3712,-1584;Inherit;False;Property;_WaveNormalStrength;Wave Normal Strength;5;0;Create;True;0;0;0;False;0;False;0;0.4;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;357;-2816,-1664;Inherit;False;Wave Normals;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;230;-2816,-1024;Inherit;False;228;UV Distortion;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DepthFade;191;-1664,1920;Inherit;False;True;True;True;2;1;FLOAT3;0,0,0;False;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;127;-2944,-2304;Inherit;False;Scene UV;-1;True;1;0;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.GetLocalVarNode;252;-1664,-2304;Inherit;False;213;Texture UV;1;0;OBJECT;;False;1;FLOAT4;0
Node;AmplifyShaderEditor.GetLocalVarNode;229;-3584,-2128;Inherit;False;228;UV Distortion;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ScreenPosInputsNode;119;-3584,-2304;Float;False;0;False;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TextureCoordinatesNode;216;-4096,-1408;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.GetLocalVarNode;232;-4096,-1280;Inherit;False;231;Parallax Offset;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;217;-3840,-1408;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode;219;-3584,-1024;Inherit;False;Property;_TextureScale;Texture Scale;9;0;Create;True;0;0;0;False;0;False;1;0.5;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;225;-3968,-896;Inherit;False;211;Texture;1;0;OBJECT;;False;1;SAMPLER2D;0
Node;AmplifyShaderEditor.TextureTransformNode;224;-3712,-896;Inherit;False;212;False;1;0;SAMPLER2D;;False;2;FLOAT2;0;FLOAT2;1
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;222;-3328,-1024;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ScreenPosInputsNode;361;-4096,-1152;Float;False;0;False;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.StaticSwitch;362;-3456,-1408;Inherit;False;Property;_TextureScreenUVs;Texture Screen UVs;8;0;Create;True;0;0;0;False;0;False;0;0;0;True;;Toggle;2;Key0;Key1;Create;True;True;All;9;1;FLOAT4;0,0,0,0;False;0;FLOAT4;0,0,0,0;False;2;FLOAT4;0,0,0,0;False;3;FLOAT4;0,0,0,0;False;4;FLOAT4;0,0,0,0;False;5;FLOAT4;0,0,0,0;False;6;FLOAT4;0,0,0,0;False;7;FLOAT4;0,0,0,0;False;8;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.GetLocalVarNode;358;-2816,-944;Inherit;False;357;Wave Normals;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;363;-3584,-2048;Inherit;False;357;Wave Normals;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;262;-3584,-1968;Inherit;False;257;Intersection Highlight Height Normals;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;313;1408,768;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ShadowCaster;0;2;ShadowCaster;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;False;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=ShadowCaster;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;314;1408,768;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthOnly;0;3;DepthOnly;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;True;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;False;False;True;1;LightMode=DepthOnly;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;315;1408,768;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;Meta;0;4;Meta;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Meta;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;316;1408,768;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;Universal2D;0;5;Universal2D;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=Universal2D;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;317;1408,768;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;SceneSelectionPass;0;6;SceneSelectionPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=SceneSelectionPass;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;318;1408,768;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ScenePickingPass;0;7;ScenePickingPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Picking;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;319;1408,768;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthNormals;0;8;DepthNormals;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=DepthNormalsOnly;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;320;1408,768;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthNormalsOnly;0;9;DepthNormalsOnly;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=DepthNormalsOnly;False;True;9;d3d11;metal;vulkan;xboxone;xboxseries;playstation;ps4;ps5;switch;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;311;800,1664;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ExtraPrePass;0;0;ExtraPrePass;5;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;0;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;312;896,1648;Float;False;True;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;Portal Transparent;2992e84f91cbeb14eab234972e07ea9d;True;Forward;0;1;Forward;8;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;True;1;5;False;;10;False;;1;1;False;;10;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;2;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=UniversalForwardOnly;False;False;0;;0;0;Standard;22;Surface;1;638673522094830314;  Blend;0;0;Two Sided;1;0;Forward Only;0;0;Cast Shadows;1;0;  Use Shadow Threshold;0;0;Receive Shadows;1;0;GPU Instancing;1;0;LOD CrossFade;1;0;Built-in Fog;1;0;Meta Pass;0;0;Extra Pre Pass;0;0;Tessellation;1;638674079748001138;  Phong;0;0;  Strength;0.5,False,;0;  Type;0;0;  Tess;32,False,;0;  Min;10,False,;0;  Max;25,False,;0;  Edge Length;16,False,;0;  Max Displacement;25,False,;0;Vertex Position,InvertActionOnDeselection;1;0;0;10;False;True;True;True;False;False;True;True;True;False;False;;True;0
WireConnection;32;8;12;0
WireConnection;32;9;13;0
WireConnection;321;1;327;0
WireConnection;321;2;328;0
WireConnection;86;20;32;0
WireConnection;86;4;19;0
WireConnection;359;0;321;4
WireConnection;359;1;360;0
WireConnection;22;0;86;0
WireConnection;330;0;359;0
WireConnection;144;0;73;0
WireConnection;144;1;85;0
WireConnection;335;0;332;0
WireConnection;335;1;334;0
WireConnection;335;2;333;0
WireConnection;77;0;144;0
WireConnection;336;0;335;0
WireConnection;220;0;222;0
WireConnection;221;0;220;0
WireConnection;223;0;362;0
WireConnection;223;1;222;0
WireConnection;226;0;223;0
WireConnection;226;1;221;0
WireConnection;226;2;227;0
WireConnection;226;3;230;0
WireConnection;226;4;358;0
WireConnection;227;0;224;1
WireConnection;215;13;214;0
WireConnection;218;0;215;0
WireConnection;231;0;218;0
WireConnection;213;0;226;0
WireConnection;138;0;119;0
WireConnection;138;1;229;0
WireConnection;138;2;363;0
WireConnection;211;0;212;0
WireConnection;116;0;115;0
WireConnection;124;0;118;0
WireConnection;125;0;124;1
WireConnection;125;1;124;2
WireConnection;120;0;118;0
WireConnection;153;20;150;0
WireConnection;153;4;152;0
WireConnection;153;7;154;0
WireConnection;153;23;155;0
WireConnection;117;2;118;0
WireConnection;117;4;128;0
WireConnection;117;3;125;0
WireConnection;117;10;120;0
WireConnection;117;7;121;0
WireConnection;117;6;146;0
WireConnection;146;0;122;0
WireConnection;146;1;153;0
WireConnection;146;2;308;0
WireConnection;204;0;117;0
WireConnection;240;0;239;0
WireConnection;241;0;240;1
WireConnection;241;1;240;2
WireConnection;242;0;239;0
WireConnection;253;0;250;0
WireConnection;244;20;243;0
WireConnection;244;4;152;0
WireConnection;244;7;154;0
WireConnection;244;23;155;0
WireConnection;250;2;239;0
WireConnection;250;4;252;0
WireConnection;250;3;241;0
WireConnection;250;10;242;0
WireConnection;250;7;121;0
WireConnection;250;6;146;0
WireConnection;251;0;248;0
WireConnection;251;1;244;0
WireConnection;251;2;309;0
WireConnection;237;0;253;0
WireConnection;123;0;204;0
WireConnection;280;1;292;0
WireConnection;280;0;293;0
WireConnection;296;22;166;0
WireConnection;294;0;280;0
WireConnection;294;1;296;0
WireConnection;300;0;299;0
WireConnection;304;20;300;0
WireConnection;304;4;301;0
WireConnection;304;7;302;0
WireConnection;304;23;303;0
WireConnection;306;0;310;0
WireConnection;142;0;140;0
WireConnection;142;1;143;0
WireConnection;142;2;307;0
WireConnection;228;0;142;0
WireConnection;278;0;294;0
WireConnection;100;8;98;0
WireConnection;100;9;99;0
WireConnection;102;20;100;0
WireConnection;102;4;101;0
WireConnection;105;0;102;0
WireConnection;35;1;49;0
WireConnection;34;4;35;0
WireConnection;34;7;36;0
WireConnection;34;8;44;0
WireConnection;34;9;37;0
WireConnection;34;12;48;0
WireConnection;51;4;34;0
WireConnection;51;6;34;15
WireConnection;51;7;52;0
WireConnection;51;9;53;0
WireConnection;54;0;51;0
WireConnection;54;1;55;0
WireConnection;130;0;51;3
WireConnection;132;0;51;3
WireConnection;59;0;54;0
WireConnection;59;1;60;0
WireConnection;59;2;61;0
WireConnection;59;3;62;0
WireConnection;131;0;130;0
WireConnection;131;1;55;0
WireConnection;39;0;59;0
WireConnection;133;0;131;0
WireConnection;133;1;60;0
WireConnection;133;2;61;0
WireConnection;133;3;62;0
WireConnection;49;13;50;0
WireConnection;129;0;134;0
WireConnection;134;0;133;0
WireConnection;134;1;136;0
WireConnection;136;0;132;0
WireConnection;322;0;323;0
WireConnection;322;1;329;5
WireConnection;322;2;325;0
WireConnection;326;0;322;0
WireConnection;325;0;329;4
WireConnection;325;1;331;0
WireConnection;171;20;172;0
WireConnection;171;110;173;0
WireConnection;189;0;171;40
WireConnection;265;0;171;0
WireConnection;273;0;269;0
WireConnection;194;20;191;0
WireConnection;194;4;195;0
WireConnection;194;7;196;0
WireConnection;194;23;197;0
WireConnection;210;0;194;0
WireConnection;266;20;273;0
WireConnection;266;4;267;0
WireConnection;266;7;268;0
WireConnection;266;23;270;0
WireConnection;271;0;266;0
WireConnection;272;0;271;0
WireConnection;192;0;210;0
WireConnection;258;20;256;0
WireConnection;258;110;259;0
WireConnection;257;0;258;40
WireConnection;208;0;275;4
WireConnection;208;1;205;0
WireConnection;274;0;199;0
WireConnection;274;1;275;5
WireConnection;274;2;208;0
WireConnection;203;0;274;0
WireConnection;203;1;207;5
WireConnection;203;2;277;0
WireConnection;277;0;207;4
WireConnection;277;1;276;0
WireConnection;209;0;203;0
WireConnection;355;20;353;0
WireConnection;355;110;356;0
WireConnection;357;0;355;40
WireConnection;191;0;193;0
WireConnection;127;0;138;0
WireConnection;217;0;216;0
WireConnection;217;1;232;0
WireConnection;224;0;225;0
WireConnection;222;0;219;0
WireConnection;222;1;224;0
WireConnection;362;1;217;0
WireConnection;362;0;361;0
WireConnection;312;2;126;0
WireConnection;312;3;78;0
WireConnection;312;4;264;0
WireConnection;312;5;337;0
ASEEND*/
//CHKSM=77F52304D2E43F3066001CA4378C9D73DDF07023