Shader "Custom/ColorChord/Step1"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
		//Not used; Not available on video streams.
		//_PlaceInSound ("PlaceInSound", int) = 0.0
		_BottomFrequency ("BottomFrequency", float ) = 55
		_SamplesPerSecond ("SamplesPerSecond", float ) = 48000
		_LastFrameData ("Last Frame", 2D) = "white" {}
		_IIRCoefficient ("IIR Coefficient", float) = 0.35
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
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

			uniform float  _AudioFrames[1023];
			float _BottomFrequency;
			float _SamplesPerSecond;
			float _IIRCoefficient;
			
			sampler2D _LastFrameData;
			uniform half2 _LastFrameData_TexelSize; 

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				float last = tex2Dlod( _LastFrameData, 
					float4( (i.uv), 0.0, 0.0 ) );
					
				const int bins = _ScreenParams.x;
				const int octaves = _ScreenParams.y;
				int bin = i.uv.x * bins;
				int octave = (1.-i.uv.y) * octaves;

				float2 ampl = 0.;
				int idx;
				float pha = 0;
				float phadelta = pow( 2, octave + ((float)bin)/bins );
				phadelta *= _BottomFrequency;
				phadelta /= _SamplesPerSecond;
				phadelta *= 3.1415926 * 2.0;
				float decay = 1.0;
				//Roll-off the time constant for higher frequencies.
				float decaymux = 1.-phadelta*.05;
				float integraldec = 0.;
				for( idx = 0; idx < SAMPHIST; idx++ )
				{
					float af = _AudioFrames[idx];
					ampl += float2( sin( pha ) * af, cos( pha ) * af ) * decay;
					integraldec += decay;
					pha += phadelta;
					decay *= decaymux;
				}
				
				ampl *= 2./integraldec;
				
				float mag = length( ampl )*length( ampl );
				mag = lerp( mag, last, _IIRCoefficient );
				
				fixed4 col = fixed4( mag, 0, 0, 0 );
				//fixed4 col = fixed4( phadelta*2., 0, 0, 0 );
                return col;
            }
            ENDCG
        }
    }
}
