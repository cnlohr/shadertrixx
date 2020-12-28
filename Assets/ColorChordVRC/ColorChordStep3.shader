Shader "Custom/ColorChord/Step3"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
		_FoldedDFTData ("Step 2 Output", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

		ZWrite Off
		ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 5.0

			#define SAMPHIST 1023

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };
			
			Texture2D<float> _FoldedDFTData;
			float2 _FoldedDFTData_TexelSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
			
			#define EXPBINS  48
			#define MAXPEAKS 4

			//Use this!
			
			
            fixed4 frag (v2f i) : SV_Target
            {
				float2 Peaks[MAXPEAKS];
				uint NumPeaks;

				//Phase 3: find peaks
				{
					float bindata[EXPBINS];
					uint bins = round( 1./_FoldedDFTData_TexelSize.x );
					uint b;
					uint i;
					for( b = 0; b < EXPBINS; b++ )
					{
						bindata[b] =  _FoldedDFTData.Load( int3( b, 0, 0 ) );
					}

					uint check[MAXPEAKS];
					uint bestbin;
					float bestbval;
					//Fill out the Peaks structure.
					for( i = 0; i < MAXPEAKS; i++ )
					{
						float prev = bindata[bins-1];
						float this = bindata[0];
						bestbin = bins;
						bestbval = 0.;
						for( b = 0; b < bins; b++ )
						{
							float next = bindata[(b+1)%bins];
							
							if( this > bestbval && this > prev &&
								this > next && check[b] == 0 )
							{
								//return float4( 1., this, 0., 1. );
								bestbin = b;
								bestbval = this;
							}
							
							prev = this;
							this = next;
						}
						if( bestbin < bins )
						{
							check[bestbin] = 1;
							Peaks[i] = float2( bestbin, bestbval );
							NumPeaks++;
						}
						else
						{
							break;
						}
					}
				}
				
				uint notes = _ScreenParams.x;
				uint noteno = round( i.uv.x * ( notes - 1 ));

				if( noteno >= NumPeaks )
					return float4( -1, -1, 0, 1 );
				else
					return float4( Peaks[noteno], 0, 1 );
			}

#if 0
			float GetBinIntensity( int bin, int octave, int bins, int octaves )
			{
				//XXX TODO: Improve this!
				float rolloff = 1.0;
				if( octave == 0 ) rolloff *= (float)bin / (float)bins;
				else if( octave == octaves-1 ) rolloff *= 1.-(float)bin / (float)bins;
				return _RawDFTData.Load( int3( bin, octaves-octave-1, 0 ) );
			}

            fixed4 frag (v2f i) : SV_Target
            {
				const int octaves = 1./_RawDFTData_TexelSize.y;
				const int bins = 1./_RawDFTData_TexelSize.x;
				int bin = i.uv.x * bins;

				int oct = 0;
				float val = 0;
				const int integrateoctaves = 6;
				for( oct = 0; oct < integrateoctaves; oct++ )
				{
					val += GetBinIntensity( bin, oct, bins, octaves );
				}
				//val = GetBinIntensity( bin, 1, bins, octaves );
				fixed4 col = fixed4( val*10., 0, 0, 0 );
                return col;
            }
#endif
            ENDCG
        }
    }
}
