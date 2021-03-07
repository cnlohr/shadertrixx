Shader "Custom/WaterShowComplex"
{
    Properties
    {
        _WaterCalcTex ("Calc Data", 2D) = "white" {}
        _WaterBottomTex ("Bottom Surface (RGB)", 2D) = "white" {}
		_WaterBottomColor ("Water Bottom Color", Color ) = (.9, .9, .9, 1. )
        _Depth ("Water Depth", float ) = 0.33
		_Metallic ("Surface Metallicity", float ) = .66
		_Smoothness ("Surface Smoothness", float ) = .96
		_LightMuxAdjust ("_LightMuxAdjust", float ) = -0.7
		_Murkiness( "Murkiness", float ) = 0.22
		_WaterMurkColor ("Water Murk Color", Color ) = (0.26,0.19,0.16,0.0)
		_IndexOfRefraction ("Water Index of Refraction", float ) = 1.33333
		_RippleIntensity ("Riple Intensity", float ) = 0.5
		_WaterBottomScaleX ("Water Bottom Scale X", float ) = 3
		_WaterBottomScaleY ("Water Bottom Scale Y", float ) = 3
		_BrightBoost("Albedo Boost", float)= 0.00
		_NormalMux( "Normal intensity", float ) = 1.0
		_LightCastShiftX ("Light Casting On Bottom Shift X", float ) = 0.01
		_LightCastShiftY ("Light Casting On Bottom Shift Y", float ) = -0.03
		_SpecLMOcclusionAdjust( "_SpecLMOcclusionAdjust", float ) = 0.5
		_SpecularLMOcclusion("_SpecularLMOcclusion", float) = 0.0
		_LightmapShiftMux("_LightmapShiftMux", float) = 0.1
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
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

            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
			#include "UnityImageBasedLighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
            };

            struct v2f
            {
				float2 uv_WaterCalcTex : TEXCOORD0;
				float3 worldPos : TEXCOORD2;
				float3 viewDir : TEXCOORD1;
				float2 uv_WaterBottomTex : TEXCOORD3;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
				
				#if defined(LIGHTMAP_ON)
					float2 uvLightStatic : TEXCOORD8;
				#endif
				#if defined( DYNAMICLIGHTMAP_ON )
					float2 uvLightDynamic : TEXCOORD9;
				#endif
            };
		
			sampler2D _WaterCalcTex;
			sampler2D _WaterBottomTex;

			float4 _WaterMurkColor;
			float _Murkiness;
			float _IndexOfRefraction;
			float4 _WaterCalcTex_ST;
			float4 _WaterBottomTex_ST;
			float _Depth, _Metallic, _Smoothness, _RippleIntensity;
			float _WaterBottomScaleX, _WaterBottomScaleY;
			float _BrightBoost;
			float _NormalMux;
			float _LightCastShiftX;
			float _LightCastShiftY;
			float _SpecLMOcclusionAdjust;
			float _LightMuxAdjust;
			float4 _WaterBottomColor;
			float _SpecularLMOcclusion;
			uniform float4 _WaterCalcTex_TexelSize;
			float _LightmapShiftMux;


			//Reflection direction, worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
			float3 getReflectionUV(float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax)
			{
				#if UNITY_SPECCUBE_BOX_PROJECTION
					if (cubemapPosition.w > 0) {
						float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
						float scalar = min(min(factors.x, factors.y), factors.z);
						direction = direction * scalar + (position - cubemapPosition);
					}
				#endif
				return direction;
			}

			float3 getBoxProjection (float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax)
			{
				// #if defined(UNITY_SPECCUBE_BOX_PROJECTION) // For some reason this doesn't work?
					if (cubemapPosition.w > 0) {
						float3 factors =
							((direction > 0 ? boxMax : boxMin) - position) / direction;
						float scalar = min(min(factors.x, factors.y), factors.z);
						direction = direction * scalar + (position - cubemapPosition);
					}
				// #endif
				return direction;
			}

			float3 getIndirectSpecular(float metallic, float roughness, float3 reflDir, float3 worldPos, float3 lightmap, float3 normal)
			{
				float3 spec = float3(0,0,0);
				#if defined(UNITY_PASS_FORWARDBASE)
					float3 indirectSpecular;
					Unity_GlossyEnvironmentData envData;
					envData.roughness = roughness;
					envData.reflUVW = getBoxProjection(
						reflDir, worldPos,
						unity_SpecCube0_ProbePosition,
						unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
					);

					float3 probe0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
					float interpolator = unity_SpecCube0_BoxMin.w;
					UNITY_BRANCH
					if (interpolator < 0.99999)
					{
						envData.reflUVW = getBoxProjection(
							reflDir, worldPos,
							unity_SpecCube1_ProbePosition,
							unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
						);
						float3 probe1 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0), unity_SpecCube0_HDR, envData);
						indirectSpecular = lerp(probe1, probe0, interpolator);
					}
					else
					{
						indirectSpecular = probe0;
					}
					float horizon = min(1 + dot(reflDir, normal), 1);
					indirectSpecular *= horizon * horizon;

					spec = indirectSpecular;
					#if defined(LIGHTMAP_ON)
						float specMultiplier = max(0, lerp(1, pow(length(lightmap), _SpecLMOcclusionAdjust), _SpecularLMOcclusion));
						spec *= specMultiplier;
					#endif
				#endif
				return spec;
			}


			//Not used - here for reference.
			float3 getRealtimeLightmapNew(float2 RTUV, float3 worldNormal)
			{
				float2 realtimeUV = RTUV;//uv * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
				float4 bakedCol = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, realtimeUV);
				float3 realtimeLightmap = DecodeRealtimeLightmap(bakedCol);

				#ifdef DIRLIGHTMAP_COMBINED
					float4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, realtimeUV);
					
					//XXX NOTE: TODO: Should this be += or = ?? The original documentation says ??
					realtimeLightmap = DecodeDirectionalLightmap (realtimeLightmap, realtimeDirTex, worldNormal);
				#endif
				
				return realtimeLightmap;
			}
			
			
			float3 getLightmapNew(float2 RTUV, float3 worldNormal)
			{
				float2 lightmapUV = RTUV;
				float4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, lightmapUV);
				float3 lightMap = DecodeLightmap(bakedColorTex);
				
				#ifdef DIRLIGHTMAP_COMBINED
					fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, lightmapUV);
					lightMap = DecodeDirectionalLightmap(lightMap, bakedDirTex, worldNormal);
				#endif
				return lightMap;
			}

			
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv_WaterCalcTex = TRANSFORM_TEX(v.uv, _WaterCalcTex);
				o.uv_WaterBottomTex = TRANSFORM_TEX(v.uv, _WaterBottomTex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.viewDir = _WorldSpaceCameraPos.xyz - o.worldPos.xyz;
				
				#if defined(LIGHTMAP_ON)
				o.uvLightStatic = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				#endif
				#if defined( DYNAMICLIGHTMAP_ON )
				o.uvLightDynamic = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
				#endif

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				// sample the texture
			
				//.xz is the interesting thing. (.x is amount) (.y is depth) (.z is the wavey bit)
				fixed4 amt  = tex2D(_WaterCalcTex, i.uv_WaterCalcTex).xyzw; 
				fixed4 amtX = tex2D(_WaterCalcTex, i.uv_WaterCalcTex + float2(_WaterCalcTex_TexelSize.x,0.0) ).xyzw; 
				fixed4 amtY = tex2D(_WaterCalcTex, i.uv_WaterCalcTex + float2(0.0,_WaterCalcTex_TexelSize.y) ).xyzw; 
				fixed3 ripplenorm = fixed3( amtX.x - amt.x, amtY.x - amt.x, 0.0 );
				ripplenorm *= _RippleIntensity;
				if( length( ripplenorm ) > 0.999 ) ripplenorm /= length( ripplenorm )*1.01;
				ripplenorm.z = sqrt( 1. - length( ripplenorm ) );

				float3 viewVec = -normalize( i.viewDir );   //Green-up
				float3 viewVecWorld = normalize( mul( viewVec, unity_ObjectToWorld ) ); //Blue up

				fixed3 viewVecUnderWater;

				//Snell's law.
				// n1 sin ( theta incident ) = n2 sin ( theta refracted )
				// The computation of the angles is annoying, especially to "set" the
				// angle on the other end.  I.e. calculating the angle isn't that bad.
				// basically just length( cross( n, i ) ) but, to rotate the correct amount
				// on the other end is painful. .. Or is it?
				
				//As vectors:
				// Stolen from: https://physics.stackexchange.com/a/436252
				// (n cross t)=μ(n cross i)
				// Solves to:
				// t=sqrt( 1−μ^2*(1−(n dot i)^2 ) )*n+μ*(i−(n dot i)*n)
				{
					float3 n = ripplenorm; //Blue up.
					float3 i = viewVecWorld; //Blue up. //viewVec; on surfac shader.
					float mu = 1./_IndexOfRefraction;
					float ndoti = dot( n, i );
					float det = 1 - mu*mu*(1-ndoti*ndoti);
					det = max( 0.3, det );
					if( det < 0 )
					{
						return _WaterMurkColor + _BrightBoost;
					}
					else
					{
						viewVecUnderWater = sqrt( det )*n + mu*(i-ndoti*n);
					}
					viewVecUnderWater.y *= -1; //XXX HACK!!! UV Map is lined up weird.
					//return float4( n, 1. );
					//return float4( i, 1. );
					//return float4(viewVecUnderWater, 1. );
				}
				
				float2 floor_deflection = (viewVecUnderWater.xy/viewVecUnderWater.z) * -1 * _Depth;
				//return float4( floor_deflection, 0., 1. );
				//return float4( i.uv_WaterBottomTex, 0., 1. );
				float2 floorlookup = i.uv_WaterBottomTex + floor_deflection;
				float DistanceToBottom = length( float3( floor_deflection.xy, _Depth ) ) + amt.z * _Depth;
				
				fixed4 watbot = tex2D(_WaterBottomTex, floorlookup*float2(_WaterBottomScaleX,_WaterBottomScaleY ));
				//return float4( watbot.xyz, 1. );

				fixed4 nv = fixed4( watbot );

				fixed3 Albedo = _BrightBoost + lerp( nv, _WaterMurkColor, pow( clamp( DistanceToBottom * _Murkiness, 0, 1 ), 0.4 ) );
				float3 TopNormal = normalize( ripplenorm.xyz );
				float3 TopWorldPos = i.worldPos;
				float3 LightmuxTop = 1.;
				float3 LightmuxBottom = 1.;
				float2 lightmapshift = _LightmapShiftMux *floor_deflection*float2(_WaterBottomScaleX,_WaterBottomScaleY ) + float2( _LightCastShiftX, _LightCastShiftY );
				float3 bottomnormalworld = float3( 0., 0., 1. ); //Don't worry about bottom normals - they're prebaked into our texture.
				#if defined(LIGHTMAP_ON)
					LightmuxTop.rgb += getLightmapNew(i.uvLightStatic, TopNormal  * _NormalMux);
					LightmuxBottom.rgb += getLightmapNew(i.uvLightStatic+lightmapshift*unity_LightmapST.xy, bottomnormalworld  * _NormalMux);
				#endif
				#if defined( DYNAMICLIGHTMAP_ON )
					LightmuxTop.rgb += getRealtimeLightmapNew(i.uvLightDynamic, TopNormal  * _NormalMux);
					LightmuxBottom.rgb += getRealtimeLightmapNew(i.uvLightDynamic+lightmapshift*unity_DynamicLightmapST.xy, bottomnormalworld  * _NormalMux);
				#endif
				#if !defined( LIGHTMAP_ON ) && !defined( DYNAMICLIGHTMAP_ON )
					LightmuxTop = 1.;
					LightmuxBottom = 1.;
				#endif
				
				LightmuxBottom += _LightMuxAdjust;
				LightmuxTop += _LightMuxAdjust;
				
				float3 BottomColor = Albedo * LightmuxBottom;
				float3 DirectDiffuse = 1.;
				float2 ReflectionRoll = (i.uv_WaterCalcTex-0.5) * .001;
				//return float4( viewVecWorld, 1. );
				float3 IndirectSpecular = getIndirectSpecular(_Metallic, _Smoothness, reflect( viewVec, TopNormal.xzy),
					TopWorldPos, DirectDiffuse, TopNormal );
				IndirectSpecular *= LightmuxTop * clamp((dot( viewVecWorld, TopNormal ))+1, 0., 1.) * .2;
				float3 FinalColor = BottomColor*_WaterBottomColor + IndirectSpecular;
				return float4( FinalColor, 1. );
            }
            ENDCG
        }
    }
}
