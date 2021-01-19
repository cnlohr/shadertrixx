Shader "Custom/ColorChord/ColorChordStep1Debug"
{
    Properties
    {
        _CCStage1 ("Texture", 2D) = "white" {}
        _CCStage2 ("Texture", 2D) = "white" {}
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

            sampler2D _CCStage1;
			
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
			
			
			int _RootNote;

			
			float3 HSVtoRGB(float3 HSV)
			{
				float3 RGB = 0;
				float C = HSV.z * HSV.y;
				float H = HSV.x * 6;
				float X = C * (1 - abs(fmod(H, 2) - 1));
				if (HSV.y != 0)
				{
					float I = floor(H);
					if (I == 0) { RGB = float3(C, X, 0); }
					else if (I == 1) { RGB = float3(X, C, 0); }
					else if (I == 2) { RGB = float3(0, C, X); }
					else if (I == 3) { RGB = float3(0, X, C); }
					else if (I == 4) { RGB = float3(X, 0, C); }
					else { RGB = float3(C, 0, X); }
				}
				float M = HSV.z - C;
				return RGB + M;
			}


			float3 CCtoRGB( float bin, float intensity )
			{
				float note = bin / EXPBINS;

				float hue = 0.0;
				note *= 12.0;
				note = glsl_mod( 4.-note + _RootNote, 12.0 );
				{
					if( note < 4.0 )
					{
						//Needs to be YELLOW->RED
						hue = (note) / 24.0;
					}
					else if( note < 8.0 )
					{
						//            [4]  [8]
						//Needs to be RED->BLUE
						hue = ( note-2.0 ) / 12.0;
					}
					else
					{
						//             [8] [12]
						//Needs to be BLUE->YELLOW
						hue = ( note - 4.0 ) / 8.0;
					}
				}
				float val = intensity-.1;
				return HSVtoRGB( float3( fmod(hue,1.0), 1.0, clamp( val, 0.0, 1.0 ) ) );
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
				//iuv.x is the NOTE, iuv.y is the INTENSITY.

				float inten = 0;

				int noteno = iuv.x * EXPBINS * EXPOCT;
				int readno = noteno % EXPBINS;
				int reado = (noteno/EXPBINS);
				inten = tex2D(_CCStage1, float2(readno/(float)EXPBINS, (EXPOCT - reado - 1 )/(float)EXPOCT ) );
					//_DFTData.Load( int3( readno, EXPOCT-reado-1, 0 ) );
					//return float4( inten*100., 0.,0.,1.);
			
		
				float marker = (readno==0)?1.0:0.0;
			
				if( abs( inten - iuv.y ) < 0.02 )
					return fixed4( CCtoRGB(noteno, 1.0 ), 1.0 );
				else if( marker > 0.0 )
					return float4( marker, 0., 0., 1. );
				else 
				{
					//Behind everything, debug the stage 2.
					
					return 0.;
				}

				//Graph-based spectrogram.
            }
            ENDCG
        }
    }
}
