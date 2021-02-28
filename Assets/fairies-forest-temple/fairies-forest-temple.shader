Shader "Custom/fairies-forest-temple"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_TANoiseTex ("TANoise", 2D) = "white" {}
		_TrackDownUp ("Track Up Down", float) = 0.0
		_BillboardSizeAdd ("Billboard Size", float ) = 0.25
		_Halftoney ("Halftoniness", int) = 1
		_HalftoneyIntensity("Halftoney Intensity", float) = 0
		
		_FlySpeed("FlySpeed", float)=1.0
		_FlapSpeed("FlapSpeed", float)=1.0
		_FlapRand("Flap Randomize", float)=1.0
		_FlyMuxX ("FlyMux X", float)=1.0
		_FlyMuxY ("FlyMux Y", float)=1.0
		_FlyMuxZ ("FlyMux Z", float)=1.0
		_WingsSize ("Wings Size", float)=2.0
		

		_WingAngle("Wing Angle", float) = 1.
		_FairyColor1 ("FairyColor1", Color) = (1,1,1,1)
		_FairyColor2 ("FairyColor2", Color) = (1,1,1,1)
		_UseBaseColorness ("Use Base Color (0..1)", float) = 1.
		
		_GlowFlutterSpeed ("Glow Flutter Speed", float) = 1.
		_GlowFlutterAmount ("Glow Flutter Amount", float) = 1.
		_GlowAmount ("Glow Base Amount", float) = 1.
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			AlphaToMask On 
			Cull Off
			CGPROGRAM


			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"

			#include "../tanoise/tanoise.cginc"

			#ifndef glsl_mod
			#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y)))) 
			#endif


			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 debug : TEXCOORD1;
				float4 rcuvmix : TEXCOORD2;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				
				float4 thiscolor : TEXCOORD3;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _TrackDownUp;
			float _BillboardSizeAdd;
			float _HalftoneyPow;
			int _Halftoney;
			fixed _HalftoneyIntensity;
			float4 _FairyColor1;
			float4 _FairyColor2;
			float _WingAngle;
			float _FlySpeed;
			float _FlyMuxX;
			float _FlyMuxY;
			float _FlyMuxZ;
			float _WingsSize;
			float _FlapSpeed;
			float _FlapRand;
			float _UseBaseColorness;
			float _GlowFlutterSpeed;
			float _GlowFlutterAmount;
			float _GlowAmount;


			v2f vert (appdata v)
			{
				v2f o;

				//Flip along X because wing is on wrong side.
				float2 uvtex = v.uv;
				uvtex.x = 1.-uvtex.x;
				o.uv = TRANSFORM_TEX(uvtex, _MainTex);

				//TODO: Uncollapse -> This is NOT how the final shader will work.
				float3 localOffset = (floor( v.vertex * 100. + 0.5 ) )/100.; //Where it should center around.

				float2 rcuv = v.uv * 2.0 - 1.0;
				float4 vout = 0.;
				
				//Wander around.
				float3 FlyMux = float3( _FlyMuxX, _FlyMuxY, _FlyMuxZ );
				float3 positional_offset = (tanoise2_hq( float2( v.uv1.x*100, _Time.y*_FlySpeed ) )-0.5)*FlyMux;
				float3 positional_offset_future = (tanoise2_hq( float2( v.uv1.x*100, _Time.y*_FlySpeed+0.2 ) )-0.5)*FlyMux;
				float3 direction = positional_offset_future - positional_offset;
				localOffset += positional_offset;
				
				
				if( v.uv1.y < 0.3 )
				{
					//Main body
					
					float3 worldpos = mul(  unity_ObjectToWorld, localOffset );
					float3 hitvworld = _WorldSpaceCameraPos - worldpos;
					float3 viewangle = normalize( hitvworld );
					float3 down = float3( 0, -1, 0 );
					float3 left = normalize( cross( down, viewangle ) );
					
					//If we want to keep it pointed straight at the camera, do this, otherwise,
					//use real up.
					float3 ldown = cross( viewangle, left );
					
					float3 usedown = lerp( down, ldown, _TrackDownUp );

					float3 BillboardVertex = 
						worldpos +
							( 
								float4(rcuv.x * left, 0 ) +
								float4(rcuv.y * usedown, 0 ) 
							) * _BillboardSizeAdd;
					vout = mul( UNITY_MATRIX_VP, float4( BillboardVertex, 1.0 ) );
					
					//vout = 0.; //disable
					o.rcuvmix = float4( rcuv, 1.0, 
						tanoise2( float2( _Time.w * _GlowFlutterSpeed, v.uv1.x*100 ) ).x*_GlowFlutterAmount+_GlowAmount
					);
					
				}
				else
				{
					float rotationangle = atan2(-direction.x,direction.z)+3.14159;
					
					float flutterdist = 0.5;
					float flutter = tanoise2( float2( _Time.w * _FlapSpeed, v.uv1.x*100 ) )*_FlapRand;
					flutter += (_Time.w * _FlapSpeed + v.uv1.x*100);
					float wingrotation = ((v.uv1.y < 0.7)?-1:1)*(sin(flutter)+1.5)*flutterdist;

					float3 localVert = float3(
						v.uv.x*sin(wingrotation),
						( v.uv.y-0.4 ),
						v.uv.x*cos(wingrotation) )*.001;

					float c, s;
					c = cos(_WingAngle);
					s = sin(_WingAngle);
					localVert.yz = mul( localVert.yz, float2x2(c,s,-s,c) );
					c = cos(rotationangle);
					s = sin(rotationangle);
					localVert.xz = mul( localVert.xz, float2x2(c,s,-s,c) );

					
					vout = UnityObjectToClipPos(localOffset + localVert*_BillboardSizeAdd*20.);
					
					o.rcuvmix = float4( 
						rcuv,
						0.0,
						1. );
					
				}
				
				float phase = v.uv1.x*1000.+_Time.y;
				o.thiscolor = float4(
					sin(phase+0)+.8,
					sin(phase+2.09)+.8,
					sin(phase+4.18)+.8, 1. );
				
				o.vertex = vout;
				o.debug = float4( v.uv1, 0., 1. );
				UNITY_TRANSFER_FOG(o,vout);
				return o;
			}

			fixed4 frag (v2f i, float4 screenSpace : SV_Position) : SV_Target
			{
				// sample the texture
				float inten = tex2D(_MainTex, i.uv).r;

				inten = lerp( inten, 0.9-length( i.rcuvmix.xy ), i.rcuvmix.z ); 
				inten *= i.rcuvmix.w;
				inten = (inten>0.0)?sqrt( inten ):0.0;
				
				//Tricky: add i.rcuvmix.zz so we can dither separately.
				uint2 ss =  (screenSpace.xy+i.rcuvmix.zz) / _Halftoney;
				uint sv = ( ss.x % 2 ) + ( ( ss.x ^ ss.y ) % 2 ) * 2;
				float isp = sv / 4. + _HalftoneyIntensity;

				float4 BaseColor = lerp(_FairyColor1, _FairyColor2, inten);
				
				BaseColor = lerp( i.thiscolor, BaseColor, _UseBaseColorness );
				
				BaseColor = lerp( 1.,BaseColor,i.rcuvmix.z );
                float4 col = BaseColor * float4( 1., 1., 1., (inten>isp)?1.0 : 0.0 );

				//Todo: Fix for Quest.
				if( col.a < 0.5 ) discard;

				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
