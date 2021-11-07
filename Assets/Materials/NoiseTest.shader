Shader "cnlohr/NoiseTest"
{
    Properties
    {
        _TANoiseTex ("Texture", 2D) = "white" {}
        _TANoiseTexNearest ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
		
		// shadow caster rendering pass, implemented manually
		// using macros from UnityCG.cginc
		Pass
		{
			Tags {"LightMode"="ShadowCaster"}
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"

			struct v2f { 
				V2F_SHADOW_CASTER;
				float4 uv : TEXCOORD0;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				o.uv = v.texcoord;
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
		
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

			#include "/Assets/cnlohr/Shaders/hashwithoutsine/hashwithoutsine.cginc"
			#include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }


            float4 frag (v2f i) : SV_Target
            {
				float4 col = 0;
                // sample the texture
				if( i.uv.y < 0.5 )
				{
					if( i.uv.x < 0.5 )
					{
						return tasimplex3( float3( i.uv * 100, _Time.y ) ).xxxx*.5+0.5;
					}
					else
					{
						return taquicksmooth3( float3( i.uv * 100, _Time.y ) ).xxxx*.5+.5;
					}
				}
				else
				{
					if( i.uv.x < 0.5 )
					{
						col = chash42( floor(i.uv*100) );//tex2D(_MainTex, i.uv);
					}
					else
					{
						return csimplex3( float3( i.uv * 100, _Time.y ) ).xxxx*.5+0.5;
					}
				}
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
