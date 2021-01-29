// Upgrade NOTE: replaced tex2D unity_Lightmap with UNITY_SAMPLE_TEX2D

// Upgrade NOTE: commented out 'float4 unity_LightmapST', a built-in variable
// Upgrade NOTE: commented out 'sampler2D unity_Lightmap', a built-in variable

// Upgrade NOTE: replaced tex2D unity_Lightmap with UNITY_SAMPLE_TEX2D

// Upgrade NOTE: replaced tex2D unity_Lightmap with UNITY_SAMPLE_TEX2D

// Upgrade NOTE: commented out 'sampler2D unity_Lightmap', a built-in variable

// Upgrade NOTE: commented out 'sampler2D unity_Lightmap', a built-in variable

// could add UNITY_SHADER_NO_UPGRADE 

//UNITY_SHADER_NO_UPGRADE 

Shader "Custom/FlowingWater"
{
    Properties
    {
        _WaterBottomTex ("Bottom Surface (RGB)", 2D) = "white" {}
		_Vividity ("Vividity", float ) = 1.0
		_VividitySurface("VividitySurface", float) = 1.0
		_WaterScale ("Water Scale", float) = 20.0
		_Depth ("Depth", float) = 0.2
		_WaterSpeed( "Water Speed", float ) = 10.
		_TANoiseTex ("TANoise", 2D) = "white" {}
		_Shinyness( "Shinyness", float ) = 100.
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 100
		Pass
        {
            Tags {"LightMode"="ForwardBase"}
			

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DYNAMICLIGHTMAP_ON
			#pragma multi_compile_fwdbase
			
			
            #include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"

			#include "../tanoise/tanoise.cginc"

			#ifndef glsl_mod
			#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))
			#endif
			
            struct appdata
            {
                float4 vertex : POSITION;
				float3 normal : NORMAL;
				float3 tangent : TANGENT;
                float2 uv : TEXCOORD0;
				float2 uv1 : TEXCOORD1; //Lightmap
				float2 uv2 : TEXCOORD2; //Lightmap
				UNITY_VERTEX_INPUT_INSTANCE_ID
				
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 hitvlocal : TEXCOORD4;
				float3 worldpos : TEXCOORD2;
				float3 localnorm : NORMAL;
				float3 localtangent : TANGENT;
				
				float4 lightpos : TEXCOORD3;
				float4 debug : TEXCOORD5;
				
			
				#if defined(LIGHTMAP_ON)
					float2 uvLightStatic : TEXCOORD8;
				#endif
				#if defined( DYNAMICLIGHTMAP_ON )
					float2 uvLightDynamic : TEXCOORD9;
				#endif
            };

			
			// sampler2D unity_Lightmap;
			// float4 unity_LightmapST;
	        //half4 unity_Lightmap_ST; // Required by TRANSFORM_TEX macro
           
		   
			sampler2D _WaterBottomTex;

            float4 _WaterBottomTex_ST;
            float _Vividity, _WaterScale;
			float _VividitySurface;
			float _WaterSpeed;
			float _Depth;
			float _Shinyness;
			uniform float4 _WaterBottomTex_TexelSize;
				 
				 
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _WaterBottomTex);
				o.worldpos = mul(  unity_ObjectToWorld, v.vertex );
				o.hitvlocal = mul( unity_WorldToObject, _WorldSpaceCameraPos - o.worldpos ) ;
				o.localnorm = v.normal;
				o.localtangent = v.tangent;
				o.lightpos = mul( unity_WorldToObject, _WorldSpaceLightPos0 );
                UNITY_TRANSFER_FOG(o,o.vertex);
				
				
				#if defined(LIGHTMAP_ON)
				o.uvLightStatic = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				#endif
				#if defined( DYNAMICLIGHTMAP_ON )
				o.uvLightDynamic = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
				#endif
				o.debug = float4( v.uv2.xy, 0., 1. );
                return o;
            }
			
			#define MYtex2DMY tex2D 
			#define MY2DLM unity_Lightmap
			
			//sampler2D MY2DLM;
			
            fixed4 frag (v2f i) : SV_Target
            {
				float4 lightmux = float4( 0., 0., 0., 1. );
			#if defined(LIGHTMAP_ON)
				lightmux.rgb += DecodeLightmap (UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uvLightDynamic ));
			#endif
			#if defined( DYNAMICLIGHTMAP_ON )
				lightmux.rgb += DecodeLightmap (UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, i.uvLightDynamic ));
			#endif
			#if !defined( LIGHTMAP_ON ) && !defined( DYNAMICLIGHTMAP_ON )
				lightmux = 1.;
			#endif
			
				float3 localnorm = normalize( i.localnorm );
				float3 localtangent = normalize(i.localtangent);                        //uv.x increase [verified]
				float3 localbitangent = normalize( cross( localtangent, localnorm ) );  //uv.y increase [verified]

				float3 worldbitangent =  mul(  unity_ObjectToWorld, localbitangent );
				
				//TODO: Change incident ray based on index of refraction change.
				

				//Calculate location the ray would hit the floor of the water, then perturb from there.
				float3 world_hitray = mul(  unity_ObjectToWorld, i.hitvlocal );
				float3 norm_hitray =  normalize(i.hitvlocal);
				float3 waterfloorimpact = i.worldpos.xyz 
					+ normalize( world_hitray ) * _Depth;
				float distanceRayNeededToTravel = _Depth/dot( norm_hitray, i.localnorm );
				
				float3 noisepos = i.worldpos.xyz * _WaterScale;
				
				
				//Water direction is always in direction of increasing texture V.
				//Problem: What if worldbitangent is shifting?
				//float3 noisetime = worldbitangent * _Time.y * _WaterSpeed;  
				
				float3 noisetime = float3( 1., 1., 1. ) * _Time.y * _WaterSpeed; 

				//Originally this was the noise pos at the bottom but that's not right.
				//float3 noisepos_depth = noisepos + norm_hitray * distanceRayNeededToTravel;

				float2 tanoiseperturb = 
					tanoise3_2d( noisepos + noisetime )-0.5 + 
					(tanoise3_2d( noisepos * 2. + noisetime*2 )-0.5) / 2. + 
					(tanoise3_2d( noisepos * 4. + noisetime*4 )-0.5) / 3. + 
					(tanoise3_2d( noisepos * 8. + noisetime*8 )-0.5) / 4.;
				float3 newlocalnorm = normalize( tanoiseperturb.x*localtangent*_Vividity + tanoiseperturb.y*localbitangent*_Vividity + localnorm ) * distanceRayNeededToTravel;
				//return float4( tanoiseperturb, 0., 1. );
				//return float4( newlocalnorm, 1. );
				
				//Tricky: we want to permute the vector heading to the floor.

				float2 newuv = i.uv;

				//Next, we need to use i.hitvlocal, and decompose by tangent and bitangent to adjust uv.
				float3 normhit = normalize( i.hitvlocal ); 

				//Appropriate parallax adjustment [verified]
				float2 shift = -float2( dot( localtangent, normhit ), dot( localbitangent, normhit ) ) * distanceRayNeededToTravel; 
				
				float2 shiftynoise = float2( dot(localtangent, newlocalnorm) , dot( localbitangent, newlocalnorm) ) * distanceRayNeededToTravel;
				shift += shiftynoise;


				newuv += shift;

				float4 bottomtexel = tex2D (_WaterBottomTex, newuv) * lightmux;

				//Now add surface effects.
				float2 tanoisesurface = tanoiseperturb;
				float3 N = normalize( tanoisesurface.x*localtangent*_VividitySurface + tanoisesurface.y*localbitangent*_VividitySurface + localnorm );

				float3 L = i.lightpos;
				float3 V = normalize( i.hitvlocal );
				float3 R = reflect( -normalize(L), normalize(N) );

				float whitetips = pow( max( dot(R, V ), 0. ), _Shinyness );
				return float4( bottomtexel.rgb + whitetips*0.8*lightmux.rgb, 1. );
            }
            ENDCG
        }
    }
}
