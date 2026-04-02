
Shader "My/Sun Corona"
{
	Properties
	{
		_CoronaNoise("Corona Noise Map", 2D) = "black" {}  

		_DischargeTileX("Discharge Tile X", float) = 0
		_DischargeTileY("Discharge Tile Y", float) = 0
		_DischargePanSpeed("Discharge Pan Speed", float) = 0		

		_CoronaFluidTile("Corona Fluid Tile", float) = 0
		_CoronaFluidInfluence("Corona Fluid Influence", float) = 0

		_SolarStormFalloff("Solar Storm Falloff", float) = 0
		_SolarStormPower("Solar Storm Power", float) = 0

		_CoronaTileX("Corona Tile X", float) = 0
		_CoronaTileY("Corona Tile Y", float) = 0
		_CoronaSpeed("Corona Speed", float) = 0
		_CoronaAmp("Corona Amp", float) = 0
		_CoronaExp("Corona Exp", float) = 0
		_CoronaBoost("Corona Boost", float) = 0
		_CoronaFalloff("Corona Falloff", float) = 0

		_CoronaColor("Corona Color", Color) = (0.5,0.5,0.5,0.5)

		_InvFade ("Fade Factor", float) = 1.0

		// Stencil
		_StencilRef("Stencil Ref", Range(0, 255)) = 0
		[Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp", Float) = 8
		[Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass", Float) = 0
		[Enum(UnityEngine.Rendering.StencilOp)] _StencilFail("Stencil Fail", Float) = 0
		[Enum(UnityEngine.Rendering.StencilOp)] _StencilZFail("Stencil ZFail", Float) = 0
		_StencilReadMask("Stencil Read Mask", Range(0, 255)) = 255
		_StencilWriteMask("Stencil Write Mask", Range(0, 255)) = 255

		// Render Queue Offset
		[HideInInspector] _QueueOffset("Queue Offset", Float) = 0.0
	}

	SubShader
	{
		Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }

		Blend One One
		ColorMask RGB
		Cull Off
		ZWrite Off

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
			Name "SunCorona"
			Tags { "LightMode"="UniversalForward" }

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

			CBUFFER_START(UnityPerMaterial)
				float _DischargeTileX, _DischargeTileY, _DischargePanSpeed;
				float _CoronaFluidTile, _CoronaFluidInfluence;
				float _SolarStormFalloff, _SolarStormPower;
				float _CoronaTileX, _CoronaTileY, _CoronaSpeed, _CoronaAmp, _CoronaExp, _CoronaBoost, _CoronaFalloff;
				float4 _CoronaColor;
				float _InvFade;
			CBUFFER_END

			TEXTURE2D(_CoronaNoise);
			SAMPLER(sampler_CoronaNoise);

			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 color : COLOR;
				float2 texcoord0 : TEXCOORD0;
			};

			struct VertexOutput
			{
				float4 pos : SV_POSITION;
				float4 color : COLOR;
				float4 posWorld : TEXCOORD0;
				float3 normalDir : TEXCOORD1;
				float2 uv : TEXCOORD2;
				float4 screenPos : TEXCOORD3;
			};

			VertexOutput vert(VertexInput v)
			{
				VertexOutput o = (VertexOutput)0;

				// Billboard: 用观察空间的 right/up 轴重建顶点位置
				float3 centerWS = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;

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

				o.posWorld = float4(billboardWS, 1);
				o.pos = mul(UNITY_MATRIX_VP, float4(billboardWS, 1));
				o.normalDir = mul((float3x3)unity_ObjectToWorld, v.normal);
				o.uv = v.texcoord0;
				o.screenPos = ComputeScreenPos(o.pos);
				o.color = v.color;
				return o;
			}

			float2 PolarCood(float2 uv, float xTile, float yTile)
			{
				float2 uvScaled = uv - 1;
				float2 uvMult = pow(uvScaled, 2);
				float a1 = sqrt(uvMult.x + uvMult.y);
				float a2 = -atan2(uvScaled.y, uvScaled.x);

				float twoPI = 3.142 * 2;

				float2 uvOut;

				if(a2 >= 0.0) uvOut.x = a2 / twoPI;
				else uvOut.x = (a2 + twoPI) / twoPI;

				uvOut.x *= xTile;
				uvOut.y = a1 * yTile;

				return uvOut;
			}

			float2 Panner(float2 uv, float speedX, float speedY, float t)
			{
				return float2(uv.x + speedX * t, uv.y + speedY * t);
			}

			float2 Rotator(float2 uv, float speed)
			{
				uv -= 0.5;

				float s = sin(speed);
				float c = cos(speed);

				float2x2 rotationMatrix = float2x2(c, -s, s, c);
				rotationMatrix *= 0.5;
				rotationMatrix += 0.5;
				rotationMatrix = rotationMatrix * 2 - 1;
				uv = mul(uv, rotationMatrix);
				uv += 0.5;

				return uv;
			}

			float CoronaMask(float2 _uv, float sizeX, float sizeY, float power, float falloff)
			{
				float2 uv = pow(_uv - 0.5, 2);
				uv.x *= sizeX;
				uv.y *= sizeY;
				float mask = 1 - pow(sqrt(uv.x + uv.y) * power, falloff);
				return clamp(mask, 0, 1);
			}

			half4 frag(VertexOutput i) : SV_Target
			{
				float2 uvA = PolarCood(i.uv * 2, _DischargeTileX * 0.5, _DischargeTileY * 0.5);
				float2 uvB = PolarCood(i.uv * 2, _DischargeTileX, _DischargeTileY);
				float2 uvC = PolarCood(i.uv * 2, _CoronaTileX, _CoronaTileY);

				uvA = Panner(uvA, 0, -1, _DischargePanSpeed * _Time.x);
				uvB = Panner(uvB, 0, -1, _DischargePanSpeed * _Time.x);
				uvC = Panner(uvC, 0, -1, _CoronaSpeed * _Time.x);

				float cNoiseA = SAMPLE_TEXTURE2D(_CoronaNoise, sampler_CoronaNoise, uvA).g;
				float cNoiseC = SAMPLE_TEXTURE2D(_CoronaNoise, sampler_CoronaNoise, Rotator(i.uv * _CoronaFluidTile * 4, 0.2 * _Time.x)).r * _CoronaFluidInfluence;
				float cNoiseB = SAMPLE_TEXTURE2D(_CoronaNoise, sampler_CoronaNoise, uvB + cNoiseC).r;
				float cNoiseD = SAMPLE_TEXTURE2D(_CoronaNoise, sampler_CoronaNoise, uvC).g;

				float sStorm = pow(cNoiseA * cNoiseB, _SolarStormFalloff) * _SolarStormPower;
				float corona = pow(cNoiseD * _CoronaAmp, _CoronaExp);

				float cMaskA = (1 - CoronaMask(i.uv, 1, 1, 4, 3)) * 3.5;
				float cMaskB = CoronaMask(i.uv, 1, 1, 2.25, 0.01) * cMaskA * _CoronaBoost;
				cMaskB = clamp(pow(cMaskB, _CoronaFalloff), 0, 1);
				corona += cMaskB;

				float cMaskC = clamp(CoronaMask(i.uv, 0.65, 0.65, 3.75, 3), 0, 1);

				float cNoiseE = pow(SAMPLE_TEXTURE2D(_CoronaNoise, sampler_CoronaNoise, Rotator(i.uv * 2, 4)).r, 1.25) * 2 * cMaskC;

				float3 finalColor = float3(corona.xxx + sStorm * cNoiseE) * _CoronaColor.rgb * 5;

				// Soft particle fade (URP depth)
				float2 screenUV = i.screenPos.xy / i.screenPos.w;
				float sceneDepth = LinearEyeDepth(SampleSceneDepth(screenUV), _ZBufferParams);
				float thisDepth = LinearEyeDepth(i.pos.z, _ZBufferParams);
				float fade = saturate(_InvFade * (sceneDepth - thisDepth));
				float alpha = i.color.a * fade;

				return half4(finalColor * cMaskB * alpha, 1);
				//return half4(cNoiseA.xxx, 1);
			}

			ENDHLSL
		}
	}

	Fallback Off
}
