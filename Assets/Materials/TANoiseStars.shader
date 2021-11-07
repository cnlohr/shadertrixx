// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/TANoiseStars"
{
    Properties
    {
        _TANoiseTex ("Texture", 2D) = "white" {}
    }	
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
 
        Pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 pos : TEXCOORD1;
				float3 worldspace : TEXCOORD2;
				float3 normal : TEXCOORD3;
            };

			#include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
				o.pos = v.vertex.xyz/v.vertex.w;
                o.uv = TRANSFORM_TEX(v.uv, _TANoiseTex);
				o.worldspace = mul( unity_ObjectToWorld, v.vertex );
				o.normal = mul ((float4x4)unity_ObjectToWorld, v.normal );
                return o;
            }


            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
				fixed4 col = 0.0;
				float3 pos = i.worldspace;
				float3 normal = normalize( i.normal.xyz );

				float3 noisevec = normalize( normalize(i.worldspace.xyz - _WorldSpaceCameraPos.xyz) + normalize(normal.xyz)*.1 );
				noisevec *= 8. * _ScreenParams.x;
				col = tanoise3_1d( noisevec/200. ) * 0.3 +
				//tanoise3_1d( noisevec/230. ) * 0.3 +
				//tanoise3_1d( noisevec/100. ) * 0.3 +
				tanoise3_1d( noisevec/30. ) * 1.5 +
				tanoise3( noisevec/40. ) * .05;
				return col*6-9.0;
            }
            ENDCG
			
			Cull Front
        }
    }
}
