//Based off of Shader "d4rkpl4y3r/BRDF PBS Macro"
//
//  THIS IS THE ONE YOU WANT TO WORK FROM.
//

Shader "Custom/ReliefDepthWriteCharles"
{
    Properties
    {
		[Enum(Off, 0, Front, 1, Back, 2)] _Culling("Culling Mode", Int) = 2
		_Cutoff("Cutout", Range(0,1)) = .5
		_MainTex("Texture", 2D) = "white" {}
		[Normal] _NormalMap("Normal Map", 2D) = "bump" {}
		[Normal] _NormalMapScale( "Normal Map Scale", Vector ) = (1,-1,1)
		[Normal] _NormalMapOffset( "Normal Map Offset", Vector ) = (0,0,0)
		_DisplacementMap( "Displacement Map", 2D) = "displacement" {}
		_ParallaxStrength( "Parallax Strength", float ) = 1.
		_ParallaxOffset("Parallax Offset", float ) = 0.5
		[hdr] _Color("Albedo", Color) = (1,1,1,1)
		
		
		_ZDeflection("Z Deflection", float ) = 0.1
		_ParallaxRaymarchingSteps("Parallax Raymarching Steps", int)=10
		_ParallaxRaymarchingSearch("Parallax Raymarching Steps", int)=3
		_DepthMux("Depth Mux", float ) = 10.
		_DepthShift("Depth Shift", float) = 10.
		
		[Gamma] _Metallic("Metallic", Range(0, 1)) = 0
		_Smoothness("Smoothness", Range(0, 1)) = 0
    }
	SubShader
	{
		Tags
		{
			"RenderType"="Opaque"
			"Queue"="Geometry"
		}

		Cull [_Culling]

		CGINCLUDE
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityPBSLighting.cginc"



            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma shader_feature_local _NORMALMAP


			uniform float4 _Color;
			uniform float _Metallic;
			uniform float _Smoothness;
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;
			uniform sampler2D _NormalMap;
			uniform float _Cutoff;
			uniform half3 _NormalMapScale, _NormalMapOffset;
			uniform sampler2D _DisplacementMap;
			uniform half _ParallaxStrength, _ParallaxOffset;
			uniform half _ZDeflection;
			uniform half _DepthMux;
			uniform half _DepthShift;
			
			struct v2f
			{
				#ifndef UNITY_PASS_SHADOWCASTER
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float3 tangent : TANGENT;
				float3 binormal : BINORMAL;
				float3 wPos : TEXCOORD0;
				float3 tangentViewDir : TEXCOORD9;
				SHADOW_COORDS(3)
				#else
				V2F_SHADOW_CASTER;
				#endif
				float2 uv : TEXCOORD1;
			};
			
			//From Catlike coding
			float3 CreateBinormal (float3 normal, float3 tangent, float binormalSign) {
				return cross(normal, tangent.xyz) *
					(binormalSign * unity_WorldTransformParams.w);
			}


			v2f vert(appdata_full v)
			{
				v2f o;
				#ifdef UNITY_PASS_SHADOWCASTER
				TRANSFER_SHADOW_CASTER_NOPOS(o, o.pos);
				#else
				o.wPos = mul(unity_ObjectToWorld, v.vertex);
				o.pos = UnityWorldToClipPos(o.wPos);
				o.normal = UnityObjectToWorldNormal(v.normal);
				
				o.tangent = UnityObjectToWorldDir(v.tangent.xyz);
				o.binormal = CreateBinormal( o.normal, o.tangent, v.tangent.w );
				
				//This is from catlikecoding
				float3x3 objectToTangent = float3x3(
					v.tangent.xyz,
					cross(v.normal, v.tangent.xyz) * v.tangent.w,
					v.normal
				);
				o.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex)) * float3( _MainTex_ST.xy, 1. );
		
				TRANSFER_SHADOW(o);
				#endif
				o.uv = TRANSFORM_TEX(v.texcoord.xy, _MainTex);
				return o;
			}
			
			
			//From catlikecoding
			float GetParallaxHeight (float2 uv) {
				float height = tex2D(_DisplacementMap, uv).r;
				height -= _ParallaxOffset;
				height *= _ParallaxStrength;
				return height;
			}

			float2 ParallaxOffset (float2 uv, float2 viewDir) {
				float height = GetParallaxHeight(uv);
				return viewDir * height;
			}
				
			void ApplyParallax (inout v2f i) {
				#if defined(_PARALLAX_MAP)
				
					//i.tangentViewDir = normalize(i.tangentViewDir);
				/*
					#if !defined(PARALLAX_OFFSET_LIMITING)
						#if !defined(PARALLAX_BIAS)
							#define PARALLAX_BIAS 0.42
						#endif
						i.tangentViewDir.xy /= (i.tangentViewDir.z + PARALLAX_BIAS);
					#endif
				*/
					//i.tangentViewDir.xy /= (i.tangentViewDir.z);
					
					float2 uvOffset = ParallaxOffset(i.uv.xy, i.tangentViewDir.xy);
					i.uv.xy += uvOffset;
					i.uv.zw += uvOffset * (_DetailTex_ST.xy / _MainTex_ST.xy);
				#endif
			}
			
			#define PARALLAX_BIAS 0
			//	#define PARALLAX_OFFSET_LIMITING
			//#define PARALLAX_RAYMARCHING_STEPS 10
			//#define PARALLAX_RAYMARCHING_SEARCH_STEPS 10
			uniform int _ParallaxRaymarchingSteps;
			uniform int _ParallaxRaymarchingSearch;
			#define PARALLAX_RAYMARCHING_STEPS _ParallaxRaymarchingSteps
			#define PARALLAX_RAYMARCHING_SEARCH_STEPS _ParallaxRaymarchingSearch

			#define PARALLAX_FUNCTION ParallaxRaymarching
	
			float2 ParallaxRaymarching (float2 uv, float2 viewDir, out float travel) {
			
				//NOTE: At glancing angles, viewDir.xy will be larger, so our "stepSize" should remain constant.
			
				float stepSize = _ParallaxStrength / PARALLAX_RAYMARCHING_STEPS;
				float2 uvDelta = viewDir * (stepSize * _ParallaxStrength);
				float stepHeight = 0.5;  //TRICKY: this is effectively an offset from 0.  1.0 would be 0.0 to 1.0 into the surface.
				float surfaceHeight = GetParallaxHeight(uv);
				float2 uvOffset = 0.;

				float2 prevUVOffset = uvOffset;
				float prevStepHeight = stepHeight;
				float prevSurfaceHeight = surfaceHeight;
				int i;
				
				[loop]
				for ( i = 1; i < PARALLAX_RAYMARCHING_STEPS && stepHeight > surfaceHeight;i++ )
				{
					prevUVOffset = uvOffset;
					prevStepHeight = stepHeight;
					prevSurfaceHeight = surfaceHeight;

					uvOffset -= uvDelta;
					stepHeight -= stepSize;
					surfaceHeight = GetParallaxHeight(uv + uvOffset);
				}
				
				//XXX TODO: This part NOT VERIFIED.
				[loop]
				for ( i = 0; i < PARALLAX_RAYMARCHING_SEARCH_STEPS; i++)
				{
					prevUVOffset = uvOffset;
					prevStepHeight = stepHeight;
					prevSurfaceHeight = surfaceHeight;

					uvDelta *= 0.5;
					stepSize *= 0.5;

					if (stepHeight < surfaceHeight) {
						uvOffset += uvDelta;
						stepHeight += stepSize;
					}
					else {
						uvOffset -= uvDelta;
						stepHeight -= stepSize;
					}
					surfaceHeight = GetParallaxHeight(uv + uvOffset);
				}
				
				
				float prevDifference = prevStepHeight - prevSurfaceHeight;
				float difference = surfaceHeight - stepHeight;
				float t = prevDifference / (prevDifference + difference);
				uvOffset = lerp(prevUVOffset, uvOffset, t);

				travel = length(uvOffset.xy)/length(uvDelta)*stepSize;
				return uvOffset;
			}

			//Validated 3/6/21 CL
			//Caveat: Examine with:
			//  #if !defined(UNITY_REVERSED_Z) // basically only OpenGL
			//			zDepth = zDepth * 0.5 + 0.5; // remap -1 to 1 range to 0.0 to 1.0
			//	#endif
			float LinearToDepth(float linearDepth)
			{
				return (1.0 - _ZBufferParams.w * linearDepth) / (linearDepth * _ZBufferParams.z);
			}
			//Validated 3/6/21 CL
			float DepthToLinear(float Depth)
			{
				return 1./(Depth*_ZBufferParams.z+_ZBufferParams.w);
			}

			
			#ifndef UNITY_PASS_SHADOWCASTER
			void frag(v2f i, out float4 colo:COLOR, out float deptho : DEPTH)
			{
				float3 viewDir = normalize(_WorldSpaceCameraPos - i.wPos);

				//----------------------------------------------------
				//ADDED: Do Relief Map

				float frustumDivide = length(_WorldSpaceCameraPos - i.wPos)/DepthToLinear(i.pos.z);
				float depthDiff = 0;

				float2 uv = i.uv;
				float3 tvd = normalize( i.tangentViewDir );
				float2 tvduv = tvd.xy / (tvd.z+_ZDeflection); //This is equivelent to the standard .42, except that in VR, using .42 makes you sick.
				
				//Do this for parallax mapping.
				//#define PARALLAX_NOT_RELIEF
				#ifdef PARALLAX_NOT_RELIEF
					float offset = tex2D( _DisplacementMap, uv );
					uv += tvduv.xy * _ParallaxStrength * offset * 0.1;
					depthDiff = -offset / (length( tvd.z )+1.);
				#else
					uv += ParallaxRaymarching( uv, tvduv, depthDiff );
					depthDiff = depthDiff * _DepthMux + _DepthShift;
					//depthDiff+=.1;
				#endif
				depthDiff /= frustumDivide;
				//----------------------------------------------------

				float4 texCol = tex2D(_MainTex, uv) * _Color;
				clip(texCol.a - _Cutoff);

				//----------------------------------------------------
				//ADDED: Get normal map.
#ifdef UNITY_ENABLE_DETAIL_NORMALMAP
				float3 tsNormal = 
					( UnpackNormal( tex2D(_NormalMap, uv)  )
						* _NormalMapScale
						+ _NormalMapOffset );
				
				float3 normal = normalize(
					tsNormal.x * i.tangent +
					tsNormal.y * i.binormal +
					tsNormal.z * i.normal
				);
#else
				float3 normal = normalize(i.normal);
#endif
				//-----------------------------------------------------

				UNITY_LIGHT_ATTENUATION(attenuation, i, i.wPos.xyz);

				float3 specularTint;
				float oneMinusReflectivity;
				float smoothness = _Smoothness;
				float3 albedo = DiffuseAndSpecularFromMetallic(
					texCol, _Metallic, specularTint, oneMinusReflectivity
				);
				
				UnityLight light;
				light.color = attenuation * _LightColor0.rgb;
				light.dir = normalize(UnityWorldSpaceLightDir(i.wPos));
				UnityIndirect indirectLight;
				#ifdef UNITY_PASS_FORWARDADD
				indirectLight.diffuse = indirectLight.specular = 0;
				#else
				indirectLight.diffuse = max(0, ShadeSH9(float4(normal, 1)));
				float3 reflectionDir = reflect(-viewDir, normal);
				Unity_GlossyEnvironmentData envData;
				envData.roughness = 1 - smoothness;
				envData.reflUVW = reflectionDir;
				indirectLight.specular = Unity_GlossyEnvironment(
					UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
				);
				#endif

				float3 col = UNITY_BRDF_PBS(
					albedo, specularTint,
					oneMinusReflectivity, smoothness,
					normal, viewDir,
					light, indirectLight
				);

				#ifdef UNITY_PASS_FORWARDADD
				colo = float4(col, 0);
				#else
				colo = float4(col, 1);
				#endif

				/*
					TODO: Look into Lyuma and D4k's suggestions:
					LyumaToday:
					hey, it's better than what I do which is
					float4 pos = UnityWorldToClipPos(worldPos);
					float4 pos2 = UnityWorldToClipPos(normalize(worldPos - _WorldSpaceCameraPos) * depthDiff);
					pos.z = pos2.z * pos.w / pos2.w;
					like, it technically gets the job done but oh god so many matrix multiplies

					d4rkpl4y3r:
					just do it the simple way and spend your time on optimising stuff inside the loop
					this is how I do it
					float4 clipPos = UnityWorldToClipPos(rayPos);
					o.depth = clipPos.z / clipPos.w;
				*/				

				deptho = LinearToDepth( DepthToLinear(i.pos.z) + depthDiff );
			}
			#else
			float4 shadowcasterfragmentfunction( v2f i ) { SHADOW_CASTER_FRAGMENT(i) } 
			void frag(v2f i, out float4 colo:COLOR, out float deptho : DEPTH)
			{
				float alpha = _Color.a;
				if (_Cutoff > 0)
					alpha *= tex2D(_MainTex, i.uv).a;
				clip(alpha - _Cutoff);
				colo = shadowcasterfragmentfunction(i);
				deptho = i.pos.z;
			}
			#endif
		ENDCG

		Pass
		{
			Tags { "LightMode" = "ForwardBase" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase_fullshadows
			#pragma multi_compile UNITY_PASS_FORWARDBASE
			ENDCG
		}

		Pass
		{
			Tags { "LightMode" = "ForwardAdd" }
			Blend One One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile UNITY_PASS_FORWARDADD
			ENDCG
		}

		Pass
		{
			Tags { "LightMode" = "ShadowCaster" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma multi_compile UNITY_PASS_SHADOWCASTER
			ENDCG
		}
	}
}
