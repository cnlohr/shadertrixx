Shader "Custom/ColorChord/Step2"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
		_DFTData ("Step 1 Output", 2D) = "white" {}
		_LastData ("Step 2 Copy", 2D) = "white" {}
		
		_PeakDecay ("Peak Decay", float) = 0.7
		_PeakCloseEnough ("Close Enough" , float) = 2.0
		_PeakMinium ("Peak Minimum", float) = 0.005
		_SortNotes ("Sort Notes", int) = 1
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
			
			Texture2D<float> _DFTData;
			Texture2D<float3> _LastData;
			float2 _DFTData_TexelSize;


			float _PeakDecay;
			float _PeakCloseEnough;
			float _PeakMinium;
			int _SortNotes;
		
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
				return o;
            }

			#define EXPOCT   8
			#define EXPBINS  48
			#define MAXPEAKS 24
			#define ETOTALBINS (EXPOCT*EXPBINS)			
			
            fixed4 frag (v2f i) : SV_Target
            {
				float3 Peaks[MAXPEAKS];
				int NumPeaks = 0;

				int notes = _ScreenParams.x;
				int noteno = round( i.uv.x * ( notes - 1 ));

				//Phase 3: find peaks
				{
					float bindata[ETOTALBINS];
					int bins = round( 1./_DFTData_TexelSize.x );
					int octs = round( 1./_DFTData_TexelSize.y );

					int o;
					int i;
					for( o = 0; o < EXPOCT; o++ )
					{
						uint b;
						for( b = 0; b < EXPBINS; b++ )
						{
							bindata[o*EXPBINS+b] = _DFTData.Load( int3( b, EXPOCT-o-1, 0 ) );
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
							
							float analogbin = bestbin;
							float bd = bindata[b];
							float tweakbinDown = bd - bindata[b-1];
							float tweakbinUp = bd - bindata[b+1];
							if( tweakbinDown < tweakbinUp )
							{
								//closer to bottom bin
								float diff = tweakbinDown / tweakbinUp;
								//The closer to 1, the closer to center.
								//The closer to 0, the further toward the lower bin.
								//Mathematically, this should be limited from 0 to 1.
								analogbin -= 0.5*(1.-diff);
							}
							else
							{
								//Closer to top bin.
								float diff = tweakbinUp / tweakbinDown;
								//The closer to 1, the closer to center.
								//The closer to 0, the further toward the upper bin.
								//Mathematically, this should be limited from 0 to 1.
								analogbin += 0.5*(1.-diff);
							}
							
							float q = (tweakbinDown + tweakbinUp) / (bd*2);

							Peaks[i] = float3( analogbin, bestbval, q );
							NumPeaks++;
						}
						else
						{
							break;
						}
					}
				}


				{
					//OK! Now, we have NumPeaks in Peaks array.
					//Next, we scour through last frame's array.

					float3 NewPeaks[MAXPEAKS];
					int NumNewPeaks;
					int p, np;
					for( p = 0; p < MAXPEAKS; p++ )
					{
						float3 Peak = _LastData.Load( int3( p, 0, 0 ) );
						if( Peak.x >= 0 )
						{
							Peak.y *= _PeakDecay;
							for( np = 0; np < MAXPEAKS; np++ )
							{
								float3 ThisPeak = Peaks[np];
								float diff = abs( ThisPeak.x - Peak.x );
								if( diff < _PeakCloseEnough )
								{
									//Roll Peak[np] into last peak.
									float percentage = ThisPeak.y / (ThisPeak.y + Peak.y);
									Peak.y += ThisPeak.y;
									Peak.x = lerp( Peak.x, ThisPeak.x, percentage );
									Peak.z = lerp( Peak.z, ThisPeak.z, percentage );
									Peaks[np] = -1;
								}
							}
							if( Peak.y < _PeakMinium )
							{
								//Nix this peak.
								Peak = -1;
							}
							NewPeaks[p] = Peak;
						}
						else
						{
							NewPeaks[p] = -1;
						}
					}
					
					//Next, load in any remaining unassigned peaks.
					for( np = 0; np < NumPeaks; np++ )
					{
						float3 ThisPeak = Peaks[np];

						if( ThisPeak.y >= _PeakMinium )
						{
							//Find an open slot in the peaks list and drop this in.
							for( p = 0; p < MAXPEAKS; p++ )
							{
								if( NewPeaks[np].y < 0 )
								{
									NewPeaks[np] = ThisPeak;
								}
							}
						}
					}
					
					//We are no longer going to use "Peaks"

					if( !!_SortNotes )
					{
						//Lastly, we need to sort the New Peaks.
						//Let's use insertion sort, because we're a mostly sorted list.
						for( np = 0; np < MAXPEAKS; np++ )
						{
							float3 SelectedItem = NewPeaks[np];
							for( p = np+1; p < MAXPEAKS; p++ )
							{
								if( SelectedItem.y > NewPeaks[p].y )
								{
									SelectedItem = NewPeaks[p];
								}
								else
								{
									NewPeaks[p-1] = NewPeaks[p];
									NewPeaks[p] = SelectedItem;
								}
							}
						}
					}

					//We've now merged any of the peaks we could.
					//Next, forget dead peaks.
					
					if( noteno >= NumPeaks )
						return float4( -1, -1, 0, 1 );
					else
						return float4( NewPeaks[noteno], 1 );
				}
			}

            ENDCG
        }
    }
}
