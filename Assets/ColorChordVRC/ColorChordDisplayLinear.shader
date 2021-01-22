Shader "Custom/ColorChord/DisplayLinear"
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
			
			#include "ColorChordVRC.cginc"
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
				float4 r = _NotesData.Load( int3( note, 0, 0 ) );
				return r;
			}

            fixed4 frag (v2f i) : SV_Target
            {
				int p;
				float TotalPower = 0.0;
				TotalPower = _NotesData.Load( int3( MAXPEAKS-1, 0, 0 ) ).w;

				float PowerPlace = 0.0;
				for( p = 0; p < MAXPEAKS-1; p++ )
				{
					float4 Peak = ReadNote( p );
					if( Peak.a <= 0 ) continue;

					float Power = Peak.a/TotalPower;
					PowerPlace += Power;
					if( PowerPlace >= i.uv.x ) 
					{
						return fixed4( CCtoRGB( Peak.x, Peak.y * _Brightness, _RootNote ), 1.0 );
					}
				}
				
				return fixed4( 0., 0., 0., 1. );
            }
            ENDCG
        }
    }
}
