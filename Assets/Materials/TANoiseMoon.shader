// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/3DRockTexture"
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

			#include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"

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

				col = tanoise4_1d( float4( pos.xyz*20., _Time.y/5. ) ) * 0.5 +
				tanoise4_1d( float4( pos.xyz*40.1, _Time.y/5. ) ) * 0.3 +
				tanoise4_1d( float4( pos.xyz*80.2, _Time.y/5. ) ) * 0.2 +
				tanoise4_1d( float4( pos.xyz*320.5, _Time.y/5. ) ) * 0.1 +
				tanoise4_1d( float4( pos.xyz*641., _Time.y/5. ) ) * .05 +
				tanoise4_1d( float4( pos.xyz*1282., _Time.y/5. ) ) * .03;
				col = pow( col, 1.8)+0.1;

                return fixed4( col.xyz*(-i.normal.zzz*0.6+0.5), 1. );
            }
            ENDCG
        }
    }
}
