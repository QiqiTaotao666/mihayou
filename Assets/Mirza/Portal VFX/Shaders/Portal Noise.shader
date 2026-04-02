// Made with Amplify Shader Editor v1.9.6.3
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Portal Noise"
{
	Properties
	{
		[HideInInspector] _EmissionColor("Emission Color", Color) = (1,1,1,1)
		[HideInInspector] _AlphaCutoff("Alpha Cutoff ", Range(0, 1)) = 0.5
		_OuterMaskRadius("Outer Mask Radius", Range( 0 , 1)) = 0.9
		_OuterMaskFeather("Outer Mask Feather", Range( 0 , 1)) = 0.1
		_OuterMaskPower("Outer Mask Power", Float) = 5
		_InnerMaskRadius("Inner Mask Radius", Range( 0 , 2)) = 0
		_InnerMaskFeather("Inner Mask Feather", Range( 0 , 1)) = 0.5
		_InnerMaskPower("Inner Mask Power", Float) = 1
		[HDR]_NoiseColourA("Noise Colour A", Color) = (1,1,1,1)
		[HDR]_NoiseColourB("Noise Colour B", Color) = (1,1,1,1)
		_NoiseScale("Noise Scale", Float) = 1
		_NoiseTiling("Noise Tiling", Vector) = (1,1,1,0)
		_NoiseAnimation("Noise Animation", Vector) = (0,0,0,0)
		_NoiseOffset("Noise Offset", Vector) = (0,0,0,0)
		_NoiseParallaxOffset("Noise Parallax Offset", Float) = 0
		[IntRange]_NoiseOctaves("Noise Octaves", Range( 0 , 5)) = 1
		_NoiseDilation("Noise Dilation", Range( 0 , 0.1)) = 0.01
		[Toggle(_NOISEPOLARCOORDINATES_ON)] _NoisePolarCoordinates("Noise Polar Coordinates", Float) = 0
		[Toggle(_NOISESIMPLEPOLARCOORDINATES_ON)] _NoiseSimplePolarCoordinates("Noise Simple Polar Coordinates", Float) = 0
		_NoisePolarCoordinatesTwist("Noise Polar Coordinates Twist", Range( -720 , 720)) = 0
		_NoisePower("Noise Power", Float) = 1
		_NoiseRemapFromMin("Noise Remap From Min", Range( 0 , 1)) = 0
		_NoiseRemapFromMax("Noise Remap From Max", Range( 0 , 1)) = 1
		_NoiseRemapToMin("Noise Remap To Min", Range( 0 , 1)) = 0
		_NoiseRemapToMaxAlpha("Noise Remap To Max (Alpha)", Range( 0 , 1)) = 1
		_NoiseColourGradientPower("Noise Colour Gradient Power", Float) = 1
		_NoiseColourGradientRemapMin("Noise Colour Gradient Remap Min", Range( 0 , 1)) = 0
		_NoiseColourGradientRemapMax("Noise Colour Gradient Remap Max", Range( 0 , 1)) = 1


		//_TessPhongStrength( "Tess Phong Strength", Range( 0, 1 ) ) = 0.5
		//_TessValue( "Tess Max Tessellation", Range( 1, 32 ) ) = 16
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

		Cull Off
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

			
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #define ASE_FOG 1
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_SRP_VERSION 140011


			
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

			#include "../../VFXToolkit/Shaders/_Includes/Noise.cginc"
			#include "../../VFXToolkit/Shaders/_Includes/Transform.cginc"
			#define ASE_NEEDS_VERT_NORMAL
			#define ASE_NEEDS_FRAG_WORLD_POSITION
			#pragma shader_feature_local _NOISEPOLARCOORDINATES_ON
			#pragma shader_feature_local _NOISESIMPLEPOLARCOORDINATES_ON


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
			float4 _NoiseColourA;
			float4 _NoiseColourB;
			float4 _NoiseOffset;
			float4 _NoiseAnimation;
			float3 _NoiseTiling;
			float _InnerMaskRadius;
			float _OuterMaskPower;
			float _OuterMaskFeather;
			float _OuterMaskRadius;
			float _NoiseColourGradientPower;
			float _NoiseRemapToMaxAlpha;
			float _NoiseRemapToMin;
			float _NoiseRemapFromMax;
			float _NoisePolarCoordinatesTwist;
			float _NoisePower;
			float _InnerMaskFeather;
			float _NoiseDilation;
			float _NoiseOctaves;
			float _NoiseScale;
			float _NoiseParallaxOffset;
			float _NoiseColourGradientRemapMax;
			float _NoiseColourGradientRemapMin;
			float _NoiseRemapFromMin;
			float _InnerMaskPower;
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

				float3 vertexValue = defaultVertexValue;

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

				float4 temp_output_22_0_g71 = _NoiseColourA;
				float4 temp_output_22_0_g72 = _NoiseColourB;
				float localSimplexNoise_Caustics_float2_g48 = ( 0.0 );
				float2 texCoord140 = IN.ase_texcoord4.xy * float2( 1,1 ) + float2( 0,0 );
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
				float3 worldToTangentDir18_g1 = mul( ase_worldToTangent, ase_worldNormal);
				float dotResult15_g1 = dot( ase_tanViewDir , worldToTangentDir18_g1 );
				float3 Parallax_Offset_UV141 = ( float3( texCoord140 ,  0.0 ) + ( -( ase_tanViewDir / dotResult15_g1 ) * _NoiseParallaxOffset ) );
				float4 temp_output_10_0_g45 = ( float4( ( Parallax_Offset_UV141 * _NoiseScale * _NoiseTiling ) , 0.0 ) - ( _NoiseOffset + ( _NoiseAnimation * _TimeParameters.x ) ) );
				float3 temp_output_34_0 = (temp_output_10_0_g45).xyz;
				float3 position2_g48 = temp_output_34_0;
				float angle2_g48 = (temp_output_10_0_g45).w;
				float octaves2_g48 = _NoiseOctaves;
				float gradientStrength2_g48 = _NoiseDilation;
				float noise2_g48 = 0.0;
				float3 gradient2_g48 = float3( 0,0,0 );
				SimplexNoise_Caustics_float( position2_g48 , angle2_g48 , octaves2_g48 , gradientStrength2_g48 , noise2_g48 , gradient2_g48 );
				float temp_output_112_0 = noise2_g48;
				float localSimplexNoise_Caustics_PolarCoordinates_float2_g62 = ( 0.0 );
				float localTwistY_float2_g47 = ( 0.0 );
				float2 position2_g47 = ( Parallax_Offset_UV141 - float3( 0.5,0.5,0 ) ).xy;
				float2 center2_g47 = float2( 0,0 );
				float twist2_g47 = radians( _NoisePolarCoordinatesTwist );
				float2 output2_g47 = float2( 0,0 );
				TwistY_float( position2_g47 , center2_g47 , twist2_g47 , output2_g47 );
				float3 position2_g62 = float3( output2_g47 ,  0.0 );
				float octaves2_g62 = _NoiseOctaves;
				float gradientStrength2_g62 = _NoiseDilation;
				float scale2_g62 = _NoiseScale;
				float3 tiling2_g62 = _NoiseTiling;
				float4 animation2_g62 = _NoiseAnimation;
				float4 offset2_g62 = _NoiseOffset;
				float time2_g62 = _TimeParameters.x;
				#ifdef _NOISESIMPLEPOLARCOORDINATES_ON
				float staticSwitch150 = (float)1;
				#else
				float staticSwitch150 = (float)0;
				#endif
				float simplePolarCoordinates2_g62 = (float)(int)staticSwitch150;
				float noise2_g62 = 0.0;
				float3 gradient2_g62 = float3( 0,0,0 );
				SimplexNoise_Caustics_PolarCoordinates_float( position2_g62 , octaves2_g62 , gradientStrength2_g62 , scale2_g62 , tiling2_g62 , animation2_g62 , offset2_g62 , time2_g62 , simplePolarCoordinates2_g62 , noise2_g62 , gradient2_g62 );
				#ifdef _NOISEPOLARCOORDINATES_ON
				float staticSwitch146 = noise2_g62;
				#else
				float staticSwitch146 = temp_output_112_0;
				#endif
				float Noise39 = (_NoiseRemapToMin + (pow( staticSwitch146 , _NoisePower ) - _NoiseRemapFromMin) * (_NoiseRemapToMaxAlpha - _NoiseRemapToMin) / (_NoiseRemapFromMax - _NoiseRemapFromMin));
				float smoothstepResult22_g73 = smoothstep( _NoiseColourGradientRemapMin , _NoiseColourGradientRemapMax , pow( Noise39 , _NoiseColourGradientPower ));
				float temp_output_81_0 = smoothstepResult22_g73;
				float3 lerpResult65 = lerp( ( (temp_output_22_0_g71).rgb * (temp_output_22_0_g71).a ) , ( (temp_output_22_0_g72).rgb * (temp_output_22_0_g72).a ) , temp_output_81_0);
				float3 Colour29 = lerpResult65;
				
				float2 texCoord11_g67 = IN.ase_texcoord4.xy * float2( 2,2 ) + float2( -1,-1 );
				float temp_output_7_0_g67 = ( 1.0 - length( texCoord11_g67 ) );
				float temp_output_6_0_g67 = ( 1.0 - _OuterMaskRadius );
				float temp_output_1_0_g69 = temp_output_6_0_g67;
				float lerpResult5_g67 = lerp( temp_output_6_0_g67 , 1.0 , _OuterMaskFeather);
				float smoothstepResult22_g70 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g67 - temp_output_1_0_g69 ) / ( lerpResult5_g67 - temp_output_1_0_g69 ) ) ) , _OuterMaskPower ));
				float Mask22 = smoothstepResult22_g70;
				float3 Parallax_Offset_UV_Centered135 = (Parallax_Offset_UV141*2.0 + -1.0);
				float temp_output_7_0_g63 = ( 1.0 - length( Parallax_Offset_UV_Centered135.xy ) );
				float temp_output_6_0_g63 = ( 1.0 - _InnerMaskRadius );
				float temp_output_1_0_g65 = temp_output_6_0_g63;
				float lerpResult5_g63 = lerp( temp_output_6_0_g63 , 1.0 , _InnerMaskFeather);
				float smoothstepResult22_g66 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g63 - temp_output_1_0_g65 ) / ( lerpResult5_g63 - temp_output_1_0_g65 ) ) ) , _InnerMaskPower ));
				float Mask_Inner105 = smoothstepResult22_g66;
				float temp_output_80_0 = ( Mask22 * saturate( ( Noise39 - Mask_Inner105 ) ) );
				float Alpha77 = temp_output_80_0;
				
				float3 BakedAlbedo = 0;
				float3 BakedEmission = 0;
				float3 Color = Colour29;
				float Alpha = Alpha77;
				float AlphaClipThreshold = 0.5;
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
			
			Name "DepthOnly"
			Tags { "LightMode"="DepthOnly" }

			ZWrite On
			ColorMask R
			AlphaToMask Off

			HLSLPROGRAM

			
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #define ASE_FOG 1
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_SRP_VERSION 140011


			
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

			#include "../../VFXToolkit/Shaders/_Includes/Noise.cginc"
			#include "../../VFXToolkit/Shaders/_Includes/Transform.cginc"
			#define ASE_NEEDS_VERT_NORMAL
			#define ASE_NEEDS_FRAG_WORLD_POSITION
			#pragma shader_feature_local _NOISEPOLARCOORDINATES_ON
			#pragma shader_feature_local _NOISESIMPLEPOLARCOORDINATES_ON


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
				float4 ase_texcoord3 : TEXCOORD3;
				float4 ase_texcoord4 : TEXCOORD4;
				float4 ase_texcoord5 : TEXCOORD5;
				float4 ase_texcoord6 : TEXCOORD6;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _NoiseColourA;
			float4 _NoiseColourB;
			float4 _NoiseOffset;
			float4 _NoiseAnimation;
			float3 _NoiseTiling;
			float _InnerMaskRadius;
			float _OuterMaskPower;
			float _OuterMaskFeather;
			float _OuterMaskRadius;
			float _NoiseColourGradientPower;
			float _NoiseRemapToMaxAlpha;
			float _NoiseRemapToMin;
			float _NoiseRemapFromMax;
			float _NoisePolarCoordinatesTwist;
			float _NoisePower;
			float _InnerMaskFeather;
			float _NoiseDilation;
			float _NoiseOctaves;
			float _NoiseScale;
			float _NoiseParallaxOffset;
			float _NoiseColourGradientRemapMax;
			float _NoiseColourGradientRemapMin;
			float _NoiseRemapFromMin;
			float _InnerMaskPower;
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

				float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
				o.ase_texcoord4.xyz = ase_worldTangent;
				float3 ase_worldNormal = TransformObjectToWorldNormal(v.normalOS);
				o.ase_texcoord5.xyz = ase_worldNormal;
				float ase_vertexTangentSign = v.ase_tangent.w * ( unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0 );
				float3 ase_worldBitangent = cross( ase_worldNormal, ase_worldTangent ) * ase_vertexTangentSign;
				o.ase_texcoord6.xyz = ase_worldBitangent;
				
				o.ase_texcoord3.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord3.zw = 0;
				o.ase_texcoord4.w = 0;
				o.ase_texcoord5.w = 0;
				o.ase_texcoord6.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

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

				float2 texCoord11_g67 = IN.ase_texcoord3.xy * float2( 2,2 ) + float2( -1,-1 );
				float temp_output_7_0_g67 = ( 1.0 - length( texCoord11_g67 ) );
				float temp_output_6_0_g67 = ( 1.0 - _OuterMaskRadius );
				float temp_output_1_0_g69 = temp_output_6_0_g67;
				float lerpResult5_g67 = lerp( temp_output_6_0_g67 , 1.0 , _OuterMaskFeather);
				float smoothstepResult22_g70 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g67 - temp_output_1_0_g69 ) / ( lerpResult5_g67 - temp_output_1_0_g69 ) ) ) , _OuterMaskPower ));
				float Mask22 = smoothstepResult22_g70;
				float localSimplexNoise_Caustics_float2_g48 = ( 0.0 );
				float2 texCoord140 = IN.ase_texcoord3.xy * float2( 1,1 ) + float2( 0,0 );
				float3 ase_worldTangent = IN.ase_texcoord4.xyz;
				float3 ase_worldNormal = IN.ase_texcoord5.xyz;
				float3 ase_worldBitangent = IN.ase_texcoord6.xyz;
				float3 tanToWorld0 = float3( ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x );
				float3 tanToWorld1 = float3( ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y );
				float3 tanToWorld2 = float3( ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z );
				float3 ase_worldViewDir = ( _WorldSpaceCameraPos.xyz - WorldPosition );
				ase_worldViewDir = normalize(ase_worldViewDir);
				float3 ase_tanViewDir =  tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y  + tanToWorld2 * ase_worldViewDir.z;
				ase_tanViewDir = normalize(ase_tanViewDir);
				float3x3 ase_worldToTangent = float3x3(ase_worldTangent,ase_worldBitangent,ase_worldNormal);
				float3 worldToTangentDir18_g1 = mul( ase_worldToTangent, ase_worldNormal);
				float dotResult15_g1 = dot( ase_tanViewDir , worldToTangentDir18_g1 );
				float3 Parallax_Offset_UV141 = ( float3( texCoord140 ,  0.0 ) + ( -( ase_tanViewDir / dotResult15_g1 ) * _NoiseParallaxOffset ) );
				float4 temp_output_10_0_g45 = ( float4( ( Parallax_Offset_UV141 * _NoiseScale * _NoiseTiling ) , 0.0 ) - ( _NoiseOffset + ( _NoiseAnimation * _TimeParameters.x ) ) );
				float3 temp_output_34_0 = (temp_output_10_0_g45).xyz;
				float3 position2_g48 = temp_output_34_0;
				float angle2_g48 = (temp_output_10_0_g45).w;
				float octaves2_g48 = _NoiseOctaves;
				float gradientStrength2_g48 = _NoiseDilation;
				float noise2_g48 = 0.0;
				float3 gradient2_g48 = float3( 0,0,0 );
				SimplexNoise_Caustics_float( position2_g48 , angle2_g48 , octaves2_g48 , gradientStrength2_g48 , noise2_g48 , gradient2_g48 );
				float temp_output_112_0 = noise2_g48;
				float localSimplexNoise_Caustics_PolarCoordinates_float2_g62 = ( 0.0 );
				float localTwistY_float2_g47 = ( 0.0 );
				float2 position2_g47 = ( Parallax_Offset_UV141 - float3( 0.5,0.5,0 ) ).xy;
				float2 center2_g47 = float2( 0,0 );
				float twist2_g47 = radians( _NoisePolarCoordinatesTwist );
				float2 output2_g47 = float2( 0,0 );
				TwistY_float( position2_g47 , center2_g47 , twist2_g47 , output2_g47 );
				float3 position2_g62 = float3( output2_g47 ,  0.0 );
				float octaves2_g62 = _NoiseOctaves;
				float gradientStrength2_g62 = _NoiseDilation;
				float scale2_g62 = _NoiseScale;
				float3 tiling2_g62 = _NoiseTiling;
				float4 animation2_g62 = _NoiseAnimation;
				float4 offset2_g62 = _NoiseOffset;
				float time2_g62 = _TimeParameters.x;
				#ifdef _NOISESIMPLEPOLARCOORDINATES_ON
				float staticSwitch150 = (float)1;
				#else
				float staticSwitch150 = (float)0;
				#endif
				float simplePolarCoordinates2_g62 = (float)(int)staticSwitch150;
				float noise2_g62 = 0.0;
				float3 gradient2_g62 = float3( 0,0,0 );
				SimplexNoise_Caustics_PolarCoordinates_float( position2_g62 , octaves2_g62 , gradientStrength2_g62 , scale2_g62 , tiling2_g62 , animation2_g62 , offset2_g62 , time2_g62 , simplePolarCoordinates2_g62 , noise2_g62 , gradient2_g62 );
				#ifdef _NOISEPOLARCOORDINATES_ON
				float staticSwitch146 = noise2_g62;
				#else
				float staticSwitch146 = temp_output_112_0;
				#endif
				float Noise39 = (_NoiseRemapToMin + (pow( staticSwitch146 , _NoisePower ) - _NoiseRemapFromMin) * (_NoiseRemapToMaxAlpha - _NoiseRemapToMin) / (_NoiseRemapFromMax - _NoiseRemapFromMin));
				float3 Parallax_Offset_UV_Centered135 = (Parallax_Offset_UV141*2.0 + -1.0);
				float temp_output_7_0_g63 = ( 1.0 - length( Parallax_Offset_UV_Centered135.xy ) );
				float temp_output_6_0_g63 = ( 1.0 - _InnerMaskRadius );
				float temp_output_1_0_g65 = temp_output_6_0_g63;
				float lerpResult5_g63 = lerp( temp_output_6_0_g63 , 1.0 , _InnerMaskFeather);
				float smoothstepResult22_g66 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g63 - temp_output_1_0_g65 ) / ( lerpResult5_g63 - temp_output_1_0_g65 ) ) ) , _InnerMaskPower ));
				float Mask_Inner105 = smoothstepResult22_g66;
				float temp_output_80_0 = ( Mask22 * saturate( ( Noise39 - Mask_Inner105 ) ) );
				float Alpha77 = temp_output_80_0;
				

				float Alpha = Alpha77;
				float AlphaClipThreshold = 0.5;

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
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_SRP_VERSION 140011


			
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

			#include "../../VFXToolkit/Shaders/_Includes/Noise.cginc"
			#include "../../VFXToolkit/Shaders/_Includes/Transform.cginc"
			#define ASE_NEEDS_VERT_NORMAL
			#pragma shader_feature_local _NOISEPOLARCOORDINATES_ON
			#pragma shader_feature_local _NOISESIMPLEPOLARCOORDINATES_ON


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
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
				float4 ase_texcoord2 : TEXCOORD2;
				float4 ase_texcoord3 : TEXCOORD3;
				float4 ase_texcoord4 : TEXCOORD4;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _NoiseColourA;
			float4 _NoiseColourB;
			float4 _NoiseOffset;
			float4 _NoiseAnimation;
			float3 _NoiseTiling;
			float _InnerMaskRadius;
			float _OuterMaskPower;
			float _OuterMaskFeather;
			float _OuterMaskRadius;
			float _NoiseColourGradientPower;
			float _NoiseRemapToMaxAlpha;
			float _NoiseRemapToMin;
			float _NoiseRemapFromMax;
			float _NoisePolarCoordinatesTwist;
			float _NoisePower;
			float _InnerMaskFeather;
			float _NoiseDilation;
			float _NoiseOctaves;
			float _NoiseScale;
			float _NoiseParallaxOffset;
			float _NoiseColourGradientRemapMax;
			float _NoiseColourGradientRemapMin;
			float _NoiseRemapFromMin;
			float _InnerMaskPower;
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

				float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
				o.ase_texcoord1.xyz = ase_worldTangent;
				float3 ase_worldNormal = TransformObjectToWorldNormal(v.normalOS);
				o.ase_texcoord2.xyz = ase_worldNormal;
				float ase_vertexTangentSign = v.ase_tangent.w * ( unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0 );
				float3 ase_worldBitangent = cross( ase_worldNormal, ase_worldTangent ) * ase_vertexTangentSign;
				o.ase_texcoord3.xyz = ase_worldBitangent;
				float3 ase_worldPos = TransformObjectToWorld( (v.positionOS).xyz );
				o.ase_texcoord4.xyz = ase_worldPos;
				
				o.ase_texcoord.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord.zw = 0;
				o.ase_texcoord1.w = 0;
				o.ase_texcoord2.w = 0;
				o.ase_texcoord3.w = 0;
				o.ase_texcoord4.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

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

			half4 frag(VertexOutput IN ) : SV_TARGET
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				float2 texCoord11_g67 = IN.ase_texcoord.xy * float2( 2,2 ) + float2( -1,-1 );
				float temp_output_7_0_g67 = ( 1.0 - length( texCoord11_g67 ) );
				float temp_output_6_0_g67 = ( 1.0 - _OuterMaskRadius );
				float temp_output_1_0_g69 = temp_output_6_0_g67;
				float lerpResult5_g67 = lerp( temp_output_6_0_g67 , 1.0 , _OuterMaskFeather);
				float smoothstepResult22_g70 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g67 - temp_output_1_0_g69 ) / ( lerpResult5_g67 - temp_output_1_0_g69 ) ) ) , _OuterMaskPower ));
				float Mask22 = smoothstepResult22_g70;
				float localSimplexNoise_Caustics_float2_g48 = ( 0.0 );
				float2 texCoord140 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float3 ase_worldTangent = IN.ase_texcoord1.xyz;
				float3 ase_worldNormal = IN.ase_texcoord2.xyz;
				float3 ase_worldBitangent = IN.ase_texcoord3.xyz;
				float3 tanToWorld0 = float3( ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x );
				float3 tanToWorld1 = float3( ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y );
				float3 tanToWorld2 = float3( ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z );
				float3 ase_worldPos = IN.ase_texcoord4.xyz;
				float3 ase_worldViewDir = ( _WorldSpaceCameraPos.xyz - ase_worldPos );
				ase_worldViewDir = normalize(ase_worldViewDir);
				float3 ase_tanViewDir =  tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y  + tanToWorld2 * ase_worldViewDir.z;
				ase_tanViewDir = normalize(ase_tanViewDir);
				float3x3 ase_worldToTangent = float3x3(ase_worldTangent,ase_worldBitangent,ase_worldNormal);
				float3 worldToTangentDir18_g1 = mul( ase_worldToTangent, ase_worldNormal);
				float dotResult15_g1 = dot( ase_tanViewDir , worldToTangentDir18_g1 );
				float3 Parallax_Offset_UV141 = ( float3( texCoord140 ,  0.0 ) + ( -( ase_tanViewDir / dotResult15_g1 ) * _NoiseParallaxOffset ) );
				float4 temp_output_10_0_g45 = ( float4( ( Parallax_Offset_UV141 * _NoiseScale * _NoiseTiling ) , 0.0 ) - ( _NoiseOffset + ( _NoiseAnimation * _TimeParameters.x ) ) );
				float3 temp_output_34_0 = (temp_output_10_0_g45).xyz;
				float3 position2_g48 = temp_output_34_0;
				float angle2_g48 = (temp_output_10_0_g45).w;
				float octaves2_g48 = _NoiseOctaves;
				float gradientStrength2_g48 = _NoiseDilation;
				float noise2_g48 = 0.0;
				float3 gradient2_g48 = float3( 0,0,0 );
				SimplexNoise_Caustics_float( position2_g48 , angle2_g48 , octaves2_g48 , gradientStrength2_g48 , noise2_g48 , gradient2_g48 );
				float temp_output_112_0 = noise2_g48;
				float localSimplexNoise_Caustics_PolarCoordinates_float2_g62 = ( 0.0 );
				float localTwistY_float2_g47 = ( 0.0 );
				float2 position2_g47 = ( Parallax_Offset_UV141 - float3( 0.5,0.5,0 ) ).xy;
				float2 center2_g47 = float2( 0,0 );
				float twist2_g47 = radians( _NoisePolarCoordinatesTwist );
				float2 output2_g47 = float2( 0,0 );
				TwistY_float( position2_g47 , center2_g47 , twist2_g47 , output2_g47 );
				float3 position2_g62 = float3( output2_g47 ,  0.0 );
				float octaves2_g62 = _NoiseOctaves;
				float gradientStrength2_g62 = _NoiseDilation;
				float scale2_g62 = _NoiseScale;
				float3 tiling2_g62 = _NoiseTiling;
				float4 animation2_g62 = _NoiseAnimation;
				float4 offset2_g62 = _NoiseOffset;
				float time2_g62 = _TimeParameters.x;
				#ifdef _NOISESIMPLEPOLARCOORDINATES_ON
				float staticSwitch150 = (float)1;
				#else
				float staticSwitch150 = (float)0;
				#endif
				float simplePolarCoordinates2_g62 = (float)(int)staticSwitch150;
				float noise2_g62 = 0.0;
				float3 gradient2_g62 = float3( 0,0,0 );
				SimplexNoise_Caustics_PolarCoordinates_float( position2_g62 , octaves2_g62 , gradientStrength2_g62 , scale2_g62 , tiling2_g62 , animation2_g62 , offset2_g62 , time2_g62 , simplePolarCoordinates2_g62 , noise2_g62 , gradient2_g62 );
				#ifdef _NOISEPOLARCOORDINATES_ON
				float staticSwitch146 = noise2_g62;
				#else
				float staticSwitch146 = temp_output_112_0;
				#endif
				float Noise39 = (_NoiseRemapToMin + (pow( staticSwitch146 , _NoisePower ) - _NoiseRemapFromMin) * (_NoiseRemapToMaxAlpha - _NoiseRemapToMin) / (_NoiseRemapFromMax - _NoiseRemapFromMin));
				float3 Parallax_Offset_UV_Centered135 = (Parallax_Offset_UV141*2.0 + -1.0);
				float temp_output_7_0_g63 = ( 1.0 - length( Parallax_Offset_UV_Centered135.xy ) );
				float temp_output_6_0_g63 = ( 1.0 - _InnerMaskRadius );
				float temp_output_1_0_g65 = temp_output_6_0_g63;
				float lerpResult5_g63 = lerp( temp_output_6_0_g63 , 1.0 , _InnerMaskFeather);
				float smoothstepResult22_g66 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g63 - temp_output_1_0_g65 ) / ( lerpResult5_g63 - temp_output_1_0_g65 ) ) ) , _InnerMaskPower ));
				float Mask_Inner105 = smoothstepResult22_g66;
				float temp_output_80_0 = ( Mask22 * saturate( ( Noise39 - Mask_Inner105 ) ) );
				float Alpha77 = temp_output_80_0;
				

				surfaceDescription.Alpha = Alpha77;
				surfaceDescription.AlphaClipThreshold = 0.5;

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
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_SRP_VERSION 140011


			
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

			#include "../../VFXToolkit/Shaders/_Includes/Noise.cginc"
			#include "../../VFXToolkit/Shaders/_Includes/Transform.cginc"
			#define ASE_NEEDS_VERT_NORMAL
			#pragma shader_feature_local _NOISEPOLARCOORDINATES_ON
			#pragma shader_feature_local _NOISESIMPLEPOLARCOORDINATES_ON


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
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
				float4 ase_texcoord2 : TEXCOORD2;
				float4 ase_texcoord3 : TEXCOORD3;
				float4 ase_texcoord4 : TEXCOORD4;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _NoiseColourA;
			float4 _NoiseColourB;
			float4 _NoiseOffset;
			float4 _NoiseAnimation;
			float3 _NoiseTiling;
			float _InnerMaskRadius;
			float _OuterMaskPower;
			float _OuterMaskFeather;
			float _OuterMaskRadius;
			float _NoiseColourGradientPower;
			float _NoiseRemapToMaxAlpha;
			float _NoiseRemapToMin;
			float _NoiseRemapFromMax;
			float _NoisePolarCoordinatesTwist;
			float _NoisePower;
			float _InnerMaskFeather;
			float _NoiseDilation;
			float _NoiseOctaves;
			float _NoiseScale;
			float _NoiseParallaxOffset;
			float _NoiseColourGradientRemapMax;
			float _NoiseColourGradientRemapMin;
			float _NoiseRemapFromMin;
			float _InnerMaskPower;
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

				float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
				o.ase_texcoord1.xyz = ase_worldTangent;
				float3 ase_worldNormal = TransformObjectToWorldNormal(v.normalOS);
				o.ase_texcoord2.xyz = ase_worldNormal;
				float ase_vertexTangentSign = v.ase_tangent.w * ( unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0 );
				float3 ase_worldBitangent = cross( ase_worldNormal, ase_worldTangent ) * ase_vertexTangentSign;
				o.ase_texcoord3.xyz = ase_worldBitangent;
				float3 ase_worldPos = TransformObjectToWorld( (v.positionOS).xyz );
				o.ase_texcoord4.xyz = ase_worldPos;
				
				o.ase_texcoord.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord.zw = 0;
				o.ase_texcoord1.w = 0;
				o.ase_texcoord2.w = 0;
				o.ase_texcoord3.w = 0;
				o.ase_texcoord4.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

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

			half4 frag(VertexOutput IN ) : SV_TARGET
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				float2 texCoord11_g67 = IN.ase_texcoord.xy * float2( 2,2 ) + float2( -1,-1 );
				float temp_output_7_0_g67 = ( 1.0 - length( texCoord11_g67 ) );
				float temp_output_6_0_g67 = ( 1.0 - _OuterMaskRadius );
				float temp_output_1_0_g69 = temp_output_6_0_g67;
				float lerpResult5_g67 = lerp( temp_output_6_0_g67 , 1.0 , _OuterMaskFeather);
				float smoothstepResult22_g70 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g67 - temp_output_1_0_g69 ) / ( lerpResult5_g67 - temp_output_1_0_g69 ) ) ) , _OuterMaskPower ));
				float Mask22 = smoothstepResult22_g70;
				float localSimplexNoise_Caustics_float2_g48 = ( 0.0 );
				float2 texCoord140 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float3 ase_worldTangent = IN.ase_texcoord1.xyz;
				float3 ase_worldNormal = IN.ase_texcoord2.xyz;
				float3 ase_worldBitangent = IN.ase_texcoord3.xyz;
				float3 tanToWorld0 = float3( ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x );
				float3 tanToWorld1 = float3( ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y );
				float3 tanToWorld2 = float3( ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z );
				float3 ase_worldPos = IN.ase_texcoord4.xyz;
				float3 ase_worldViewDir = ( _WorldSpaceCameraPos.xyz - ase_worldPos );
				ase_worldViewDir = normalize(ase_worldViewDir);
				float3 ase_tanViewDir =  tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y  + tanToWorld2 * ase_worldViewDir.z;
				ase_tanViewDir = normalize(ase_tanViewDir);
				float3x3 ase_worldToTangent = float3x3(ase_worldTangent,ase_worldBitangent,ase_worldNormal);
				float3 worldToTangentDir18_g1 = mul( ase_worldToTangent, ase_worldNormal);
				float dotResult15_g1 = dot( ase_tanViewDir , worldToTangentDir18_g1 );
				float3 Parallax_Offset_UV141 = ( float3( texCoord140 ,  0.0 ) + ( -( ase_tanViewDir / dotResult15_g1 ) * _NoiseParallaxOffset ) );
				float4 temp_output_10_0_g45 = ( float4( ( Parallax_Offset_UV141 * _NoiseScale * _NoiseTiling ) , 0.0 ) - ( _NoiseOffset + ( _NoiseAnimation * _TimeParameters.x ) ) );
				float3 temp_output_34_0 = (temp_output_10_0_g45).xyz;
				float3 position2_g48 = temp_output_34_0;
				float angle2_g48 = (temp_output_10_0_g45).w;
				float octaves2_g48 = _NoiseOctaves;
				float gradientStrength2_g48 = _NoiseDilation;
				float noise2_g48 = 0.0;
				float3 gradient2_g48 = float3( 0,0,0 );
				SimplexNoise_Caustics_float( position2_g48 , angle2_g48 , octaves2_g48 , gradientStrength2_g48 , noise2_g48 , gradient2_g48 );
				float temp_output_112_0 = noise2_g48;
				float localSimplexNoise_Caustics_PolarCoordinates_float2_g62 = ( 0.0 );
				float localTwistY_float2_g47 = ( 0.0 );
				float2 position2_g47 = ( Parallax_Offset_UV141 - float3( 0.5,0.5,0 ) ).xy;
				float2 center2_g47 = float2( 0,0 );
				float twist2_g47 = radians( _NoisePolarCoordinatesTwist );
				float2 output2_g47 = float2( 0,0 );
				TwistY_float( position2_g47 , center2_g47 , twist2_g47 , output2_g47 );
				float3 position2_g62 = float3( output2_g47 ,  0.0 );
				float octaves2_g62 = _NoiseOctaves;
				float gradientStrength2_g62 = _NoiseDilation;
				float scale2_g62 = _NoiseScale;
				float3 tiling2_g62 = _NoiseTiling;
				float4 animation2_g62 = _NoiseAnimation;
				float4 offset2_g62 = _NoiseOffset;
				float time2_g62 = _TimeParameters.x;
				#ifdef _NOISESIMPLEPOLARCOORDINATES_ON
				float staticSwitch150 = (float)1;
				#else
				float staticSwitch150 = (float)0;
				#endif
				float simplePolarCoordinates2_g62 = (float)(int)staticSwitch150;
				float noise2_g62 = 0.0;
				float3 gradient2_g62 = float3( 0,0,0 );
				SimplexNoise_Caustics_PolarCoordinates_float( position2_g62 , octaves2_g62 , gradientStrength2_g62 , scale2_g62 , tiling2_g62 , animation2_g62 , offset2_g62 , time2_g62 , simplePolarCoordinates2_g62 , noise2_g62 , gradient2_g62 );
				#ifdef _NOISEPOLARCOORDINATES_ON
				float staticSwitch146 = noise2_g62;
				#else
				float staticSwitch146 = temp_output_112_0;
				#endif
				float Noise39 = (_NoiseRemapToMin + (pow( staticSwitch146 , _NoisePower ) - _NoiseRemapFromMin) * (_NoiseRemapToMaxAlpha - _NoiseRemapToMin) / (_NoiseRemapFromMax - _NoiseRemapFromMin));
				float3 Parallax_Offset_UV_Centered135 = (Parallax_Offset_UV141*2.0 + -1.0);
				float temp_output_7_0_g63 = ( 1.0 - length( Parallax_Offset_UV_Centered135.xy ) );
				float temp_output_6_0_g63 = ( 1.0 - _InnerMaskRadius );
				float temp_output_1_0_g65 = temp_output_6_0_g63;
				float lerpResult5_g63 = lerp( temp_output_6_0_g63 , 1.0 , _InnerMaskFeather);
				float smoothstepResult22_g66 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g63 - temp_output_1_0_g65 ) / ( lerpResult5_g63 - temp_output_1_0_g65 ) ) ) , _InnerMaskPower ));
				float Mask_Inner105 = smoothstepResult22_g66;
				float temp_output_80_0 = ( Mask22 * saturate( ( Noise39 - Mask_Inner105 ) ) );
				float Alpha77 = temp_output_80_0;
				

				surfaceDescription.Alpha = Alpha77;
				surfaceDescription.AlphaClipThreshold = 0.5;

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
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_SRP_VERSION 140011


			
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

			#include "../../VFXToolkit/Shaders/_Includes/Noise.cginc"
			#include "../../VFXToolkit/Shaders/_Includes/Transform.cginc"
			#define ASE_NEEDS_VERT_NORMAL
			#pragma shader_feature_local _NOISEPOLARCOORDINATES_ON
			#pragma shader_feature_local _NOISESIMPLEPOLARCOORDINATES_ON


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
				float3 normalWS : TEXCOORD1;
				float4 ase_texcoord2 : TEXCOORD2;
				float4 ase_texcoord3 : TEXCOORD3;
				float4 ase_texcoord4 : TEXCOORD4;
				float4 ase_texcoord5 : TEXCOORD5;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _NoiseColourA;
			float4 _NoiseColourB;
			float4 _NoiseOffset;
			float4 _NoiseAnimation;
			float3 _NoiseTiling;
			float _InnerMaskRadius;
			float _OuterMaskPower;
			float _OuterMaskFeather;
			float _OuterMaskRadius;
			float _NoiseColourGradientPower;
			float _NoiseRemapToMaxAlpha;
			float _NoiseRemapToMin;
			float _NoiseRemapFromMax;
			float _NoisePolarCoordinatesTwist;
			float _NoisePower;
			float _InnerMaskFeather;
			float _NoiseDilation;
			float _NoiseOctaves;
			float _NoiseScale;
			float _NoiseParallaxOffset;
			float _NoiseColourGradientRemapMax;
			float _NoiseColourGradientRemapMin;
			float _NoiseRemapFromMin;
			float _InnerMaskPower;
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

				float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
				o.ase_texcoord3.xyz = ase_worldTangent;
				float3 ase_worldNormal = TransformObjectToWorldNormal(v.normalOS);
				float ase_vertexTangentSign = v.ase_tangent.w * ( unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0 );
				float3 ase_worldBitangent = cross( ase_worldNormal, ase_worldTangent ) * ase_vertexTangentSign;
				o.ase_texcoord4.xyz = ase_worldBitangent;
				float3 ase_worldPos = TransformObjectToWorld( (v.positionOS).xyz );
				o.ase_texcoord5.xyz = ase_worldPos;
				
				o.ase_texcoord2.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord2.zw = 0;
				o.ase_texcoord3.w = 0;
				o.ase_texcoord4.w = 0;
				o.ase_texcoord5.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

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

			void frag( VertexOutput IN
				, out half4 outNormalWS : SV_Target0
			#ifdef _WRITE_RENDERING_LAYERS
				, out float4 outRenderingLayers : SV_Target1
			#endif
				 )
			{
				float4 ClipPos = IN.clipPosV;
				float4 ScreenPos = ComputeScreenPos( IN.clipPosV );

				float2 texCoord11_g67 = IN.ase_texcoord2.xy * float2( 2,2 ) + float2( -1,-1 );
				float temp_output_7_0_g67 = ( 1.0 - length( texCoord11_g67 ) );
				float temp_output_6_0_g67 = ( 1.0 - _OuterMaskRadius );
				float temp_output_1_0_g69 = temp_output_6_0_g67;
				float lerpResult5_g67 = lerp( temp_output_6_0_g67 , 1.0 , _OuterMaskFeather);
				float smoothstepResult22_g70 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g67 - temp_output_1_0_g69 ) / ( lerpResult5_g67 - temp_output_1_0_g69 ) ) ) , _OuterMaskPower ));
				float Mask22 = smoothstepResult22_g70;
				float localSimplexNoise_Caustics_float2_g48 = ( 0.0 );
				float2 texCoord140 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float3 ase_worldTangent = IN.ase_texcoord3.xyz;
				float3 ase_worldBitangent = IN.ase_texcoord4.xyz;
				float3 tanToWorld0 = float3( ase_worldTangent.x, ase_worldBitangent.x, IN.clipPosV.xyz.x );
				float3 tanToWorld1 = float3( ase_worldTangent.y, ase_worldBitangent.y, IN.clipPosV.xyz.y );
				float3 tanToWorld2 = float3( ase_worldTangent.z, ase_worldBitangent.z, IN.clipPosV.xyz.z );
				float3 ase_worldPos = IN.ase_texcoord5.xyz;
				float3 ase_worldViewDir = ( _WorldSpaceCameraPos.xyz - ase_worldPos );
				ase_worldViewDir = normalize(ase_worldViewDir);
				float3 ase_tanViewDir =  tanToWorld0 * ase_worldViewDir.x + tanToWorld1 * ase_worldViewDir.y  + tanToWorld2 * ase_worldViewDir.z;
				ase_tanViewDir = normalize(ase_tanViewDir);
				float3x3 ase_worldToTangent = float3x3(ase_worldTangent,ase_worldBitangent,IN.clipPosV.xyz);
				float3 worldToTangentDir18_g1 = mul( ase_worldToTangent, IN.clipPosV.xyz);
				float dotResult15_g1 = dot( ase_tanViewDir , worldToTangentDir18_g1 );
				float3 Parallax_Offset_UV141 = ( float3( texCoord140 ,  0.0 ) + ( -( ase_tanViewDir / dotResult15_g1 ) * _NoiseParallaxOffset ) );
				float4 temp_output_10_0_g45 = ( float4( ( Parallax_Offset_UV141 * _NoiseScale * _NoiseTiling ) , 0.0 ) - ( _NoiseOffset + ( _NoiseAnimation * _TimeParameters.x ) ) );
				float3 temp_output_34_0 = (temp_output_10_0_g45).xyz;
				float3 position2_g48 = temp_output_34_0;
				float angle2_g48 = (temp_output_10_0_g45).w;
				float octaves2_g48 = _NoiseOctaves;
				float gradientStrength2_g48 = _NoiseDilation;
				float noise2_g48 = 0.0;
				float3 gradient2_g48 = float3( 0,0,0 );
				SimplexNoise_Caustics_float( position2_g48 , angle2_g48 , octaves2_g48 , gradientStrength2_g48 , noise2_g48 , gradient2_g48 );
				float temp_output_112_0 = noise2_g48;
				float localSimplexNoise_Caustics_PolarCoordinates_float2_g62 = ( 0.0 );
				float localTwistY_float2_g47 = ( 0.0 );
				float2 position2_g47 = ( Parallax_Offset_UV141 - float3( 0.5,0.5,0 ) ).xy;
				float2 center2_g47 = float2( 0,0 );
				float twist2_g47 = radians( _NoisePolarCoordinatesTwist );
				float2 output2_g47 = float2( 0,0 );
				TwistY_float( position2_g47 , center2_g47 , twist2_g47 , output2_g47 );
				float3 position2_g62 = float3( output2_g47 ,  0.0 );
				float octaves2_g62 = _NoiseOctaves;
				float gradientStrength2_g62 = _NoiseDilation;
				float scale2_g62 = _NoiseScale;
				float3 tiling2_g62 = _NoiseTiling;
				float4 animation2_g62 = _NoiseAnimation;
				float4 offset2_g62 = _NoiseOffset;
				float time2_g62 = _TimeParameters.x;
				#ifdef _NOISESIMPLEPOLARCOORDINATES_ON
				float staticSwitch150 = (float)1;
				#else
				float staticSwitch150 = (float)0;
				#endif
				float simplePolarCoordinates2_g62 = (float)(int)staticSwitch150;
				float noise2_g62 = 0.0;
				float3 gradient2_g62 = float3( 0,0,0 );
				SimplexNoise_Caustics_PolarCoordinates_float( position2_g62 , octaves2_g62 , gradientStrength2_g62 , scale2_g62 , tiling2_g62 , animation2_g62 , offset2_g62 , time2_g62 , simplePolarCoordinates2_g62 , noise2_g62 , gradient2_g62 );
				#ifdef _NOISEPOLARCOORDINATES_ON
				float staticSwitch146 = noise2_g62;
				#else
				float staticSwitch146 = temp_output_112_0;
				#endif
				float Noise39 = (_NoiseRemapToMin + (pow( staticSwitch146 , _NoisePower ) - _NoiseRemapFromMin) * (_NoiseRemapToMaxAlpha - _NoiseRemapToMin) / (_NoiseRemapFromMax - _NoiseRemapFromMin));
				float3 Parallax_Offset_UV_Centered135 = (Parallax_Offset_UV141*2.0 + -1.0);
				float temp_output_7_0_g63 = ( 1.0 - length( Parallax_Offset_UV_Centered135.xy ) );
				float temp_output_6_0_g63 = ( 1.0 - _InnerMaskRadius );
				float temp_output_1_0_g65 = temp_output_6_0_g63;
				float lerpResult5_g63 = lerp( temp_output_6_0_g63 , 1.0 , _InnerMaskFeather);
				float smoothstepResult22_g66 = smoothstep( 0.0 , 1.0 , pow( saturate( ( ( temp_output_7_0_g63 - temp_output_1_0_g65 ) / ( lerpResult5_g63 - temp_output_1_0_g65 ) ) ) , _InnerMaskPower ));
				float Mask_Inner105 = smoothstepResult22_g66;
				float temp_output_80_0 = ( Mask22 * saturate( ( Noise39 - Mask_Inner105 ) ) );
				float Alpha77 = temp_output_80_0;
				

				float Alpha = Alpha77;
				float AlphaClipThreshold = 0.5;

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
Node;AmplifyShaderEditor.RangedFloatNode;50;-2944,-1152;Inherit;False;Property;_NoiseParallaxOffset;Noise Parallax Offset;15;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;140;-2944,-1280;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.FunctionNode;49;-2688,-1152;Inherit;False;Parallax Offset;-1;;1;66d259709a71255489a93d3df825942b;3,20,1,16,0,9,0;1;13;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;138;-2432,-1280;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;141;-2304,-1280;Inherit;False;Parallax Offset UV;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;143;-1920,-256;Inherit;False;141;Parallax Offset UV;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;36;-1920,-128;Inherit;False;Property;_NoiseScale;Noise Scale;11;0;Create;True;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.Vector3Node;44;-1920,-48;Inherit;False;Property;_NoiseTiling;Noise Tiling;12;0;Create;True;0;0;0;False;0;False;1,1,1;1,1,1;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.Vector4Node;37;-1920,112;Inherit;False;Property;_NoiseAnimation;Noise Animation;13;0;Create;True;0;0;0;False;0;False;0,0,0,0;0,0,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector4Node;48;-1920,288;Inherit;False;Property;_NoiseOffset;Noise Offset;14;0;Create;True;0;0;0;False;0;False;0,0,0,0;0,0,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleSubtractOpNode;118;-1536,-512;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0.5,0.5,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;124;-1536,-384;Inherit;False;Property;_NoisePolarCoordinatesTwist;Noise Polar Coordinates Twist;20;0;Create;True;0;0;0;False;0;False;0;0;-720;720;0;1;FLOAT;0
Node;AmplifyShaderEditor.IntNode;153;-1536,208;Inherit;False;Constant;_Int0;Int 0;27;0;Create;True;0;0;0;False;0;False;0;0;False;0;1;INT;0
Node;AmplifyShaderEditor.IntNode;154;-1536,288;Inherit;False;Constant;_Int1;Int 0;27;0;Create;True;0;0;0;False;0;False;1;0;False;0;1;INT;0
Node;AmplifyShaderEditor.GetLocalVarNode;142;-2944,-1024;Inherit;False;141;Parallax Offset UV;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.FunctionNode;34;-1280,-128;Inherit;False;Scale Tiling Offset Animation;-1;;45;650501f4d90f3194eb72a847e06cc2e3;1,21,0;6;4;FLOAT3;0,0,0;False;7;FLOAT;1;False;8;FLOAT3;1,1,1;False;9;FLOAT4;0,0,0,0;False;19;INT;0;False;12;FLOAT4;0,0,0,0;False;2;FLOAT3;0;FLOAT;15
Node;AmplifyShaderEditor.RangedFloatNode;53;-1280,400;Inherit;False;Property;_NoiseDilation;Noise Dilation;17;0;Create;True;0;0;0;False;0;False;0.01;0.01;0;0.1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;52;-1280,320;Inherit;False;Property;_NoiseOctaves;Noise Octaves;16;1;[IntRange];Create;True;0;0;0;False;0;False;1;1;0;5;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;125;-1152,-512;Inherit;False;TwistY;-1;;47;f01b2afddc7faff458daf44b17435f3b;0;3;3;FLOAT2;0,0;False;5;FLOAT2;0,0;False;4;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleTimeNode;117;-1280,128;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.StaticSwitch;150;-1280,208;Inherit;False;Property;_NoiseSimplePolarCoordinates;Noise Simple Polar Coordinates;19;0;Create;True;0;0;0;False;0;False;0;0;0;True;;Toggle;2;Key0;Key1;Create;True;True;All;9;1;FLOAT;0;False;0;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT;0;False;7;FLOAT;0;False;8;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;139;-2688,-1024;Inherit;False;3;0;FLOAT3;0,0,0;False;1;FLOAT;2;False;2;FLOAT;-1;False;1;FLOAT3;0
Node;AmplifyShaderEditor.FunctionNode;112;-768,-128;Inherit;False;Simplex Noise Caustics;-1;;48;477e7c249263854458b4f42934448d42;0;4;4;FLOAT3;0,0,0;False;6;FLOAT;0;False;7;FLOAT;1;False;9;FLOAT;0.01;False;2;FLOAT;0;FLOAT3;3
Node;AmplifyShaderEditor.RegisterLocalVarNode;135;-2304,-1024;Inherit;False;Parallax Offset UV Centered;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.CommentaryNode;145;-1920,-1072;Inherit;False;454.8589;131.3558;Second mask SHOULD be parallax'd to be at the pattern itself.;1;136;;1,1,1,1;0;0
Node;AmplifyShaderEditor.FunctionNode;163;-768,-512;Inherit;False;Simplex Noise Caustics Polar Coordinates;-1;;62;4803721f0eb13d54e8865e59d932ac6f;0;9;4;FLOAT3;0,0,0;False;10;FLOAT;0;False;11;FLOAT3;1,1,1;False;12;FLOAT4;0,0,0,0;False;13;FLOAT4;0,0,0,0;False;14;FLOAT;0;False;15;INT;0;False;7;FLOAT;1;False;9;FLOAT;0.01;False;2;FLOAT;0;FLOAT3;3
Node;AmplifyShaderEditor.StaticSwitch;146;-256,-256;Inherit;False;Property;_NoisePolarCoordinates;Noise Polar Coordinates;18;0;Create;True;0;0;0;False;0;False;0;0;0;True;;Toggle;2;Key0;Key1;Create;True;True;All;9;1;FLOAT;0;False;0;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT;0;False;7;FLOAT;0;False;8;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;136;-1792,-1024;Inherit;False;135;Parallax Offset UV Centered;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;55;-768,32;Inherit;False;Property;_NoisePower;Noise Power;21;0;Create;True;0;0;0;False;0;False;1;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;98;-1792,-896;Inherit;False;Property;_InnerMaskRadius;Inner Mask Radius;3;0;Create;True;0;0;0;False;0;False;0;0;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;99;-1792,-816;Inherit;False;Property;_InnerMaskFeather;Inner Mask Feather;4;0;Create;True;0;0;0;False;0;False;0.5;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;100;-1280,-1024;Inherit;False;Radial Gradient 2;-1;;63;969db7e12a1ad8c4c8b8d89670372700;1,12,0;3;10;FLOAT2;0,0;False;8;FLOAT;0.5;False;9;FLOAT;0.1;False;1;FLOAT;0
Node;AmplifyShaderEditor.PowerNode;54;128,-128;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;60;-768,128;Inherit;False;Property;_NoiseRemapFromMin;Noise Remap From Min;22;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;61;-768,208;Inherit;False;Property;_NoiseRemapFromMax;Noise Remap From Max;23;0;Create;True;0;0;0;False;0;False;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;62;-768,288;Inherit;False;Property;_NoiseRemapToMin;Noise Remap To Min;24;0;Create;True;0;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;85;-768,368;Inherit;False;Property;_NoiseRemapToMaxAlpha;Noise Remap To Max (Alpha);25;0;Create;True;0;0;0;False;0;False;1;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;101;-1280,-864;Inherit;False;Property;_InnerMaskPower;Inner Mask Power;5;0;Create;True;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;59;384,-128;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;12;-1792,-1280;Inherit;False;Property;_OuterMaskRadius;Outer Mask Radius;0;0;Create;True;0;0;0;False;0;False;0.9;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;13;-1792,-1200;Inherit;False;Property;_OuterMaskFeather;Outer Mask Feather;1;0;Create;True;0;0;0;False;0;False;0.1;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;102;-768,-1024;Inherit;False;Power Smoothstep;-1;;66;eaa8bfb6a4986cb418a1675cea297eed;0;4;20;FLOAT;1;False;4;FLOAT;1;False;7;FLOAT;0;False;23;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;32;-1280,-1408;Inherit;False;Radial Gradient 2;-1;;67;969db7e12a1ad8c4c8b8d89670372700;1,12,0;3;10;FLOAT2;0,0;False;8;FLOAT;0.5;False;9;FLOAT;0.1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;39;640,-128;Inherit;False;Noise;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;19;-1280,-1248;Inherit;False;Property;_OuterMaskPower;Outer Mask Power;2;0;Create;True;0;0;0;False;0;False;5;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;105;-384,-1024;Inherit;False;Mask Inner;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;79;-2432,2432;Inherit;False;39;Noise;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;107;-2432,2528;Inherit;False;105;Mask Inner;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;86;-768,-1408;Inherit;False;Power Smoothstep;-1;;70;eaa8bfb6a4986cb418a1675cea297eed;0;4;20;FLOAT;1;False;4;FLOAT;1;False;7;FLOAT;0;False;23;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;106;-2176,2432;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;22;-384,-1408;Inherit;False;Mask;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;73;-2176,2304;Inherit;False;22;Mask;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;108;-1920,2432;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;80;-1664,2224;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;77;-1024,2224;Inherit;False;Alpha;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TexturePropertyNode;156;-1280,-1664;Inherit;True;Property;_NoiseTexture;Noise Texture;9;2;[NoScaleOffset];[SingleLineTexture];Create;True;0;0;0;False;0;False;None;None;False;white;Auto;Texture2D;-1;0;2;SAMPLER2D;0;SAMPLERSTATE;1
Node;AmplifyShaderEditor.RegisterLocalVarNode;157;-1024,-1664;Inherit;False;Noise Texture;-1;True;1;0;SAMPLER2D;;False;1;SAMPLER2D;0
Node;AmplifyShaderEditor.GetLocalVarNode;159;-1536,640;Inherit;False;157;Noise Texture;1;0;OBJECT;;False;1;SAMPLER2D;0
Node;AmplifyShaderEditor.SamplerNode;158;-768,640;Inherit;True;Property;_TextureSample0;Texture Sample 0;28;0;Create;True;0;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.StaticSwitch;161;-256,640;Inherit;False;Property;_UseNoiseTexture;Use Noise Texture;10;0;Create;True;0;0;0;False;0;False;0;0;0;True;;Toggle;2;Key0;Key1;Create;True;True;All;9;1;FLOAT;0;False;0;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT;0;False;7;FLOAT;0;False;8;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;87;-1920,1152;Inherit;False;Property;_BackplateColour;Backplate Colour;6;0;Create;True;0;0;0;False;0;False;0,0,0,0;0,0,0,1;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.RegisterLocalVarNode;93;-1536,1232;Inherit;False;Backplate Alpha;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;96;-1664,2432;Inherit;False;93;Backplate Alpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;89;-1280,2304;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;1;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;84;-1920,2048;Inherit;False;Property;_NoiseColourGradientRemapMax;Noise Colour Gradient Remap Max;28;0;Create;True;0;0;0;False;0;False;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;82;-1920,1888;Inherit;False;Property;_NoiseColourGradientPower;Noise Colour Gradient Power;26;0;Create;True;0;0;0;False;0;False;1;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;83;-1920,1968;Inherit;False;Property;_NoiseColourGradientRemapMin;Noise Colour Gradient Remap Min;27;0;Create;True;0;0;0;False;0;False;0;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;75;-1536,1408;Inherit;False;Colour RGB x A;-1;;71;034d6205f93eb7e4f9100dabf18de7c4;0;1;22;COLOR;1,1,1,0.5019608;False;1;FLOAT3;0
Node;AmplifyShaderEditor.FunctionNode;76;-1536,1488;Inherit;False;Colour RGB x A;-1;;72;034d6205f93eb7e4f9100dabf18de7c4;0;1;22;COLOR;1,1,1,0.5019608;False;1;FLOAT3;0
Node;AmplifyShaderEditor.FunctionNode;81;-1280,1792;Inherit;False;Power Smoothstep;-1;;73;eaa8bfb6a4986cb418a1675cea297eed;0;4;20;FLOAT;1;False;4;FLOAT;1;False;7;FLOAT;0;False;23;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;23;-1920,1792;Inherit;False;39;Noise;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;90;-1536,1152;Inherit;False;Backplate RGB;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.LerpOp;65;-896,1536;Inherit;False;3;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;29;-256,1536;Inherit;False;Colour;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;95;-896,1408;Inherit;False;90;Backplate RGB;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;109;-1280,1936;Inherit;False;93;Backplate Alpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;110;-1024,1936;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;111;-512,1408;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.LerpOp;88;-512,1664;Inherit;False;3;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;78;128,1104;Inherit;False;77;Alpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;30;128,1024;Inherit;False;29;Colour;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.FunctionNode;162;-1152,640;Inherit;False;Polar Coordinates;-1;;74;7dab8e02884cf104ebefaa2e788e4162;0;4;1;FLOAT2;0,0;False;2;FLOAT2;0.5,0.5;False;3;FLOAT;1;False;4;FLOAT;1;False;3;FLOAT2;0;FLOAT;55;FLOAT;56
Node;AmplifyShaderEditor.LerpOp;160;-256,512;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;24;-1920,1408;Inherit;False;Property;_NoiseColourA;Noise Colour A;7;1;[HDR];Create;True;0;0;0;False;0;False;1,1,1,1;1,1,1,1;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.ColorNode;66;-1920,1600;Inherit;False;Property;_NoiseColourB;Noise Colour B;8;1;[HDR];Create;True;0;0;0;False;0;False;1,1,1,1;1,1,1,1;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;-896,-1408;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ExtraPrePass;0;0;ExtraPrePass;5;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;0;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;2;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ShadowCaster;0;2;ShadowCaster;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;False;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=ShadowCaster;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;3;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthOnly;0;3;DepthOnly;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;True;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;False;False;True;1;LightMode=DepthOnly;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;4;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;Meta;0;4;Meta;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Meta;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;5;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;Universal2D;0;5;Universal2D;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=Universal2D;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;6;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;SceneSelectionPass;0;6;SceneSelectionPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=SceneSelectionPass;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;7;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ScenePickingPass;0;7;ScenePickingPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Picking;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;8;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthNormals;0;8;DepthNormals;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=DepthNormalsOnly;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;9;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthNormalsOnly;0;9;DepthNormalsOnly;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=DepthNormalsOnly;False;True;9;d3d11;metal;vulkan;xboxone;xboxseries;playstation;ps4;ps5;switch;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;1;512,1024;Float;False;True;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;Portal Noise;2992e84f91cbeb14eab234972e07ea9d;True;Forward;0;1;Forward;8;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;2;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;True;1;5;False;;10;False;;1;1;False;;10;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;2;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=UniversalForwardOnly;False;False;0;;0;0;Standard;22;Surface;1;638666119554491752;  Blend;0;0;Two Sided;0;638666123377285247;Forward Only;0;0;Cast Shadows;0;638666123337185133;  Use Shadow Threshold;0;0;Receive Shadows;0;638666123355270459;GPU Instancing;1;0;LOD CrossFade;1;0;Built-in Fog;1;0;Meta Pass;0;0;Extra Pre Pass;0;0;Tessellation;0;0;  Phong;0;0;  Strength;0.5,False,;0;  Type;0;0;  Tess;16,False,;0;  Min;10,False,;0;  Max;25,False,;0;  Edge Length;16,False,;0;  Max Displacement;25,False,;0;Vertex Position,InvertActionOnDeselection;1;0;0;10;False;True;False;True;False;False;True;True;True;False;False;;False;0
Node;AmplifyShaderEditor.CommentaryNode;144;-1920,-1408;Inherit;False;388.0717;100;First mask should NOT be parallax'd. It's the frame.;0;;1,1,1,1;0;0
WireConnection;49;13;50;0
WireConnection;138;0;140;0
WireConnection;138;1;49;0
WireConnection;141;0;138;0
WireConnection;118;0;143;0
WireConnection;34;4;143;0
WireConnection;34;7;36;0
WireConnection;34;8;44;0
WireConnection;34;9;37;0
WireConnection;34;12;48;0
WireConnection;125;3;118;0
WireConnection;125;4;124;0
WireConnection;150;1;153;0
WireConnection;150;0;154;0
WireConnection;139;0;142;0
WireConnection;112;4;34;0
WireConnection;112;6;34;15
WireConnection;112;7;52;0
WireConnection;112;9;53;0
WireConnection;135;0;139;0
WireConnection;163;4;125;0
WireConnection;163;10;36;0
WireConnection;163;11;44;0
WireConnection;163;12;37;0
WireConnection;163;13;48;0
WireConnection;163;14;117;0
WireConnection;163;15;150;0
WireConnection;163;7;52;0
WireConnection;163;9;53;0
WireConnection;146;1;112;0
WireConnection;146;0;163;0
WireConnection;100;10;136;0
WireConnection;100;8;98;0
WireConnection;100;9;99;0
WireConnection;54;0;146;0
WireConnection;54;1;55;0
WireConnection;59;0;54;0
WireConnection;59;1;60;0
WireConnection;59;2;61;0
WireConnection;59;3;62;0
WireConnection;59;4;85;0
WireConnection;102;20;100;0
WireConnection;102;4;101;0
WireConnection;32;8;12;0
WireConnection;32;9;13;0
WireConnection;39;0;59;0
WireConnection;105;0;102;0
WireConnection;86;20;32;0
WireConnection;86;4;19;0
WireConnection;106;0;79;0
WireConnection;106;1;107;0
WireConnection;22;0;86;0
WireConnection;108;0;106;0
WireConnection;80;0;73;0
WireConnection;80;1;108;0
WireConnection;77;0;80;0
WireConnection;157;0;156;0
WireConnection;158;0;159;0
WireConnection;158;1;34;0
WireConnection;161;1;146;0
WireConnection;161;0;158;1
WireConnection;93;0;87;4
WireConnection;89;0;80;0
WireConnection;89;1;73;0
WireConnection;89;2;96;0
WireConnection;75;22;24;0
WireConnection;76;22;66;0
WireConnection;81;20;23;0
WireConnection;81;4;82;0
WireConnection;81;7;83;0
WireConnection;81;23;84;0
WireConnection;90;0;87;5
WireConnection;65;0;75;0
WireConnection;65;1;76;0
WireConnection;65;2;81;0
WireConnection;29;0;65;0
WireConnection;110;0;109;0
WireConnection;111;0;95;0
WireConnection;111;1;65;0
WireConnection;88;0;95;0
WireConnection;88;1;65;0
WireConnection;88;2;81;0
WireConnection;160;0;112;0
WireConnection;160;1;158;1
WireConnection;1;2;30;0
WireConnection;1;3;78;0
ASEEND*/
//CHKSM=D6FC6F37CF585BD993BB2E847CC39462E04122A4