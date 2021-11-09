// Retro, parallax ceiling, safe for static, batched, instanced and stereo applications.
// (C) 2020-2021 cnlohr, licensible under the MIT/x11, New BSD or CC0 licenses.

Shader "cnlohr/ParallaxRetroCeiling"
{
    Properties
    {
		_Orientation ("CeilingOrientation", Vector) = ( 0, 0, 0, 0)
		brightness( "Brightness", float) = 0.6
		_GeneralColor( "General Color" , Color ) = (1, 0,0 ,1 )
        _Imagery ("Texture", 2D) = "white" {}
		_Parallax( "Parallax/Slide", Vector ) = ( 1, -1, 0, 0 )
		_GrainQty( "Grain Quantity", float ) = 1
		_GrainColor( "Grain Color", Color ) = ( 1, 0, 0, 1 )
		_ZeroBrightnessOffset( "Zero Brightness Offset", float ) = 0.15
		_LayerMotion ("LayerMotion", Vector ) = ( 0, .5, 1, 1.5 )
		[Toggle(_GRAIN_ON)] _GRAIN_ON ("Grain", Int) = 0
		[Toggle(_GRID_ON)] _GRID_ON ("Grid", Int) = 0
    }	
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
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
        Pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
			
			//#define USE_SYNCTIME

            #include "UnityCG.cginc"
			
			#ifdef USE_SYNCTIME
			#include "/Assets/AudioLink/Shaders/AudioLink.cginc"
			#endif

			#pragma shader_feature_local _GRAIN_ON
			#pragma shader_feature_local _GRID_ON

			#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y)))) 

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 pos : TEXCOORD1;
				float3 viewangle : TEXCOORD2;
				float3 normal : TEXCOORD3;
				float4 layer_offsets : TEXCOORD4;
            };

			float4 _LayerMotion;
			float4 _GeneralColor;
			float4 _Orientation;
			float4 _GrainColor;
			float4 _Parallax;
			float _GrainQty;
            sampler2D _Imagery;
			half2 _Imagery_TexelSize; 
            float4 _NoiseTex_ST;
			half _ParallaxQty;
			half brightness;
			float _ZeroBrightnessOffset;

			float3x3 EulerRotationMatrix( float3 euler )
			{
				float3 c = cos( euler );
				float3 s = sin( euler );
				return float3x3(
					c.z * c.y, c.x*s.y*s.x - s.z*c.x, c.z*s.y*c.x + s.z*s.x,
					s.z * c.y, s.x*s.y*s.x + c.z*c.x, s.z*s.y*c.x - c.z*s.x,
					-s.y, c.y*s.x, c.y*c.x );
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
				o.pos = v.vertex.xyz/v.vertex.w;
                o.uv = v.uv;
				float3 viewangle = mul( unity_ObjectToWorld, v.vertex )- _WorldSpaceCameraPos.xyz;
				o.normal = mul ((float4x4)unity_ObjectToWorld, v.normal );

				viewangle = mul( EulerRotationMatrix( _Orientation * (3.14159/180) ), viewangle );

				o.viewangle = viewangle;
				
				float usetime = _Time.y;
				#ifdef USE_SYNCTIME
				usetime = AudioLinkDecodeDataAsSeconds( ALPASS_GENERALVU_NETWORK_TIME );
				#endif
				o.layer_offsets = frac( usetime*_LayerMotion/8000 )*8000;
                return o;
            }

			// Adds scanlines.
			half pattern1( float2 uv )
			{
				uv = glsl_mod( uv, 1.0 );
				return floor(1.1-min( uv.x, uv.y ));
			}
			
			// Adds movie grain.
			#ifdef _GRAIN_ON
			#include "/Assets/cnlohr/Shaders/hashwithoutsine/hashwithoutsine.cginc"
			float3 moviegrain( float2 uv )
			{
				return chash33( float3( uv*931., glsl_mod( _Time.y, 2000 ) ) );
			}
			#endif

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
				fixed4 col = 0.0;

				half2 vaxy = i.viewangle.xy/i.viewangle.z*_Parallax;
				
				half intensity = 0.0;

				intensity += tex2D( _Imagery, float3( i.layer_offsets.xx*_Parallax.zw + i.uv, 0.0 ) ).r * 1.0;
				intensity += tex2D( _Imagery, float3( i.layer_offsets.yy*_Parallax.zw + i.uv+vaxy, 0.0 ) ).g * .5;
				intensity += tex2D( _Imagery, float3( i.layer_offsets.zz*_Parallax.zw + i.uv+vaxy*2., 0.0 ) ).b * .25;
				
				#ifdef _GRID_ON				
				intensity += pattern1( i.uv+i.layer_offsets.ww*_Parallax.zw+vaxy*4. ) * .125;
				#endif

				
				//Create a pattern.
				col = pow( intensity*.5, .8 );
				//col = fixed4(col.r*brightness, col.r*0.5-0.4, col.r*0.5-0.4, 1.0);
				col = (_GeneralColor) * (intensity-_ZeroBrightnessOffset);

				#ifdef _GRAIN_ON
				col.xyz += moviegrain( i.uv ) * _GrainQty * _GrainColor;
				#endif

                return col;
            }
            ENDCG
        }
    }
}
