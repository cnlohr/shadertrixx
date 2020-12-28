Shader "Custom/ColorChord/Step3ALT"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
		_FoldedDFTData ("Step 1 Output", 2D) = "white" {}
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
			
			#define EXPOCT   8
			#define EXPBINS  48
			
			#define ETOTALBINS (EXPOCT*EXPBINS)
			
			#define MAXPEAKS 8
			
            fixed4 frag (v2f i) : SV_Target
            {
				float2 Peaks[MAXPEAKS];
				int NumPeaks = 0;

				int notes = _ScreenParams.x;
				int noteno = round( i.uv.x * ( notes - 1 ));

				//Phase 3: find peaks
				{
					float bindata[ETOTALBINS];
					int bins = round( 1./_FoldedDFTData_TexelSize.x );
					int octs = round( 1./_FoldedDFTData_TexelSize.y );

					int o;
					int i;
					for( o = 0; o < EXPOCT; o++ )
					{
						uint b;
						for( b = 0; b < EXPBINS; b++ )
						{
							bindata[o*EXPBINS+b] = _FoldedDFTData.Load( int3( b, EXPOCT-o-1, 0 ) );
						}
					}

					int check[ETOTALBINS];
					for( i = 0; i < ETOTALBINS; i++ )
					{
						check[i] = 0;
					}
					int bestbin;
					float bestbval;
					//Fill out the Peaks structure.
					for( i = 0; i < MAXPEAKS; i++ )
					{
						float prev = bindata[0];
						float this = bindata[1];
						bestbin = ETOTALBINS;
						bestbval = 0.;
						int b;
						for( b = 1; b < ETOTALBINS-1; b++ )
						{
							float next = bindata[b+1];
							
							if( this > bestbval && this > prev && this > next && check[b] == 0 )
							{
								bestbin = b;
								bestbval = this;
							}
							
							prev = this;
							this = next;
						}

						if( bestbin < ETOTALBINS )
						{
							check[bestbin] = 1;
							
							float tweakbin;
							//XXX TODO
							
							Peaks[i] = float2( bestbin, bestbval );
							NumPeaks++;
						}
						else
						{
							break;
						}
					}
				}

				//OK! Now, we have NumPeaks of Peaks.
				//Next, combine peaks?

				
				if( noteno >= NumPeaks )
					return float4( -1, -1, 0, 1 );
				else
					return float4( Peaks[noteno].x/100, Peaks[noteno].y*10., 0, 1 );
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
