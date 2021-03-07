//Based off of Shader "d4rkpl4y3r/BRDF PBS Macro"
Shader "Custom/parallaxdepthwrite"
{
    Properties
    {
		[Enum(Off, 0, Front, 1, Back, 2)] _Culling("Culling Mode", Int) = 2
		_Cutoff("Cutout", Range(0,1)) = .5
		_MainTex("Texture", 2D) = "white" {}
		[Normal] _NormalMap("Normal Map", 2D) = "bump" {}
		[Normal] _NormalMapScale( "Normal Map Scale", Vector ) = (1,-1,1)
		[Normal] _NormalMapOffset( "Normal Map Offset", Vector ) = (0,0,0)
		
		[hdr] _Color("Albedo", Color) = (1,1,1,1)
		
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

			struct v2f
			{
				#ifndef UNITY_PASS_SHADOWCASTER
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float3 tangent : TANGENT;
				float3 binormal : BINORMAL;
				float3 wPos : TEXCOORD0;
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
				
				TRANSFER_SHADOW(o);
				#endif
				o.uv = TRANSFORM_TEX(v.texcoord.xy, _MainTex);
				return o;
			}
			
			#ifndef UNITY_PASS_SHADOWCASTER
			void frag(v2f i, out float4 colo:COLOR, out float deptho : DEPTH)
			{
				float4 texCol = tex2D(_MainTex, i.uv) * _Color;
				clip(texCol.a - _Cutoff);
				
				//ADDED: Get normal map.
#ifdef UNITY_ENABLE_DETAIL_NORMALMAP
				float3 tsNormal = 
					( UnpackNormal( tex2D(_NormalMap, i.uv)  )
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

				float2 uv = i.uv;

				UNITY_LIGHT_ATTENUATION(attenuation, i, i.wPos.xyz);

				float3 specularTint;
				float oneMinusReflectivity;
				float smoothness = _Smoothness;
				float3 albedo = DiffuseAndSpecularFromMetallic(
					texCol, _Metallic, specularTint, oneMinusReflectivity
				);
				
				float3 viewDir = normalize(_WorldSpaceCameraPos - i.wPos);
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
				
				deptho = i.pos.z;
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
