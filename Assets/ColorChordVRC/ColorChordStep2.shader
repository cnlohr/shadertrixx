Shader "Custom/ColorChord/Step2"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
		_RawDFTData ("Step 1 Output", 2D) = "white" {}
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
			
			Texture2D<float> _RawDFTData;
			uniform half2 _RawDFTData_TexelSize; 

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

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
            ENDCG
        }
    }
}
