Shader "cnlohr/grabpasswater"
{
	Properties
	{
		_WaterNorm ("Water Normal", 2D) = "white" {}
		//_TANoiseTex ("TANoise", 2D) = "white" {}
		_WaterNormalDeflection ("Normal Deflection Amount", float) = 0.01
		_RefractionAmount ("Index of Refraction", float) = .3
		_WaterNormScale( "Water Norm Scale", float ) = 1.
		_DepthMargin ("Depth Margin", float ) = 2.
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
		
		// Draw ourselves after all opaque geometry
		Tags {
			"RenderType" = "Transparent"
			"Queue" = "Transparent+10"
			"IgnoreProjector" = "True"
			"IsEmissive" = "true"
		}

		GrabPass
		{
			"_Grabpass"
		}
		Pass
		{
            Tags {"LightMode"="ForwardBase"}
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
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				float3 ssnormalcalc : TEXCOORD5;
				float3 worldPos : TEXCOORD4;
				float4 grabpos : TEXCOORD6;
				float4 screenPosition : TEXCOORD7;
			};

			sampler2D _WaterNorm;
			float4 _WaterNorm_ST;
			float _WaterNormalDeflection;
			float _RefractionAmount;
			float _WaterNormScale;
			float _DepthMargin;
			sampler2D _Grabpass;
			sampler2D _CameraDepthTexture;

			//#include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"

			v2f vert (appdata v)
			{
				UNITY_SETUP_INSTANCE_ID(i);
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul (unity_ObjectToWorld, v.vertex);
				o.uv = v.uv;
				o.ssnormalcalc =  UnityObjectToClipPos(v.vertex + v.normal);
				o.grabpos = ComputeGrabScreenPos(o.vertex);
				o.screenPosition = o.vertex;//UnityObjectToClipPos(v.vertex);
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
				return LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, place)));
			}

			fixed4 frag (v2f i) : SV_Target
			{
				// Compute projective scaling factor...
				float perspectiveDivide = 1.0f / i.screenPosition.w;

				// Calculate our UV within the screen (for reading depth buffer)
				float2 screenUV = (i.screenPosition.xy * perspectiveDivide) * 0.5f + 0.5f;
				// No idea, Seems to fix lox's stuff.
				if (_ProjectionParams.x < 0)
					screenUV.y = 1 - screenUV.y; 

				// VR stereo support
				screenUV = UnityStereoTransformScreenSpaceTex(screenUV);

				//From https://github.com/lukis101/VRCUnityStuffs/blob/master/Shaders/DJL/Overlays/WorldPosOblique.shader as well.
				float3	viewVector = i.worldPos - _WorldSpaceCameraPos;

				//This makes it not normalized, vectors toward the edges are longer than toward the center.
				float3	viewWithPerspectiveDivide = viewVector * perspectiveDivide;
				float	depthTextureCorrectionFactor = length( viewWithPerspectiveDivide );
				float   distanceToSurfaceOfWater = length( i.worldPos - _WorldSpaceCameraPos );
				float 	depthAtGrab = depthTextureCorrectionFactor * GrabDepthAtPoint( screenUV ); 
				float   distanceBeyondWater = depthAtGrab - distanceToSurfaceOfWater;
				
				float tt = frac(_Time.y/1000)*1000;
#if 0
				float2 perta = 
					abs(tanoise3_2d( float3( i.uv * _WaterNormScale, tt ) * float3( 22.2, 19.3, 1 ) )-0.5)*2 +
					abs(tanoise3_2d( float3( i.uv * _WaterNormScale, tt ) * float3( 35.2, 45.3, 1 ) )-0.5) +
					abs(tanoise3_2d( float3( i.uv * _WaterNormScale, tt ) * float3( 98.2, 80.3, 1 ) )-0.5)*.5 +
					abs(tanoise3_2d( float3( i.uv * _WaterNormScale, tt ) * float3( 198.2, 180.3, 1 ) )-0.5)*.5;

#endif
				float2  surfaceNormal = 
					//perta*.5;
					normalize( tex2D( _WaterNorm, i.uv * _WaterNormScale + _Time.y * float2( .15, .1 ) )+ tex2D( _WaterNorm, -i.uv * _WaterNormScale * 2. + _Time.y * float2( .08, -.2 ) ) - 0.5 );

				//float2 screenSpaceNormalDeflection = i.ssnormalcalc.xy * perspectiveDivide / 2.0 + 0.5;///_ScreenParams.xy;
				//screenSpaceNormalDeflection.y = 1. - screenSpaceNormalDeflection.y;
				//screenSpaceNormalDeflection = screenSpaceNormalDeflection - screenPosNormalized;
				//How to compute refraction vector?
				//return float4( screenSpaceNormalDeflection, 0., 1. );
				//return  float4( i.worldPos.xz - _WorldSpaceCameraPos.xz, 0., 1. );
				
				//return float4( i.ssnormalcalc.xyz, 1. );
				//float2 refractionVector = (i.ssnormalcalc.xyz).xy*.00;
				//surfaceNormal += (i.ssnormalcalc.xyz)*-.05;

				float deferAmount = (distanceBeyondWater) * (20/depthAtGrab) * (1+pow(distanceToSurfaceOfWater,1.2));
				
				float2  deflectionVector = surfaceNormal.xy * deferAmount * _WaterNormalDeflection;// + refractionVector * distanceBeyondWater * _RefractionAmount;
				float4  thisUV = i.grabpos + float4(deflectionVector, 0, 0);
				float2  thisScreenUV = screenUV;

				//Potentially select a different pixel, so we don't bleed people in front of the water.
#if 1
				int j;
				for( j = 0; j < 5; j++ )
				{
					float thisDepth = depthTextureCorrectionFactor * GrabDepthAtPoint( thisScreenUV ); 
					float thisDistanceBeyondWater = thisDepth - distanceToSurfaceOfWater;
					if( thisDistanceBeyondWater > 0. && distanceBeyondWater > 0 - distanceToSurfaceOfWater - _DepthMargin  ) break;
					thisUV -= float4( deflectionVector / 5., 0, 0);
					thisScreenUV -= deflectionVector / 5.;
				}
#endif
				fixed4 col = tex2Dproj( _Grabpass, thisUV);
					
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
