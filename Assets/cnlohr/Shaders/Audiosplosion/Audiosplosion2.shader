Shader "Unlit/Audiosplosion2"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		pertAmount( "Perterb Amount", float) = 0.05
		heightStretch( "Heigh Stretch", float) = 128
		heightCenter( "Heigh Center", float) = 64
		detachness ("Detachness", float) = 0.2
		[HDR] _diffuse ("Diffuse", Color) = (0.8, 0.8, 0.8, 0.8)
		[HDR] _ambient ("Ambient", Color) = (0.1, 0.1, 0.1, 0.1)
    }
    SubShader
    {
        Tags { "LightMode"="ForwardBase"}
		LOD 100

		CGINCLUDE
		#include "/Assets/AudioLink/Shaders/AudioLink.cginc"
		
		float pertAmount;
		float heightStretch, heightCenter;
		float detachness;
		float4 _diffuse;
		float4 _ambient;
		
		float3 PerterbAmount( float3 center, float2 uv, float3 normal, float3 v, float3 thisnorm )
		{
			//return AudioLinkData( ALPASS_AUDIOLINK + uint2( heightCenter-center.y * heightStretch, 0. ) ).r * pertAmount * lerp(normal, thisnorm, detachness);
			float3 perb = 
				AudioLinkLerpMultiline( ALPASS_DFT + uint2( (heightCenter-center.y*heightStretch) * 128, 0 ) ).bbb
				//saturate( heightCenter-center.y*heightStretch )
				* pertAmount * lerp(normal, thisnorm, detachness); 
			
			
			return perb;
		}
		ENDCG

		Pass
		{
			Cull Off
            CGPROGRAM
			#include "UnityCG.cginc"
			#include "Autolight.cginc"
		
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment fragShadow
			#pragma multi_compile_fog
			#pragma multi_compile_fwdbase
			#pragma shader_feature IS_LIT

			#pragma target 5.0
				
			sampler2D _MainTex;
		
		
			struct appdata
			{
				float4 vertex : POSITION;
				float4 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};
		
			struct v2g
			{
					float4 vertex : POSITION;
					float3 normal : NORMAL;
					float2 uv : TEXCOORD0;
					float3 origv : blah;
			};
			struct g2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float3 origv : blah;
				float4 vertex : SV_POSITION;
				float3 normal : NORMAL;
				unityShadowCoord4 _ShadowCoord : TEXCOORD1;
			};

			v2g vert (appdata v)
			{
				v2g o;
				
				//move my verts
				float4 position = v.vertex;
				o.origv = v.vertex;
				o.vertex = position;
				o.normal = v.normal;
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			[maxvertexcount(3)]
			void geom(triangle v2g input[3], inout TriangleStream<g2f> triStream)
			{
				g2f o;
				float3 normal = normalize(cross(input[1].vertex.xyz - input[0].vertex.xyz, input[2].vertex.xyz - input[0].vertex.xyz));
				float3 center = ( input[0].origv + input[1].origv + input[2].origv ) / 3.0;
				float2 centuv = (input[0].uv + input[1].uv + input[2].uv)/3.0;

				for(int i = 0; i < 3; i++)
				{
					float4 vert = input[i].vertex;
					vert.xyz += PerterbAmount( center, centuv, normal, vert, input[i].normal );
					o.vertex = UnityObjectToClipPos(vert);
					UNITY_TRANSFER_FOG(o,o.vertex);
					o.uv = input[i].uv;
					o.origv = input[i].origv;
					o.normal = UnityObjectToWorldNormal((normal));
					o._ShadowCoord = ComputeScreenPos(o.vertex);
					#if UNITY_PASS_SHADOWCASTER
					o.vertex = UnityApplyLinearShadowBias(o.vertex);
					#endif
					triStream.Append(o);
				}

				triStream.RestartStrip();
			}
			
			float4 fragShadow(g2f i) : SV_Target
			{
			//	return float4( i.origv, 1.0 );
                fixed4 col = tex2D(_MainTex, i.uv);
                // compute shadow attenuation (1.0 = fully lit, 0.0 = fully shadowed)
                fixed shadow = SHADOW_ATTENUATION(i);
                // darken light's illumination with shadow, keep ambient intact
                fixed3 lighting = _diffuse * shadow * .2 + _ambient*.3;
                col.rgb *= lighting;
                return col;
			}   

            ENDCG
        }
		
		
        // shadow caster rendering pass, implemented manually
        // using macros from UnityCG.cginc
        Pass
        {
            Tags {"LightMode"="ShadowCaster"}
			Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma geometry geom
            #pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"
			#include "Autolight.cginc"


			struct appdata
			{
				float4 vertex : POSITION;
				float4 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};
            struct v2g { 
                //V2F_SHADOW_CASTER;
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
				float3 origv : blah;
           };

			struct g2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float3 normal : NORMAL;
				float3 origv : blah;
				unityShadowCoord4 _ShadowCoord : TEXCOORD1;
				 V2F_SHADOW_CASTER;
			};
			
			
			v2g vert (appdata v)
			{
				v2g o;
				
				//move my verts
                //TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				float4 position = v.vertex;
				o.origv = v.vertex;
				o.vertex = position;
				o.normal = v.normal;
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
					
			
			[maxvertexcount(3)]
			void geom(triangle v2g input[3], inout TriangleStream<g2f> triStream)
			{
				g2f o;
				float3 normal = normalize(cross(input[1].vertex.xyz - input[0].vertex.xyz , input[2].vertex.xyz  - input[0].vertex.xyz ));
				float3 center = ( input[0].origv + input[1].origv + input[2].origv ) / 3.0;
				float2 centuv = (input[0].uv + input[1].uv + input[2].uv)/3.0;

				for(int i = 0; i < 3; i++)
				{
					float4 vert = input[i].vertex;
					vert.xyz += PerterbAmount( center, centuv, normal, vert.xyz, input[i].normal );
					v2g v = input[i];
					v.vertex += float4( PerterbAmount( center, centuv, normal, vert.xyz, input[i].normal ), 0.0 );
					o.pos = UnityObjectToClipPos(vert);
					UNITY_TRANSFER_FOG(o,o.pos);
					o.uv = input[i].uv;
					o.origv = input[i].origv;
					o.normal = UnityObjectToWorldNormal((normal));
					o._ShadowCoord = ComputeScreenPos(o.pos);
					#if UNITY_PASS_SHADOWCASTER
					o.pos = UnityApplyLinearShadowBias(o.pos);
					#endif
					TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
					triStream.Append(o);
				}

				triStream.RestartStrip();
			}
			
			
            float4 frag(g2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
}
