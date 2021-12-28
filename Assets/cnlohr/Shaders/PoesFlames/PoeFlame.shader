// Billboard flame shader, safe for static, batched, instanced and stereo applications.
// Does not require any Udon 
// (C) 2020-2021 cnlohr, licensible under the MIT/x11, New BSD or CC0 licenses.

Shader "cnlohr/PoeFlame"
{
	Properties
	{
		_Color1 ("Color1", Color) = (1,1,1,1)
		_DualColorThreshold("Dual Color Threshold", float) = 0.6
		_Color2 ("Color2", Color) = (1,1,1,1)
		_MainTex ("Texture", 2D) = "white" {}
		_TANoiseTex ("TANoise", 2D) = "white" {}
		
		_FlamePositionalNoise ("Positional Noise", float) = 8.0
		_FlameSpeed ("Flame Speed", float) = 8.0
		_FlameTimeNoise ("Time Noise", float) = 1.0
		_FlameNoisyness ("Noiseyness", float ) = 1.0
		_FlameMagBase ("Magnitude", float) = 1.0
		_FlameSize ("Inverted Flame Size", float) = 1.0
		_Halftoney ("Halftoniness", int) = 1
		_Detail ("Detail", float) = 1000
		_BillboardSizeAdd ("Billboard Overall Size", float) = 1.0
		_HalftoneyIntensity("Halftoney Intensity", float) = 0
		_HalftoneyPow("Halftoney Pow", float) = 0.5
		_PhaseOffset("Phase Offset (For randomization)",float) = 0
		_UsePositionalSpaceToChangePhase( "Use Position to Permute Phase", float ) = 0


		_TrackDownUp ("Does the sprite rotate down and up to look at player", float) = 0.0
		_EyeSeparation("Make billboard point to center of face", Range( 0, 1 ) ) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Tags {"LightMode"="ForwardBase"}
			AlphaToMask True 
			//Alphatest Equal 1
	
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			// #pragma alpha 

			#include "UnityCG.cginc"

			#define glsl_mod(x,y) abs(((x)-(y)*floor((x)/(y)))) 

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 worldpos : TEXCOORD1;
				//UNITY_VERTEX_OUTPUT_STEREO
			};

			#include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color1, _Color2;
			fixed _FlamePositionalNoise;
			fixed _FlameSpeed;
			fixed _FlameTimeNoise;
			fixed _FlameNoisyness;
			fixed _FlameMagBase;
			fixed _FlameSize;
			fixed _BillboardSizeAdd;
			fixed _Detail;
			int _Halftoney;
			fixed _HalftoneyIntensity;
			fixed _HalftoneyPow;
			fixed _DualColorThreshold;
			fixed _PhaseOffset;
			fixed _TrackDownUp, _EyeSeparation;
			fixed _UsePositionalSpaceToChangePhase;

			v2f vert (appdata v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(i);
				//UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				float2 uvoff = float2(v.uv.x-.5, .5-v.uv.y);

				//Tricky: we use the big outside geometry to catch frustum culling.
				if( v.vertex.x > 1.5 )
				{
					o.vertex = 0;
					o.worldpos = 0;
					return o;
				}
	
#if defined(USING_STEREO_MATRICES)
				float3 PlayerCenterCamera = (
					float3(unity_StereoCameraToWorld[0][0][3], unity_StereoCameraToWorld[0][1][3], unity_StereoCameraToWorld[0][2][3]) +
					float3(unity_StereoCameraToWorld[1][0][3], unity_StereoCameraToWorld[1][1][3], unity_StereoCameraToWorld[1][2][3]) ) * 0.5;
#else
				float3 PlayerCenterCamera = _WorldSpaceCameraPos.xyz;
#endif
				PlayerCenterCamera = lerp( _WorldSpaceCameraPos.xyz, PlayerCenterCamera, _EyeSeparation );

				//TODO: Cross product with view angle.
				o.worldpos = mul(  unity_ObjectToWorld, v.vertex );
				float3 hitvworld = PlayerCenterCamera - o.worldpos;
				float3 viewangle = normalize( hitvworld );
				float3 down = float3( 0, -1, 0 );
				float3 left = normalize( cross( down, viewangle ) );
				
				//If we want to keep it pointed straight at the camera, do this, otherwise,
				//use real up.
				float3 ldown = cross( viewangle, left );
				
				float3 usedown = lerp( down, ldown, _TrackDownUp );

				float3 BillboardVertex = 
					o.worldpos +
						( 
							float4(uvoff.x * left, 0 ) +
							float4(uvoff.y * usedown, 0 ) 
						) * _BillboardSizeAdd;
				o.vertex = mul( UNITY_MATRIX_VP, float4( BillboardVertex, 1.0 ) );

				return o;
			}

			fixed4 frag (v2f i, float4 screenSpace : SV_Position) : SV_Target
			{
				//UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
				//We loop every 2,000 seconds, otherwise, when doing the 
				//random math, it gets yucky.
				float UseTime = frac( _Time.y/2000 ) * 2000;
				float2 iuv = floor((i.uv - 0.5) * _Detail ) / _Detail + 0.5;
				float PhaseOff = _PhaseOffset+floor((i.worldpos.x*1.5+i.worldpos.z)*_UsePositionalSpaceToChangePhase);
				float intennoise = tanoise3_1d( float3( 
					iuv.x*_FlamePositionalNoise,
					iuv.y*_FlamePositionalNoise - UseTime*_FlameSpeed,
					UseTime*_FlameTimeNoise + PhaseOff ) );
				
				//Attenuate based on Y, long tail flame, but base of flame is strong.
				float yatten = (iuv.y < 0.25 )?
					(1.-4.*(iuv.y))*2. : //Bottom part of flame
					-0.5+2.0*(iuv.y);			//Top part of flame.
				
				float xatten = length( iuv.x-0.5 )*4.;
				float attenmag = length( float2( xatten, yatten ) );
				
				float inten = _FlameMagBase - attenmag*_FlameSize + intennoise*_FlameNoisyness;
				
				// sample the texture
				fixed4 col = tex2D(_MainTex, iuv);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				
				col *= lerp( _Color1, _Color2, clamp( inten - _DualColorThreshold, 0.0, 1.0 ) );

				if( inten < 0 )
				{
					return 0.;
				}
				else
				{
					inten = pow( inten, _HalftoneyPow);
					uint2 ss =  screenSpace.xy / _Halftoney;
					uint sv = ( ss.x % 2 ) + ( ( ss.x ^ ss.y ) % 2 ) * 2;
					float isp = sv / 4. + _HalftoneyIntensity;
					return col * float4( 1., 1., 1., inten>isp );
				}
			}
			ENDCG
		}
	}
}
