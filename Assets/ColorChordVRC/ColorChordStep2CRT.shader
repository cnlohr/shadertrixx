Shader "Custom/ColorChord/Step2CRT"
{
	//the output from this:
	// Linear array, left-to-right of MAXPEAKS.
	//  Each element:
	//   R: Peak Location (Note #)
	//   G: Peak Intensity
	//   B: Peak Q value (How pointy?)
	//   A: 1.0
	//
	// If note is empty, value will be:
	//  (-1, -1, -1, 1. )
	
    Properties
    {
		_DFTData ("Step 1 Output", 2D) = "white" {}
		_LastData ("Step 2 Copy", 2D) = "white" {}
		
		_PeakDecay ("Peak Decay", float) = 0.7
		_PeakCloseEnough ("Close Enough" , float) = 2.0
		_PeakMinium ("Peak Minimum", float) = 0.005
		_SortNotes ("Sort Notes", int) = 1
		_OctaveMerge ("Octave Merge", int) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100


		Cull Off
        Lighting Off		
		ZWrite Off
		ZTest Always

        Pass
        {
            CGPROGRAM

            #include "UnityCustomRenderTexture.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
			#pragma target 5.0

			#include "ColorChordVRC.cginc"

            #include "UnityCG.cginc"
			
			Texture2D<float> _DFTData;
			Texture2D<float3> _LastData;
			float2 _DFTData_TexelSize;


			float _PeakDecay;
			float _PeakCloseEnough;
			float _PeakMinium;
			int _SortNotes;
			int _OctaveMerge;
		


		
            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				float3 Peaks[MAXPEAKS];
				int NumPeaks = 0;

				int notes = MAXPEAKS;
				int noteno = round( (IN.localTexcoord.x) * ( notes - 1 ));
				//return fixed4( (noteno == (((int)_Time.y)%24))?100:0, 0., 0., 1. );
				
				//Phase 3: find peaks
				{
					float bindata[ETOTALBINS];
					int bins = EXPBINS;//round( 1./_DFTData_TexelSize.x );
					int octs = EXPOCT;//round( 1./_DFTData_TexelSize.y );

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
					[loop]
					for( i = 0; i < MAXPEAKS; i++ )
					{
						float prev = bindata[0];
						float this = bindata[1];
						bestbin = ETOTALBINS;
						bestbval = 0.;
						int b;
						[loop]
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

							if( !!_OctaveMerge ) analogbin = glsl_mod( analogbin, EXPBINS );

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
					[loop]
					for( p = 0; p < MAXPEAKS; p++ )
					{
						float3 Peak = _LastData.Load( int3( p, 0, 0 ) );
						if( Peak.x >= 0 )
						{
							Peak.y *= _PeakDecay;
							[loop]
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
						return float4( -1, -1, -1, 1 );
					else
						return float4( NewPeaks[noteno], 1 );
				}
			}

            ENDCG
        }
    }
}
