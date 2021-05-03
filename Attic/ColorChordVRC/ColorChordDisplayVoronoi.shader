Shader "Custom/ColorChord/DisplayVoronoi"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
		_NotesData ("Note Data (Phase 2 Output)", 2D) = "white" {}
		_RootNote ("RootNote", float ) = 0
		_Brightness ("Brightness",float) = 1.
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
			#include "ColorChordVRC.cginc"

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
			float _RootNote;
			float _Uniformitivity;
            float4 _ToCopy_ST;
			float _Brightness;
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
				float4 r = _NotesData.Load( int3( note, 0, 0 ) );
				r.y = (r.y > 0)?pow( r.y, _Uniformitivity ):0.0;
				r.y = r.y * 12 - 0.1;
				//r.y = pow( r.y, 0.5 )  * 6;
				return r;
			}

            fixed4 frag (v2f i) : SV_Target
            {
				int p;
				//float TotalPower = _NotesData.Load( int3( MAXPEAKS-1, 0, 0 ) ).x;

				float2 xy = i.uv * 2.0 - 1.0;

				float BestSway = 0.0;
				fixed4 BestColor = 0.0;

				float PowerPlace = 0.0;
				for( p = 0; p < MAXPEAKS-1; p++ )
				{
					float4 Peak = ReadNote( p );
					if( Peak.a <= 0 ) continue;

					float2 NoteCenterPhiR = float2( glsl_mod( Peak.x/ EXPBINS, 1.0 ) * 3.1415926 * 2.0, Peak.z  );
					float2 NoteCenterXY = float2( sin( NoteCenterPhiR.x ), cos( NoteCenterPhiR.x ) ) * NoteCenterPhiR.y;
					
					float Distance = length( xy - NoteCenterXY );

					float Sway = Peak.a / Distance;
					
					if( Sway > BestSway )
					{
						BestSway = Sway;
						BestColor = float4( CCtoRGB( Peak.x, Peak.a * _Brightness, _RootNote ), 1.0 );
					}
				}
				
				return fixed4( BestColor );
            }
            ENDCG
        }
    }
}
