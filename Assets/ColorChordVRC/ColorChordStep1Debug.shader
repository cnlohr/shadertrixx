Shader "Custom/ColorChord/ColorChordStep1Debug"
{
    Properties
    {
		_AudioLinkTexture ("Texture", 2D) = "white" {}
		_RootNote ("RootNote", int ) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
			#include "ColorChordVRC.cginc"

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
            };

            sampler2D _AudioLinkTexture;
			uniform float4 _AudioLinkTexture_TexelSize;
			int _RootNote;
			
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
			
			float4 forcefilt( sampler2D sample, float4 texelsize, float2 uv )
			{
				float4 A = tex2D( sample, uv );
				float4 B = tex2D( sample, uv + float2(texelsize.x, 0 ) );
				float4 C = tex2D( sample, uv + float2(0, texelsize.y ) );
				float4 D = tex2D( sample, uv + float2(texelsize.x, texelsize.y ) );
				float2 conv = frac(uv*texelsize.zw);
				//return float4(uv, 0., 1.);
				return lerp(
					lerp( A, B, conv.x ),
					lerp( C, D, conv.x ),
					conv.y );
			}
			
			float4 GetAudioPixelData( int2 pixelcoord )
			{
				return tex2D( _AudioLinkTexture, float2( pixelcoord*_AudioLinkTexture_TexelSize.xy) );
			}
			
            fixed4 frag (v2f i) : SV_Target
            {
			#if 0
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv)*10.;
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
			#endif
				float2 iuv = i.uv;

				float4 inten = 0;

				int noteno = iuv.x * EXPBINS * EXPOCT;
				float notenof = iuv.x * EXPBINS * EXPOCT;
				int readno = noteno % EXPBINS;
				float readnof = fmod( notenof, EXPBINS );
				int reado = (noteno/EXPBINS);
				float readof = notenof/EXPBINS;

				inten = forcefilt(_AudioLinkTexture, _AudioLinkTexture_TexelSize, 
					 float2((fmod(notenof,128))/128.,((noteno/128)/64.+4./64.)) );
				
				inten.x *= 3.;				
			
				if( iuv.y > 0.98 )
				{
					return fixed4( CCtoRGB( iuv.x*48., 1.0, 1.0 ), 1.0);
				}
				float4 coloro = 0.;

				{
					//Debug stage 2 (notes)
					float4 ccpick = GetAudioPixelData( uint2( 5 + floor(iuv.x*16), 16 ) );
					
					if( (glsl_mod( iuv.x, 1./MAXPEAKS ) > 0.5/MAXPEAKS ) )
					{
						float vv = ccpick.g/4;
						vv= sqrt(vv);
						if( iuv.y < vv && iuv.y > vv - 0.05 ) 
							coloro += fixed4( CCtoRGB( ccpick.r, 1.0, _RootNote ), 1.);
						else if( iuv.y > vv - 0.055 && iuv.y < vv + 0.00 )
							coloro += 1.;
					}
					else
					{
						float vv =(ccpick.a/40.);
						vv= sqrt(vv);
						if( iuv.y < vv && iuv.y > vv - 0.05 ) 
							coloro += fixed4( CCtoRGB( ccpick.r, 1.0, _RootNote ), 1.);
						else if( iuv.y > vv - 0.05 && iuv.y < vv + 0.005 )
							coloro += 1.;
					}
				}

				//The first-note-segmenters
				coloro += float4( max(0.,1.3-length(readnof-1.3) ), 0., 0., 1. );
				
				//Sinewave
				// Get whole waveform would be / 1.
				float sinpull = notenof / 2.;
				float sinewaveval = forcefilt( _AudioLinkTexture, _AudioLinkTexture_TexelSize, 
					 float2((fmod(sinpull,128))/128.,((floor(sinpull/128.))/64.+8./64.)) );
					 
				//If line has more significant slope, roll it extra wide.
				float ddd = 1.+length(float2(ddx( sinewaveval ),ddy(sinewaveval)))*20;
				coloro += max( 100.*((0.02*ddd)-abs( sinewaveval - iuv.y*2.+1. )), 0. );
				
				float rval = max( 0.01 - abs( inten.x - iuv.y ), 0. );
				rval = min( 1., 1000*rval );
				coloro = lerp( coloro, fixed4( CCtoRGB(noteno, 1.0, _RootNote ), 1.0 ), rval );
				return coloro;

				//Graph-based spectrogram.
            }
            ENDCG
        }
    }
}
