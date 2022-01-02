Shader "cnlohr/ExposeCubemap"
{
	Properties
	{
		_ViewNormalLerp( "View Normal Lerp", float ) = 0.0
		[Toggle(USE_CUSTOM_CUBE_MAP)] USE_CUSTOM_CUBE_MAP( "Use Custom Cube Map", int ) = 0
		
		_customCubeMap ("Texture", CUBE) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }

		Pass
		{
			CGPROGRAM
			#pragma target 5.0
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"


			#pragma shader_feature_local USE_CUSTOM_CUBE_MAP
			
			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				float3 worldNormal : NORMAL;
				float3 worldView : TEXCOORD2;
			};
			
			UNITY_DECLARE_TEXCUBE( _customCubeMap );
			float _ViewNormalLerp;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = mul( unity_ObjectToWorld, v.normal );
				o.worldView = mul( unity_ObjectToWorld, v.vertex ).xyz - _WorldSpaceCameraPos;

				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			float4 frag (v2f i) : SV_Target
			{
				float perspectiveDivide = 1.0f / i.vertex.w;

				// I personally avoid UnityWorldSpaceViewDir because it seems to be just a littttle bit wrong on the edges of the screen.
				float3 worldViewDir = i.worldView * perspectiveDivide;  
				float3 worldRefl = reflect(worldViewDir, i.worldNormal);
				
				// Scale our view ray to unit depth.
				float3 direction = lerp( worldViewDir, worldRefl, _ViewNormalLerp );
				
				#ifdef USE_CUSTOM_CUBE_MAP
				float4 col = UNITY_SAMPLE_TEXCUBE(_customCubeMap, direction);
				#else
				float4 col = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, direction);
				#endif
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
