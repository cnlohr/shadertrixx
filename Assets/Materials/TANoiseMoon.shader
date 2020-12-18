// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/TANoiseMoon"
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
            // make fog work
            #pragma multi_compile_fog

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
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
				float3 pos : TEXCOORD1;
				float3 worldspace : TEXCOORD2;
				float3 normal : TEXCOORD3;
            };

            sampler2D _TANoiseTex;
			uniform half2 _TANoiseTex_TexelSize; 
            float4 _NoiseTex_ST;
			#include "../../tanoise/tanoise.cginc"
			

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
				o.pos = v.vertex.xyz/v.vertex.w;
                o.uv = TRANSFORM_TEX(v.uv, _NoiseTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
				o.worldspace = mul( unity_ObjectToWorld, v.vertex );
				o.normal = mul ((float4x4)unity_ObjectToWorld, v.normal );
                return o;
            }


            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
				fixed4 col;
				float3 pos = i.worldspace;
				float3 normal = normalize( i.normal.xyz );
				//Test 1:
#if 0
				col = 2.*tanoise4( float4(pos.xyz*20.,1.) );
				//col = pos.xyzz;
				//Test 2:
                return fixed4( col.xyz*(i.normal.zzz*0.6+0.5), 1. );
#endif
#if 0
				col = tanoise4_1d( float4( pos.xyz*40., 0.0 ) ).rrrr;
				//col += fmod( col.rrrr, 1. )*.1;
                return fixed4( col.xyz*(i.normal.zzz*0.6+0.5), 1. );
#endif
#if 1
				//Test 3: Multilayer noise.
				col = tanoise4_1d( float4( pos.xyz*20., _Time.y/5. ) ) * 0.5 +
				tanoise4_1d( float4( pos.xyz*40.1, _Time.y/5. ) ) * 0.3 +
				tanoise4_1d( float4( pos.xyz*80.2, _Time.y/5. ) ) * 0.2 +
				tanoise4_1d( float4( pos.xyz*320.5, _Time.y/5. ) ) * 0.1 +
				tanoise4_1d( float4( pos.xyz*641., _Time.y/5. ) ) * .05 +
				tanoise4_1d( float4( pos.xyz*1282., _Time.y/5. ) ) * .03;
				col = pow( col, 1.8)+0.1;
                return fixed4( col.xyz*(-i.normal.zzz*0.6+0.5), 1. );
#endif
#if 0
				col = tanoise3_1d( pos.xyz*_ScreenParams.x/200. ) * 0.3 +
				//tanoise3_1d( pos.xyz*_ScreenParams.x/230. ) * 0.3 +
				//tanoise3_1d( pos.xyz*_ScreenParams.x/100. ) * 0.3 +
				tanoise3_1d( pos.xyz*_ScreenParams.x/30. ) * 1.5 +
				tanoise3( pos.xyz*_ScreenParams.x/40. ) * .05;
#endif
				return col*6-9.0;
                //UNITY_APPLY_FOG(i.fogCoord, col);
            }
            ENDCG
			
//			Cull Front
        }
    }
}
