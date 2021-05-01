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
		_BaseAmplitude ("Base Amplitude Multiplier", float) = 4.0

		// Phase 2 (Waveform Data)
		
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
						
			#define PHASE_ONE_OFFSET 4 //Y-Coordinate of Phase 1.
			#define PHASE_TWO_OFFSET 8 //Y-Coordinate of Phase 2.

			#define SAMPHIST 1023
			#define EXPBINS 64
			#define EXPOCT 8
			#define  _SamplesPerSecond 48000

			// AUDIO_LINK_ALPHA_START is a shortcut macro you can use at the top of your
			// fragment shader to quickly get coordinateLocal and coordinateGlobal.
			
			#if UNITY_UV_STARTS_AT_TOP
			#define AUDIO_LINK_ALPHA_START( BASECOORDY ) \
				float2 guv = IN.globalTexcoord.xy; \
				uint2 coordinateGlobal = round( guv/_SelfTexture2D_TexelSize.xy - 0.5 ); \
				uint2 coordinateLocal = uint2( coordinateGlobal.x, coordinateGlobal.y - BASECOORDY );
			#else
			#define AUDIO_LINK_ALPHA_START( BASECOORDY ) \
				float2 guv = IN.globalTexcoord.xy; \
				guv.y = 1.-guv.y; \
				uint2 coordinateGlobal = round( guv/_SelfTexture2D_TexelSize.xy - 0.5 ); \
				uint2 coordinateLocal = uint2( coordinateGlobal.x, coordinateGlobal.y - BASECOORDY );
			#endif

			#pragma target 4.0
			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment frag
			#include "UnityCustomRenderTexture.cginc"
			#include "UnityCG.cginc"
			uniform half4 _SelfTexture2D_TexelSize; 
			ENDCG

			Name "Pass1AudioDFT"
			CGPROGRAM
			// The structure of the output is:
			// RED CHANNEL: Intensity of given frequency.
			// GREEN/BLUE Reserved.
			//   4 Rows, each row contains two octaves. 
			//   Each octave contains 64 bins.

			uniform float  _AudioFrames[1023];
			float _BottomFrequency;
			float _IIRCoefficient;
			float _BaseAmplitude;


			fixed4 frag (v2f_customrendertexture IN) : SV_Target
			{
				AUDIO_LINK_ALPHA_START( PHASE_ONE_OFFSET )

				float4 last = tex2D( _SelfTexture2D, float2( coordinateGlobal*_SelfTexture2D_TexelSize.xy) );

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
				const float decay_coefficient = 0.08;
				
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
					
					// Advance phase
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

			uniform float  _AudioFrames[1023];
			float _BaseAmplitude;

			fixed4 frag (v2f_customrendertexture IN) : SV_Target
			{
				AUDIO_LINK_ALPHA_START( PHASE_TWO_OFFSET )

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
	}
}
