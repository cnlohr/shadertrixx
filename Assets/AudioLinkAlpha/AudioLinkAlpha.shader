Shader "Custom/AudioLinkAlpha"
{
	//Example CRT with multiple passed, used to read its own texture and write into another place.
	//Example of usage is in colorchord scene.
	//This shows how to read from other coordiantes within the CRT texture when using multiple passes.

	Properties
	{
		// Phase 1 (Audio DFT)
		_BottomFrequency ("BottomFrequency", float ) = 27.5
		_IIRCoefficient ("IIR Coefficient", float) = 0.85
		_BaseAmplitude ("Base Amplitude Multiplier", float) = 2.0

		// Phase 2 (Waveform Data)
		// This has no parameters.
		
		// ColorChord Notes (Pass 6)
		_PeakDecay ("Peak Decay", float) = 0.7
		_PeakCloseEnough ("Close Enough" , float) = 2.0
		_PeakMinium ("Peak Minimum", float) = 0.005
		_SortNotes ("Sort Notes", int) = 0
		_OctaveMerge ("Octave Merge", int) = 1
		
		_Uniformity( "Uniformitvity", float ) = 1.5
		_UniCutoff( "Uniformitvity Cutoff", float) = 0.0
		_UniAmp( "Uniformitvity Amplitude", float ) = 12.0
		_UniMaxPeak( "Uniformitvity Peak Reduction", float ) = 0.0
		_UniSumPeak( "Uniformitvity Sum Reduction", float ) = 0.1
		_UniNerfFromQ ("Uniformitvity Nerf from Bad Q", float ) = 0.05

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
			CGINCLUDE

			#define PASS_ONE_OFFSET    int2(0,4)  //Pass 1: DFT
			#define PASS_TWO_OFFSET    int2(0,8)  //Pass 2: Sample Data

			#define PASS_THREE_OFFSET  int2(0,0)  //Pass 3: Traditional 4 bands of AudioLink
			#define PASS_FOUR_OFFSET   int2(1,0)  //Pass 4: History from 4 bands of AudioLink

			#define PASS_FIVE_OFFSET   int2(0,16) //Pass 5: VU Meter
			#define PASS_SIX_OFFSET    int2(4,16) //Pass 6: ColorChord Notes Note: This is reserved to 32,16.

			#define SAMPHIST 1023
			#define EXPBINS 64
			#define EXPOCT 8
			#define ETOTALBINS ((EXPBINS)*(EXPOCT))
			#define  _SamplesPerSecond 48000

			// AUDIO_LINK_ALPHA_START is a shortcut macro you can use at the top of your
			// fragment shader to quickly get coordinateLocal and coordinateGlobal.

			#if UNITY_UV_STARTS_AT_TOP
			#define AUDIO_LINK_ALPHA_START( BASECOORDY ) \
				float2 guv = IN.globalTexcoord.xy; \
				uint2 coordinateGlobal = round( guv/_SelfTexture2D_TexelSize.xy - 0.5 ); \
				uint2 coordinateLocal = uint2( coordinateGlobal.x - BASECOORDY.x, coordinateGlobal.y - BASECOORDY.y );
			#else
			#define AUDIO_LINK_ALPHA_START( BASECOORDY ) \
				float2 guv = IN.globalTexcoord.xy; \
				guv.y = 1.-guv.y; \
				uint2 coordinateGlobal = round( guv/_SelfTexture2D_TexelSize.xy - 0.5 ); \
				uint2 coordinateLocal = uint2( coordinateGlobal.x - BASECOORDY.x, coordinateGlobal.y - BASECOORDY.y );
			#endif

			#pragma target 4.0
			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment frag
			#include "UnityCustomRenderTexture.cginc"
			#include "UnityCG.cginc"
			uniform half4 _SelfTexture2D_TexelSize; 

			uniform float  _AudioFrames[1023];
			
			// This pulls data from this texture.
			float4 GetSelfPixelData( int2 pixelcoord )
			{
				return tex2D( _SelfTexture2D, float2( pixelcoord*_SelfTexture2D_TexelSize.xy) );
			}
			ENDCG

			Name "Pass1AudioDFT"
			
			CGPROGRAM
			
			// The structure of the output is:
			// RED CHANNEL: Intensity of given frequency.
			// GREEN/BLUE Reserved.
			//   4 Rows, each row contains two octaves. 
			//   Each octave contains 64 bins.

			float _BottomFrequency;
			float _IIRCoefficient;
			float _BaseAmplitude;

			fixed4 frag (v2f_customrendertexture IN) : SV_Target
			{
				AUDIO_LINK_ALPHA_START( PASS_ONE_OFFSET )
				
				float4 last = GetSelfPixelData( coordinateGlobal );

				int bin = coordinateLocal.x % EXPBINS;
				int octave = coordinateLocal.y * 2 + coordinateLocal.x / EXPBINS;

				float2 ampl = 0.;
				int idx;
				float pha = 0;
				float phadelta = pow( 2, octave + ((float)bin)/EXPBINS );
				phadelta *= _BottomFrequency;
				phadelta /= _SamplesPerSecond;
				phadelta *= 3.1415926 * 2.0;

				//Roll-off the time constant for higher frequencies.
				//This 0.08 if reduced, 0.1 normally.  Consider altering this value.
				const float decay_coefficient = 0.15;
				
				float decaymux = 1.-phadelta*decay_coefficient;
				float integraldec = 0.;

				//The decay starts at 1.0, but will be reduced by decaymux.
				float decay = 1;

				for( idx = 0; idx < SAMPHIST; idx++ )
				{
					float af = _AudioFrames[idx];
					float2 sc; //Sin and cosine components to convolve.
					sincos( pha, sc.x, sc.y );
					
					// Step through, one sample at a time, multiplying the sin
					// and cos values by the incoming signal.
					ampl += sc * af * decay;
					
					// Advance PASS
					pha += phadelta;
					
					// Handle decay for higher frequencies.
					integraldec += decay;
					decay *= decaymux;
				}
				
				ampl *= _BaseAmplitude/integraldec;
				
				float mag = pow( length( ampl ), 2.0 );
				mag = lerp( mag, last, _IIRCoefficient );
				
				return float4( 
					mag,	//Red:   Spectrum power
					0,		//Green: Reserved
					0, 		//Blue:  Reserved
					1 );
			}
			ENDCG
		}

		Pass
		{
			Name "Pass2WaveformData"
			CGPROGRAM
			// The structure of the output is:
			// RED CHANNEL: Mono Audio
			// GREEN/BLUE: Reserved (may be left/right)
			//   8 Rows, each row contains 128 samples. Note: The last sample may be repeated.

			float _BaseAmplitude;

			fixed4 frag (v2f_customrendertexture IN) : SV_Target
			{
				AUDIO_LINK_ALPHA_START( PASS_TWO_OFFSET )

				uint frame = coordinateLocal.x + coordinateLocal.y * 128;
				if( frame == 1023 ) frame = 1022; //Prevent overflow.
				
				return float4( 
					_AudioFrames[frame],	//Red:   Spectrum power
					0,		//Green: Reserved
					0, 		//Blue:  Reserved
					1 );
			}
			ENDCG
		}
		
		Pass
		{
			Name "Pass5-VU-Meter"
			CGPROGRAM
			// The structure of the output is:
			// RED CHANNEL: Peak Amplitude
			// GREEN CHANNEL: RMS Amplitude.
			// BLUE CHANNEL: RESERVED.

			float _BaseAmplitude;

			fixed4 frag (v2f_customrendertexture IN) : SV_Target
			{
				AUDIO_LINK_ALPHA_START( PASS_TWO_OFFSET )

				int i;
				
				float total = 0;
				float peak = 0;
				for( i = 0; i < 1023; i++ )
				{
					float af = _AudioFrames[i];
					total += af*af;
					peak = max( peak, af );
					peak = max( peak, -af );
				}

				if( coordinateLocal.x == 0 )
				{
					//First pixel: Current value.
					return float4( sqrt( total / 1023. ), peak, 0., 1. );
				}
				else
				{
					//XXX TODO: Finish VU meter!
					return 0;
				}
			}
			ENDCG
		}

		Pass
		{
			Name "Pass6ColorChord-Notes"
			CGPROGRAM
			float _PeakDecay;
			float _PeakCloseEnough;
			float _PeakMinium;
			int _SortNotes;
			int _OctaveMerge;
			
			float _Uniformity;
			float _UniCutoff;
			float _UniAmp;
			float _UniMaxPeak;
			float _UniSumPeak;
			float _UniNerfFromQ;
			
            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				AUDIO_LINK_ALPHA_START( PASS_SIX_OFFSET )

				#define MAXPEAKS 16
				float3 Peaks[MAXPEAKS];
				int NumPeaks = 0;

				int notes = MAXPEAKS;
				int noteno = coordinateLocal.x-1;
				float4 LastPeaksSummary = GetSelfPixelData( PASS_SIX_OFFSET );
				
				// This finds the peaks and assigns them to notes.
				
				{
					float bindata[ETOTALBINS];
					int bins = EXPBINS;//round( 1./_DFTData_TexelSize.x );
					int octs = EXPOCT;//round( 1./_DFTData_TexelSize.y );

					uint o;
					uint i;
					for( o = 0; o < EXPOCT; o++ )
					{
						uint b;
						for( b = 0; b < EXPBINS; b++ )
						{
							bindata[o*EXPBINS+b] = GetSelfPixelData( PASS_ONE_OFFSET + int2( (o%2)*64 + b, o/2 ) ).r;
						}
					}
				
#if 0
					if( noteno == 0 )
					{
						int besti = -1;
						float bb = 0;
						for( i = 0; i < 64*8; i++ )
							if(  bindata[i] > bb ) { bb = bindata[i]; besti = i; }
						return float4( besti, 10, 0, 1 );
					}
#endif
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
							
							#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y)))) 
							
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
					//In order to merge in the peaks.
					float3 NewPeaks[MAXPEAKS];
					int NumNewPeaks;
					int p, np;
					[loop]
					for( p = 0; p < MAXPEAKS; p++ )
					{
						float3 Peak = GetSelfPixelData( PASS_SIX_OFFSET + int2( p+1, 0 ) );
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
					
					//Find the most intense peak + PEak totals.
					float maxpeak = 0.0;
					float peaktot = 0.0;
					for( np = 0; np <= MAXPEAKS-1; np++ )
					{
						float peakamp = NewPeaks[np].y;
						if( peakamp > maxpeak )
							maxpeak = peakamp;
						if( peakamp > 0.0 )
						{
							peaktot += peakamp;
						}
					}
					float peaktotrun = lerp( LastPeaksSummary.z, peaktot, 0.9 );
					
					if( noteno == -1 )
					{
						//This is the first, special pixel that gives metadata instead.
						
						float unitot = 0.0;
						for( np = 0; np < MAXPEAKS-1; np++ )
						{
							float peakamp = NewPeaks[np].y;
							if( peakamp > 0.0 )
							{

								float pu = ( pow( peakamp, _Uniformity )) * _UniAmp  - _UniCutoff - pow( maxpeak, _Uniformity ) * _UniMaxPeak + (1. - NewPeaks[np].z*_UniNerfFromQ) -  pow( peaktotrun, _Uniformity ) * _UniSumPeak;
								if( pu > 0. )
									unitot += pu;
							}
						}
						
						float avgphase1 = 0;

						uint o, b;
						for( o = 0; o < EXPOCT; o++ )
						for( b = 0; b < EXPBINS; b++ )
						{
							avgphase1 += GetSelfPixelData( PASS_ONE_OFFSET + uint2( (o%2)*64 + b, o/2 ) ).r;
						}
						avgphase1 /= (EXPOCT*EXPBINS);
						
						return float4( peaktot, avgphase1, peaktotrun, unitot );
					}	


					//We've now merged any of the peaks we could.
					//Next, forget dead peaks.
					
					float3 thisNote =  NewPeaks[noteno];

					if( noteno >= NumPeaks || thisNote.y <= 0.0 )
						return float4( -1, -1, -1, -1 );
					else
					{
						float pu = ( pow( thisNote.y, _Uniformity )) * _UniAmp  - _UniCutoff - pow( maxpeak, _Uniformity ) * _UniMaxPeak  + (1. - thisNote.z*_UniNerfFromQ) - pow( peaktotrun, _Uniformity ) * _UniSumPeak;
						return float4( thisNote, pu );
					}
				}
			}
			ENDCG
		}
	}
}
