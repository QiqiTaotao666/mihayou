Shader "My/MaskBlended"
{
	Properties
	{
		[HDR]_TintColor("Color", Color) = (1,1,1,1)
		_MainTex ("Texture", 2D) = "white" {}
		[Space]
		[Space]
		[Space]
		[Toggle(USE_CUTOUT)] _UseCutout("Use Cutout", Int) = 0
		_MaskTex ("MaskTexture", 2D) = "white" {}
		_MaskCutout("MaskCutout", Range(0,1)) = .5
		[Space]
		[Space]
		[Space]
		_Thickness("Border Thickness", Range(0,.3)) = .05
		[HDR]_ThicknessColor("TBorder Color", Color) = (1,1,1,1)
		[Space]
		[Space]
		[Space]
		_AlphaPow("Alpha Pow", Float) = 1
		_AlphaMul("Alpha Mul", Float) = 1
		[Space]
		[Space]
		[Header(Stencil)]
		_StencilRef("Stencil Ref", Range(0, 255)) = 0
		[Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp", Float) = 8
		[Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass", Float) = 0
		[Enum(UnityEngine.Rendering.StencilOp)] _StencilFail("Stencil Fail", Float) = 0
		[Enum(UnityEngine.Rendering.StencilOp)] _StencilZFail("Stencil ZFail", Float) = 0
		_StencilReadMask("Stencil Read Mask", Range(0, 255)) = 255
		_StencilWriteMask("Stencil Write Mask", Range(0, 255)) = 255
		[Space]
		[Space]
		[Header(Render Queue)]
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
		_QueueOffset("Queue Offset", Float) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" "Queue"="Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha
		Cull Off
		ZWrite Off
		ZTest [_ZTest]

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
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature USE_CUTOUT// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"
			sampler2D _MainTex;
			sampler2D _MaskTex;
			float _MaskCutout;
			float4 _MainTex_ST;
			float4 _MaskTex_ST;
			float4 _TintColor;
			float _Thickness;
			float4 _ThicknessColor;
			float _AlphaPow;
			float _AlphaMul;
			
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 color : COLOR0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float2 maskUV: TEXCOORD1;
				UNITY_FOG_COORDS(2)
				float4 vertex : SV_POSITION;
				float4 color : COLOR0;
			};


			v2f vert (appdata vertexInput)
			{
				v2f pixelInput;
				pixelInput.vertex = UnityObjectToClipPos(vertexInput.vertex);
				pixelInput.uv = TRANSFORM_TEX(vertexInput.uv, _MainTex);
				pixelInput.maskUV = TRANSFORM_TEX(vertexInput.uv, _MaskTex);
				UNITY_TRANSFER_FOG(pixelInput, pixelInput.vertex);
				pixelInput.color = vertexInput.color;
				return pixelInput;
			}
			
			float4 frag (v2f pixelInput) : SV_Target
			{
				// sample the texture
				float mask = 1;
			float3 border = 0;

#ifdef USE_CUTOUT
				float cutoff = 1 - _MaskCutout;
				float maskCol = tex2D(_MaskTex, pixelInput.maskUV).r;
				mask = step(cutoff, maskCol);
				float borderEdge = step(cutoff, maskCol) - step(saturate(cutoff + _Thickness), maskCol);
				border = borderEdge * _ThicknessColor.rgb;
#endif
				//return float4 (mask,border.r,0,1);

				float4 col = tex2D(_MainTex, pixelInput.uv)*_TintColor*pixelInput.color;
				col.rgb += border;
				col.a = saturate(pow(col.a, _AlphaPow) * _AlphaMul * mask);
				// apply fog
				UNITY_APPLY_FOG(pixelInput.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
