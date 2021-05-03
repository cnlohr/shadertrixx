Shader "Custom/ColorChord/DisplayLinearCRT"
{
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
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
			
            #include "UnityCustomRenderTexture.cginc"
			#include "ColorChordVRC.cginc"
            #include "UnityCG.cginc"

            sampler2D _ToCopy;
			int _RootNote;
			float _Uniformitivity;
			float _Brightness;
            float4 _ToCopy_ST;
			Texture2D<float4> _NotesData;
			
			float4 ReadNote( int note )
			{
				float4 r = _NotesData.Load( int3( note, 0, 0 ) );
				return r;
			}

            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				float2 uv = IN.localTexcoord.xy;
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
					if( PowerPlace >= uv.x ) 
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
