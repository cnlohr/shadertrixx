Shader "AudioLink/AudioLinkColorLinear"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
		_NotesData ("Note Data (Phase 2 Output)", 2D) = "white" {}
		_RootNote ("RootNote", int ) = 0
		_Uniformitivity ("Uniformitivity", float) = 0.9
		_Brightness ("Brightness",float) = 1.
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

		//ZWrite Off
		//ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			
						
			#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))
			#define EXPBINS 24
			#define EXPOCT 10
			#define OCTAVES 10
			#define MAXPEAKS 16
			#define SAMPHIST 1023
			#define ETOTALBINS (EXPOCT*EXPBINS)			


			float3 CCHSVtoRGB(float3 HSV)
			{
				float3 RGB = 0;
				float C = HSV.z * HSV.y;
				float H = HSV.x * 6;
				float X = C * (1 - abs(fmod(H, 2) - 1));
				if (HSV.y != 0)
				{
					float I = floor(H);
					if (I == 0) { RGB = float3(C, X, 0); }
					else if (I == 1) { RGB = float3(X, C, 0); }
					else if (I == 2) { RGB = float3(0, C, X); }
					else if (I == 3) { RGB = float3(0, X, C); }
					else if (I == 4) { RGB = float3(X, 0, C); }
					else { RGB = float3(C, 0, X); }
				}
				float M = HSV.z - C;
				return RGB + M;
			}

			#ifndef CCclamp
			#define CCclamp(x,y,z) clamp( x, y, z )
			#endif


			float3 CCtoRGB( float bin, float intensity, int RootNote )
			{
				float note = bin / EXPBINS;

				float hue = 0.0;
				note *= 12.0;
				note = glsl_mod( 4.-note + RootNote, 12.0 );
				{
					if( note < 4.0 )
					{
						//Needs to be YELLOW->RED
						hue = (note) / 24.0;
					}
					else if( note < 8.0 )
					{
						//            [4]  [8]
						//Needs to be RED->BLUE
						hue = ( note-2.0 ) / 12.0;
					}
					else
					{
						//             [8] [12]
						//Needs to be BLUE->YELLOW
						hue = ( note - 4.0 ) / 8.0;
					}
				}
				float val = intensity-.1;
				return CCHSVtoRGB( float3( fmod(hue,1.0), 1.0, CCclamp( val, 0.0, 1.0 ) ) );
			}



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

            sampler2D _ToCopy;
			int _RootNote;
			float _Uniformitivity;
			float _Brightness;
            float4 _ToCopy_ST;
			Texture2D<float4> _NotesData;

			
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
			
			float4 ReadNote( int note )
			{
				float4 r =_NotesData.Load( int3( 5+note, 20, 0 ) );
				return r;
			}

            fixed4 frag (v2f i) : SV_Target
            {
				int p;
				
				float4 NotesSummary =  _NotesData.Load( int3( 4, 20, 0 ) );

				float TotalPower = 0.0;
				TotalPower = NotesSummary.z;

				float PowerPlace = 0.0;
				for( p = 0; p < MAXPEAKS-1; p++ )
				{
					float4 Peak = ReadNote( p );
					if( Peak.z <= 0 ) continue;

					float Power = Peak.z/TotalPower;
					PowerPlace += Power;
					if( PowerPlace >= i.uv.x ) 
					{
						return fixed4( CCtoRGB( Peak.x, Peak.a*0.5 * _Brightness, _RootNote ), 1.0 );
					}
				}
				
				return fixed4( 0., 0., 0., 1. );
            }
            ENDCG
        }
    }
}
