Shader "Custom/ColorChord/ColorChordStep1Debug"
{
    Properties
    {
        _CCStage1 ("Texture", 2D) = "white" {}
        _CCStage2 ("Texture", 2D) = "white" {}
		_RootNote ("RootNote", int ) = 0
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
            // make fog work
            #pragma multi_compile_fog

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
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _CCStage1;
            sampler2D _CCStage2;
			int _RootNote;
			
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
			
            fixed4 frag (v2f i) : SV_Target
            {
			#if 0
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv)*10.;
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
			#endif
				float2 iuv = i.uv;

				float4 inten = 0;

				int noteno = iuv.x * EXPBINS * EXPOCT;
				int readno = noteno % EXPBINS;
				int reado = (noteno/EXPBINS);
				inten = tex2D(_CCStage1, float2(readno/(float)EXPBINS, (EXPOCT - reado - 1 )/(float)EXPOCT ) );

				inten.x *= 3.;
		
				float marker = (readno==0)?1.0:0.0;
			
				if( iuv.y > 0.98 )
				{
					return fixed4( CCtoRGB( iuv.x*48., 1.0, 1.0 ), 1.0);
				}

				if( abs( inten.x - iuv.y ) < 0.02 )
					return fixed4( CCtoRGB(noteno, 1.0, _RootNote ), 1.0 );
				if( abs( inten.z - iuv.y*2.+1. )< 0.04 )
					return 1.;
				else if( marker > 0.0 )
					return float4( marker, 0., 0., 1. );
				else
				{
					//Debug stage 2.
					float4 ccpick = tex2D( _CCStage2, float2( iuv.x, 0.5 ) );
					if( (glsl_mod( iuv.x, 1./MAXPEAKS ) > 0.5/MAXPEAKS ) )
					{
						float vv = ccpick.g;
						vv= sqrt(vv);
						if( iuv.y < vv ) 
							return fixed4( CCtoRGB( ccpick.r, 1.0, _RootNote ), 1.);
					}
					else
					{
						float vv =(ccpick.a/10.);
						vv= sqrt(vv);
						if( iuv.y < vv && iuv.y > vv - 0.05 ) 
							return fixed4( CCtoRGB( ccpick.r, 1.0, _RootNote ), 1.);
					}
					
					return 0.;
				}

				//Graph-based spectrogram.
            }
            ENDCG
        }
    }
}
