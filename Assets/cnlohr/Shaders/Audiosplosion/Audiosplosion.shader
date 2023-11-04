Shader "Custom/Audiosplosion"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        CGPROGRAM
		#include "UnityCG.cginc"
		#include "Autolight.cginc"
		#include "/Assets/AudioLink/Shaders/AudioLink.cginc"
	
		#pragma vertex vert
		#pragma geometry geom
		#pragma fragment frag
		#pragma multi_compile_fog
		#pragma multi_compile_fwdbase
		#pragma shader_feature IS_LIT
        #pragma multi_compile_shadowcaster
        #pragma target 5.0

        sampler2D _MainTex;
		
	
		struct appdata
		{
			float4 vertex : POSITION;
			float4 normal : NORMAL;
			float2 uv : TEXCOORD0;
		};
	
		struct v2g
		{
		        float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
		};
		struct v2g
		{
			float4 vertex : POSITION;
			float3 normal : NORMAL;
			float2 uv : TEXCOORD0;
		};
		struct g2f
		{
			float2 uv : TEXCOORD0;
			UNITY_FOG_COORDS(1)
			float4 vertex : SV_POSITION;
			float3 normal : NORMAL;
			unityShadowCoord4 _ShadowCoord : TEXCOORD1;
		};

		v2g vert (appdata v)
		{
			v2g o;
			
			//move my verts
			float4 position = v.vertex;
			position.xz *= 2 - ( abs( sin(25.13 * v.uv.x) ) );
			
			o.vertex = position;
			o.normal = v.normal;
			o.uv = TRANSFORM_TEX(v.uv, _MainTex);
			UNITY_TRANSFER_FOG(o,o.vertex);
			return o;
		}
		
		[maxvertexcount(3)]
		void geom(triangle v2g input[3], inout TriangleStream<g2f> triStream)
		{
			g2f o;
			float3 normal = normalize(cross(input[1].vertex - input[0].vertex, input[2].vertex - input[0].vertex));
			
			for(int i = 0; i < 3; i++)
			{
				float4 vert = input[i].vertex;
				o.vertex = UnityObjectToClipPos(vert);
				UNITY_TRANSFER_FOG(o,o.vertex);
				o.uv = input[i].uv;
				o.normal = UnityObjectToWorldNormal((normal));
				o._ShadowCoord = ComputeScreenPos(o.vertex);
				#if UNITY_PASS_SHADOWCASTER
				o.vertex = UnityApplyLinearShadowBias(o.vertex);
				#endif
				triStream.Append(o);
			}

			triStream.RestartStrip();
		}
		
		float4 fragShadow(g2f i) : SV_Target
		{
			SHADOW_CASTER_FRAGMENT(i)
		}   
		
        ENDCG
    }
}
