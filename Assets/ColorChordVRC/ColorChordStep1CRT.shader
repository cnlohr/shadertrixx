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
		_SamplesPerSecond ("SamplesPerSecond", float ) = 48000
		_LastFrameData ("Last Frame", 2D) = "white" {}
		_IIRCoefficient ("IIR Coefficient", float) = 0.35
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
			
			uniform float  _AudioFrames[1018];
			float _BottomFrequency;
			float _SamplesPerSecond;
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
				float decay = 1.0;
				
				//Roll-off the time constant for higher frequencies.
				//This 0.08 if reduced
				float decaymux = 1.-phadelta*.1;
				float integraldec = 0.;
				for( idx = 0; idx < SAMPHIST; idx++ )
				{
					float af = _AudioFrames[idx];
					ampl += float2( sin( pha ) * af, cos( pha ) * af ) * decay;
					integraldec += decay;
					pha += phadelta;
					decay *= decaymux;
				}
				
				ampl *= _BaseAmplitude/integraldec;
				
				float mag = pow( length( ampl ), 2.0 );
				mag = lerp( mag, last, _IIRCoefficient );
				
				fixed4 col = fixed4( mag, 1.0, _AudioFrames[bin+octave*bins], 1 );
                return col;
            }
            ENDCG
        }
    }
}
