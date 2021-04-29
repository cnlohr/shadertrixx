Shader "Custom/ColorChord/Step1CRT"
{
	//The output of this pass:
	//	X: The intensity of the note within the octave.
	//  Y: The and Y of target texture are bins per octave, and octaves respectively.
    Properties
    {
		//Not used; Not available on video streams.
		//_PlaceInSound ("PlaceInSound", int) = 0.0
		_BottomFrequency ("BottomFrequency", float ) = 55
		//_SamplesPerSecond ("SamplesPerSecond", float ) = 48000
		_LastFrameData ("Last Frame", 2D) = "white" {}
		_IIRCoefficient ("IIR Coefficient", float) = 0.85
		_BaseAmplitude ("Base Amplitude Multiplier", float) = 4.0
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
            Name "Step1CRT"
            CGPROGRAM
			
            #include "UnityCustomRenderTexture.cginc"
			#include "ColorChordVRC.cginc"

			#pragma target 4.0
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag

            #include "UnityCG.cginc"
			
			uniform float  _AudioFrames[1023];
			float _BottomFrequency;
			#define  _SamplesPerSecond 48000
			float _IIRCoefficient;
			float _BaseAmplitude;

			sampler2D _LastFrameData;
			uniform half2 _LastFrameData_TexelSize; 


            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				float2 uv = IN.localTexcoord.xy;
				float last = tex2Dlod( _LastFrameData, 
					float4( (uv), 0.0, 0.0 ) );
					
				const int bins = EXPBINS;
				const int octaves = OCTAVES;
				int bin = uv.x * bins;
				int octave = (1.-uv.y) * octaves;

				float2 ampl = 0.;
				int idx;
				float pha = 0;
				float phadelta = pow( 2, octave + ((float)bin)/bins );
				phadelta *= _BottomFrequency;
				phadelta /= _SamplesPerSecond;
				phadelta *= 3.1415926 * 2.0;

				//Roll-off the time constant for higher frequencies.
				//This 0.08 if reduced, 0.1 normally.
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
				
				fixed4 col = fixed4( mag, _AudioFrames[bin+octave*bins], _AudioFrames[bin+octave*bins+EXPBINS*EXPOCT], 1 );
                return col;
            }
            ENDCG
        }
    }
}
