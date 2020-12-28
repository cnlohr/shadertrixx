Shader "Custom/ColorChord/DisplayLinear"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
       _NotesData ("Texture", 2D) = "white" {}
	   _RootNote ("RootNote", int ) = 0
	   _Uniformitivity ("Uniformitivity", float) = 0.9
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
            float4 _ToCopy_ST;
			Texture2D<float3> _NotesData;

			
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
			
			#define EXPBINS  48
			#define MAXPEAKS 24

			float3 HSVtoRGB(float3 HSV)
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


			float3 CCtoRGB( float bin, float intensity )
			{
				float note = bin / EXPBINS;

				float hue = 0.0;
				note *= 12.0;
				note = glsl_mod( 4.-note + _RootNote, 12.0 );
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
				return HSVtoRGB( float3( fmod(hue,1.0), 1.0, clamp( val, 0.0, 1.0 ) ) );
			}

			float3 ReadNote( int note )
			{
				float3 r = _NotesData.Load( int3( note, 0, 0 ) );
				r.y = (r.y > 0)?pow( r.y, _Uniformitivity ):0.0;
				r.y = r.y * 12 - 0.1;
				//r.y = pow( r.y, 0.5 )  * 6;
				return r;
			}

            fixed4 frag (v2f i) : SV_Target
            {
				int p;
				float TotalPower = 0.0;
				for( p = 0; p < MAXPEAKS; p++ )
				{
					float3 Peak = ReadNote( p );
					if( Peak.y <= 0 ) continue;
					TotalPower += Peak.y;
				}
				

				float PowerPlace = 0.0;
				for( p = 0; p < MAXPEAKS; p++ )
				{
					float3 Peak = ReadNote( p );
					if( Peak.y <= 0 ) continue;

					float Power = Peak.y/TotalPower;
					PowerPlace += Power;
					if( PowerPlace >= i.uv.x ) 
					{
						return fixed4( CCtoRGB( Peak.x, Peak.y ), 1.0 );
					}
				}
				
				return fixed4( 0., 0., 0., 1. );
            }
            ENDCG
        }
    }
}
