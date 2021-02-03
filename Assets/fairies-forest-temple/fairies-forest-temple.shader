Shader "Custom/fairies-forest-temple"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_TANoiseTex ("TANoise", 2D) = "white" {}
		_TrackDownUp ("Track Up Down", float) = 0.0
		_BillboardSizeAdd ("Billboard Size", float ) = 0.25
		_HalftoneyPow("Halftoney Pow", float) = 0.69
		_Halftoney ("Halftoniness", int) = 1
		_HalftoneyIntensity("Halftoney Intensity", float) = 0
		
		_FlySpeed("FlySpeed", float)=1.0
		_FlapSpeed("FlapSpeed", float)=1.0
		_FlyMuxX ("FlyMux X", float)=1.0
		_FlyMuxY ("FlyMux Y", float)=1.0
		_FlyMuxZ ("FlyMux Z", float)=1.0
		_WingsSize ("Wings Size", float)=2.0
		

		_WingAngle("Wing Angle", float) = 1.
		_FairyColor1 ("FairyColor1", Color) = (1,1,1,1)
		_FairyColor2 ("FairyColor2", Color) = (1,1,1,1)
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			AlphaToMask True 
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
			float _FlapSpeed;
			float _FlyMuxY;
			float _FlyMuxZ;
			float _WingsSize;

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
					o.rcuvmix = float4( rcuv, 1.0, 0.0 );
					
				}
				else
				{
					float rotationangle = atan2(direction.x,direction.y)+3.14159;
					
					float flutterdist = 0.5;
					float flutterspeed = _FlapSpeed;
					float flutter = _Time.w * flutterspeed + v.uv1.x*100; /*Add arbitrary phase offset*/
					float wingrotation = ((v.uv1.y < 0.7)?-1:1)*(sin(flutter)+1.5)*flutterdist;
						

					float3 localVertBehind = float3(
						v.uv.x*sin(rotationangle+wingrotation),
						v.uv.x*cos(rotationangle+wingrotation),
						( v.uv.y-0.4 ) )*.001;
					float3 localVertUp = float3(
						v.uv.x*cos(wingrotation),
						(v.uv.y-0.4)*sin(wingrotation),
						(v.uv.y-0.4)*sin(wingrotation)
						)*.001;
					float3 localVert = lerp( localVertBehind, localVertUp, 0.0 ) * _WingsSize;

/*					float c, s;
					float wingangleX = 0;//cos(rotationangle)*_WingAngle;
					float wingangleY = 0;//-sin(rotationangle)*_WingAngle;
					c = cos(wingangleX);
					s = sin(wingangleX);
					localVert.yz = mul( localVert.yz, float2x2(c,s,-s,c) );
					c = cos(wingangleY);
					s = sin(wingangleY);
					localVert.xz = mul( localVert.xz, float2x2(c,-s,s,c) );
*/
					
					vout = UnityObjectToClipPos(localOffset + localVert*_BillboardSizeAdd*20.);
					
					o.rcuvmix = float4( rcuv, 0.0, 0.0 );
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
				fixed inten = tex2D(_MainTex, i.uv).r;

				inten = lerp( inten, 0.9-length( i.rcuvmix.xy ), i.rcuvmix.z ); 
				
				inten = pow( inten, _HalftoneyPow);
				
				uint2 ss =  screenSpace.xy / _Halftoney;
				uint sv = ( ss.x % 2 ) + ( ( ss.x ^ ss.y ) % 2 ) * 2;
				float isp = sv / 4. + _HalftoneyIntensity;
				float4 BaseColor = lerp(_FairyColor1, _FairyColor2, inten);
				
				BaseColor = i.thiscolor;
				
				BaseColor = lerp( 1.,BaseColor,i.rcuvmix.z );
                float4 col = BaseColor * float4( 1., 1., 1., inten>isp );


				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
