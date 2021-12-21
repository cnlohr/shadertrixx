Shader "Unlit/FortyPixelPrint"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
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
		
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			#pragma target 5.0

			#define DEMO_AUDIOLINK

			#ifdef DEMO_AUDIOLINK
				float2 guv;
				#include "/Assets/AudioLink/Shaders/AudioLink.cginc"
				#define FONTTHINNESS (.35-AudioLinkLerp( ALPASS_AUDIOLINK + float2( floor(guv.x) * 4, guv.y ) ).r*.5)
			#endif
			
			#include "/Assets/cnlohr/Shaders/FortyPixelPrint/FortyPixelPrint.cginc"
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
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = 0.;
				float2 uv = i.uv * float2( 1.0, 5.0 );
				#ifdef DEMO_AUDIOLINK
					float instancetime = AudioLinkDecodeDataAsSeconds( ALPASS_GENERALVU_INSTANCE_TIME );
					guv = uv*float2(7,1);
				#else
					float instancetime = _Time.y;
				#endif
				switch( floor(uv.y) )
				{
				case 0:	col.rgb = print5x7intzl( int(instancetime), uv, 7 ); break;
				case 1:	col.rgb = print5x7int( int(instancetime), uv, 7, 0 ); break;
				case 2:	col.rgb = print5x7int( int(instancetime), uv, 7, ZEROLEADBLANK ); break;
				case 3:	col.rgb = print5x7float( instancetime, uv, 3, 3 ); break;
				case 4:
				{
					uv.x *= 7;
					int cell = uv.x;
					col.rgb = char5x7( floor(instancetime+cell)%96, fmod(frac(uv)*float2(6.,8.), float2(10,10) ) ); break;
					break;
				}
				default: break;
				};
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
