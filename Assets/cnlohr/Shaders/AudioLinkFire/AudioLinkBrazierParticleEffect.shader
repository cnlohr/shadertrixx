// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "AudioLink/AudioLinkSandbox/BrazierParticleEffect"
{
    Properties
    {
        _TANoiseTex ("TANoise", 2D) = "white" {}
        _FlameSpeed ("Flame Speed", float ) = 8.0
    }
    SubShader
    {
		Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        //Tags { "RenderType"="Opaque" }
        //Blend SrcAlpha OneMinusSrcAlpha
		Blend One One
        //ZWrite Off
        LOD 100

		// shadow caster rendering pass, implemented manually
		// using macros from UnityCG.cginc
		Pass
		{
			Tags {"LightMode"="ShadowCaster"}
			Cull Off
			
			CGINCLUDE

            #include "UnityCG.cginc"
            #include "/Assets/AudioLink/Shaders/AudioLink.cginc"
            #include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 base_color: TEXCOORD1;
            };

            float _FlameSpeed;
			
			v2f VertPos( appdata v )
			{
                v2f o;
                float4 vp = v.vertex;
                o.uv = v.uv;
                uint lightid = floor( v.uv.x );
                
				float _OverallScale = 3;
				float _ScatterScale = 4;
				float _UpwardScale = .8;
				float _BaseScatter = 1;
				
                float3 localOffset = 0.;
                float _FlySpeed = 1.;
                float SyncTime = AudioLinkDecodeDataAsSeconds( ALPASS_GENERALVU_NETWORK_TIME );
                float4 ThisNote = AudioLinkData(ALPASS_CCINTERNAL + uint2( lightid/8, 0 ) );
                float ThisScale = AudioLinkData(ALPASS_AUDIOLINK + uint2( 0, lightid%4 ) );
                
                float height = glsl_mod( lightid * 423 + SyncTime*_FlameSpeed, 16. )/16.;
                float3 FlyMux = .05;
                float noisex = lightid*100. + floor( v.vertex.x + 0.5 ) + unity_ObjectToWorld[0][3]*2;
                float3 positional_offset = (tanoise2_hq( float2( noisex, SyncTime*_FlySpeed + floor( v.vertex.y + 0.5 ) + unity_ObjectToWorld[2][3]*2 ) )-0.5)*FlyMux;
                float3 positional_offset_future = (tanoise2_hq( float2( noisex, SyncTime*_FlySpeed+0.2 ) )-0.5)*FlyMux;
                float3 direction = positional_offset_future - positional_offset;
                
                localOffset = positional_offset * (height*3.+_BaseScatter) * _ScatterScale;
                localOffset.z += height*_UpwardScale;
				
				//localOffset = mul( unity_ObjectToWorld, localOffset );
    
                vp.z -= lightid * .025;
                vp.xyz *= ThisScale-0.1+(1.-height);
				vp.xyz *= _OverallScale;
                vp.xyz += localOffset;

                o.base_color = float4( AudioLinkCCtoRGB( ThisNote.x, 1, 0 ), 1. );
                o.vertex = UnityObjectToClipPos(vp);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
			}
			
			ENDCG
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing

			struct av2f { 
				V2F_SHADOW_CASTER;
				float4 uv : TEXCOORD0;
			};

			av2f vert(appdata v)
			{
				v2f tpo = VertPos( v );
				av2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				//TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				o.uv = v.uv.xyxy;
	#if defined(UNITY_PASS_SHADOWCASTER)
				o.pos  = tpo.vertex;
	#else
					//Nothing.
	#endif
				//DISABLE:
				//o.pos = 0.;
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
		
        Pass
        {
			Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog


            v2f vert (appdata v)
            {
				return VertPos( v );
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = i.base_color;
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
