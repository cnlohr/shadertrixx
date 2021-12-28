Shader "cnlohr/CubeTestCRT"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

	Properties
	{
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM

			#include "UnityCustomRenderTexture.cginc"
			
			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment frag
			#pragma target 5.0

			#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))
			
			#include "UnityCG.cginc"
			#include "/Assets/cnlohr/Shaders/hashwithoutsine/hashwithoutsine.cginc"
			
			fixed4 frag (v2f_customrendertexture IN) : SV_Target
			{
				return float4( normalize(IN.direction), 1. );
			}


			ENDCG
		}
	}
}
