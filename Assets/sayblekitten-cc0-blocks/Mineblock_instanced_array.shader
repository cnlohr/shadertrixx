Shader "Custom/Mineblock_instanced_array"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MineTex ("Albedo (RGB)", 2DArray) = "white" {}
        //_MineTexX ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
		_OverrideBlockID ("Override Block ID", Range(-1,240) ) = -1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM

        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows addshadow 
		#pragma require 2darray
        #pragma target 5.0
		
		#include "/Assets/AudioLink/Shaders/AudioLink.cginc"

		//sampler2D _MineTexX;
        UNITY_DECLARE_TEX2DARRAY( _MineTex );
		float4 _MineTex_TexelSize;
		
        struct Input
        {
            float2 uv_MineTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
		float _OverrideBlockID;
		
		#define AA_AXES_STEPS 3

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
			float4 _InstanceID;
        UNITY_INSTANCING_BUFFER_END(Props)

		float4 GetAdvancedColor( float2 uv, float2 rawuv, uint blockid )
		{
			blockid -= 192;
			if( blockid < 4 )
			{
				float uvc = length(uv-0.5)*100;
				return UNITY_SAMPLE_TEX2DARRAY( _MineTex, float4( uv, 112, 0 ) ) * AudioLinkData( ALPASS_CCCOLORS + uint2( blockid + 1, 0 ) ) * (AudioLinkData( ALPASS_AUDIOLINK + uint2( uvc, blockid ))*2.0 + .2); 
			}
			else if( blockid == 5 )
			{
				float phi = atan2( rawuv.x-0.5, rawuv.y-0.5 ) / 3.14159;
				float placeinautocorrelator = abs( phi );
				float autocorrvalue = AudioLinkLerp( ALPASS_AUTOCORRELATOR +
					float2( placeinautocorrelator * AUDIOLINK_WIDTH, 0. ) );
				float r = length( rawuv -0.5 )*6;
				float acmax = AudioLinkLerp( ALPASS_AUTOCORRELATOR ) * 0.2 + .6; 
				float rpos = r / (autocorrvalue/acmax + 2);
				float4 colr = AudioLinkLerp( ALPASS_CCSTRIP + float2( rpos*128, 0 ) );
				float4 ocolor = (rpos < 1)?colr:0;
				return (ocolor+.02) * UNITY_SAMPLE_TEX2DARRAY( _MineTex, float4( uv, 112, 0 ) );
			}
			else if( blockid == 6 )
			{
				uint2 uvx = uint2( floor(rawuv*8).xy );
				return AudioLinkData( ALPASS_CCLIGHTS + uint2( uvx.x + uvx.y*8, 0) );
			}
			else if( blockid == 7 )
			{
				uint2 uvx = uint2( floor(rawuv*8).xy );
				return AudioLinkData( ALPASS_CCLIGHTS + uint2( uvx.x + uvx.y*8+64, 0) );
			}
			else
			{
				return 0;
			}
		}

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
			int cursor0 = UNITY_ACCESS_INSTANCED_PROP(Props, _InstanceID).z;
			int cursor1 = UNITY_ACCESS_INSTANCED_PROP(Props, _InstanceID).w;
			float4 c = 0.;
			if( ( cursor0 <= 0 && cursor1 <= 0 ) || _OverrideBlockID >= 0 )
			{
				// Albedo comes from a texture tinted by color
				uint blockID;
				if( _OverrideBlockID >= 0 )
					blockID = _OverrideBlockID;
				else
					blockID = ((uint)(UNITY_ACCESS_INSTANCED_PROP(Props, _InstanceID).y))%256;

				float2 uv = IN.uv_MineTex;
                float2 coord = uv * 16.;
                float2 fr = frac(coord + 0.5);
                float2 fw = max(abs(ddx(coord)), abs(ddy(coord)));
                coord += (saturate((fr-(1-fw)*0.5)/fw) - fr);// * (16.);
				coord *= 1./16.;
				if( _OverrideBlockID >= 0 )
					coord = frac( coord );
				
				if( blockID >= 192 && blockID < 208 )
					c = GetAdvancedColor( coord, uv, blockID );
				else
					c = UNITY_SAMPLE_TEX2DARRAY( _MineTex, float4( coord, blockID, 0 ) );


				//Inspired roughly by this:  https://gitlab.com/s-ilent/pixelstandard/-/blob/master/Assets/Shaders/PixelStandard/PixelUnlit.shader
				// Their's is better.

				float2 uvbase = coord;//floor( newuv * 256 ) / 256.;
				float2 dlxy = 1./16.;
				float2 clxy = frac( coord * 16 );
				float4 cob1a = UNITY_SAMPLE_TEX2DARRAY(_MineTex, float4( uvbase+float2(0,0), blockID, 0 )) * _Color;
				float4 cob1b = UNITY_SAMPLE_TEX2DARRAY(_MineTex, float4( uvbase+float2(dlxy.x,0), blockID, 0 )) * _Color;
				float4 cob1c = UNITY_SAMPLE_TEX2DARRAY(_MineTex, float4( uvbase+float2(0,dlxy.y), blockID, 0 )) * _Color;
				float4 cob1d = UNITY_SAMPLE_TEX2DARRAY(_MineTex, float4( uvbase+dlxy, blockID, 0 )) * _Color;
				float4 cob1 = lerp( lerp( cob1a, cob1b, clxy.x ), lerp( cob1c, cob1d, clxy.x ), clxy.y );

				o.Normal = normalize( float3( 0, 0, 1 ) + cob1.xyz*.5 );
			
			}
			else
			{
				cursor0--;
				cursor1--;
#if 1
				// Currently used block ID.
				uint bvy = (uint)UNITY_ACCESS_INSTANCED_PROP(Props, _InstanceID).y;
				uint blockID = bvy%256;
				
				int localblockid = floor( IN.uv_MineTex.x * 16 ) + floor( IN.uv_MineTex.y * 16 ) * 16;
				float2 localuv = frac( IN.uv_MineTex * 16 );
				//float2 newuv = (localuv/16) + (float2( localblockid % 16, localblockid / 16 )/16.0);
				float2 newuv = localuv;
				newuv.y = 1-newuv.y;

				if( localblockid >= 192 && localblockid < 208 )
					c = GetAdvancedColor( newuv, localuv, localblockid );
				else
					c = UNITY_SAMPLE_TEX2DARRAY(_MineTex, float4( newuv, localblockid, 0 ));

				if( localblockid >= 251 )
				{
					int motionmode = (bvy>>8)&0x0f;
					if( localblockid == 251 ) c *= (motionmode==4)?0.8:0.1;
					if( localblockid == 252 ) c *= (motionmode==1)?0.8:0.1;
					if( localblockid == 253 ) c *= (motionmode==2)?0.8:0.1;
					if( localblockid == 254 ) c *= (motionmode==3)?0.8:0.1;
				}

				if( localblockid == cursor0 || localblockid == cursor1 )
				{
					c = frac( c + sin( _Time.y * 15. ) );
				}
				if( localblockid == blockID )
				{
					c = frac( c + sin( _Time.y * 2. ) );
				}
#endif
			}
			c *= _Color;
			//c = cob1;
            o.Albedo = c.rgb;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
