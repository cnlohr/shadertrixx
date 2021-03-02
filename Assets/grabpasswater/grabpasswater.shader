Shader "Unlit/grabpasswater"
{
	Properties
	{
		_WaterNorm ("Normal Texture", 2D) = "white" {}
		_WaterNormalDeflection ("Normal Deflection Amount", float) = 0.01
		_RefractionAmount ("Index of Refraction", float) = .3
		_WaterNormScale( "Water Norm Scale", float ) = 1.
		_DepthMargin ("Depth Margin", float ) = 2.
	}
	SubShader
	{
		// Draw ourselves after all opaque geometry
		Tags {
			"RenderType" = "Transparent"
			"Queue" = "Transparent-10"
			"IgnoreProjector" = "True"
			"IsEmissive" = "true"
		}

		GrabPass
		{
			"_BackgroundTexture"
		}

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
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				float3 ssnormalcalc : TEXCOORD5;
				float3 worldPos : TEXCOORD4;
			};

			sampler2D _WaterNorm;
			float4 _WaterNorm_ST;
			float _WaterNormalDeflection;
			float _RefractionAmount;
			float _WaterNormScale;
			float _DepthMargin;
			sampler2D _BackgroundTexture;
			sampler2D _CameraDepthTexture;

			//General notes: lukis101 has a totally different approach to calculating depth here:
			//https://github.com/lukis101/VRCUnityStuffs/blob/master/Shaders/DJL/Overlays/WorldPosOblique.shader
			//But it feels more complicated, and amounts to slightly more assembly instructions in the fragment shader.
			//
			// NOTES: Why don't se use? 				//float2  screenPosNormalized = scrPos.xy/scrPos.w; (With VS from:    o.scrPos = ComputeScreenPos(o.vertex); )
			// 			Why don't we have to add + _ProjectionParams.y to fix the 

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul (unity_ObjectToWorld, v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _WaterNorm);
				o.ssnormalcalc =  UnityObjectToClipPos(v.vertex + v.normal);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			//Todo:
			//  1: Do refraction.
			//  2: Surface effects (Reflection)
			//		* Reflection probe
			//		* Screen space reflections.
			//  3: Fog
			//  4: Working from underneath.


			float GrabDepthAtPoint( float2 place )
			{
				//NOTE: This function returns back a vector in non-normalized space, like if you were to shoot a ray through
				// a screen in front of your face.
				//
				//In order to normalize it you should multiply it by: length( (i.worldPos - _WorldSpaceCameraPos)/ i.vertex.w )
				//
				// TODO: Why don't we need + _ProjectionParams.y;?  It should be on near plane but appears to be incorrect.
				return DECODE_EYEDEPTH( SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, place ) );

				//Also FYI: Potentially useful: depth in frustum.
				//float3  worldPosOfGeoAtGrab = _WorldSpaceCameraPos + viewWithPerspectiveDivide * GrabDepthAtPoint(...);
			}

			fixed4 frag (v2f i) : SV_Target
			{
				//From https://github.com/lukis101/VRCUnityStuffs/blob/master/Shaders/DJL/Overlays/WorldPosOblique.shader as well.
				float perspectiveDivide = 1.0f / i.vertex.w;
				float3	viewVector = i.worldPos - _WorldSpaceCameraPos;

				//This makes it not normalized, vectors toward the edges are longer than toward the center.
				float3	viewWithPerspectiveDivide = viewVector * perspectiveDivide;
				float	depthTextureCorrectionFactor = length( viewWithPerspectiveDivide );
				float2  screenPosNormalized = i.vertex.xy/_ScreenParams.xy; //0..1 across view
				float   distanceToSurfaceOfWater = length( i.worldPos - _WorldSpaceCameraPos );
				float 	depthAtGrab = depthTextureCorrectionFactor * GrabDepthAtPoint( screenPosNormalized ); 
				float   distanceBeyondWater = depthAtGrab - distanceToSurfaceOfWater;
				float3  surfaceNormal = normalize( tex2D( _WaterNorm, i.uv * _WaterNormScale + _Time.y * float2( .2, .3 ) )+ tex2D( _WaterNorm, -i.uv * _WaterNormScale * 2. + _Time.y * float2( .15, -.4 ) ) - 0.5 );

				//float2 screenSpaceNormalDeflection = i.ssnormalcalc.xy * perspectiveDivide / 2.0 + 0.5;///_ScreenParams.xy;
				//screenSpaceNormalDeflection.y = 1. - screenSpaceNormalDeflection.y;
				//screenSpaceNormalDeflection = screenSpaceNormalDeflection - screenPosNormalized;
				//How to compute refraction vector?
				//return float4( screenSpaceNormalDeflection, 0., 1. );
				//return  float4( i.worldPos.xz - _WorldSpaceCameraPos.xz, 0., 1. );
				
				//return float4( i.ssnormalcalc.xyz, 1. );
				//float2 refractionVector = (i.ssnormalcalc.xyz).xy*.00;
				//surfaceNormal += (i.ssnormalcalc.xyz)*-.05;

				float deferAmount = distanceBeyondWater * (20./depthAtGrab);

				float2  deflectionVector = surfaceNormal.xy * deferAmount * _WaterNormalDeflection;// + refractionVector * distanceBeyondWater * _RefractionAmount;
				float2  thisUV = screenPosNormalized + deflectionVector;

				//Potentially select a different pixel, so we don't bleed people in front of the water.
				int j;
				for( j = 0; j < 5; j++ )
				{
					float thisDepth = depthTextureCorrectionFactor * GrabDepthAtPoint( thisUV ); 
					float thisDistanceBeyondWater = thisDepth - distanceToSurfaceOfWater;
					if( thisDistanceBeyondWater > 0. && thisDistanceBeyondWater > depthAtGrab - distanceToSurfaceOfWater - _DepthMargin  ) break;
					thisUV -= deflectionVector / 5.;
				}

				fixed4 col = tex2D( _BackgroundTexture, thisUV );
					
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
