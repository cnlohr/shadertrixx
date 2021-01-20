Shader "Custom/CharlesGIComposite"
{
	//We are compositing to a atlas texture from multiple textures.

    Properties
    {
        _FloorMap ("Floor Data", 2D) = "white" {}
        _ScreenMap ("Screen Data", 2D) = "white" {}
        _CCMap ("ColorChord Note Data", 2D) = "white" {}
		
		_FloorIntensity( "Floor Intensity", float ) = 0
		_ScreenIntensity( "Screen Intensity", float ) = 0
		_LampsIntensity( "Lamps Intensity", float ) = 0
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
            CGPROGRAM

            #include "UnityCustomRenderTexture.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
			#pragma target 4.0

			#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))

			#define TARGET_SIZE 256
			
            #include "UnityCG.cginc"
			
			Texture2D<float4> _FloorMap;
			float2 _LaplacianMap_TexelSize;
			sampler2D _ScreenMap;
			float2 _ScreenMap_TexelSize;
			Texture2D<float4> _CCMap;
			float2 _CCMap_TexelSize;
			
			float _FloorIntensity;
			float _ScreenIntensity;
			float _LampsIntensity;

			
			int2 _Size;

			float3 HSVtoRGB(float3 HSV)
			{
				float3 RGB = 0;
				float C = HSV.z * HSV.y;
				float H = glsl_mod( HSV.x, 1. ) * 6;
				float X = C * (1 - abs(glsl_mod(H, 2) - 1));
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


            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				int2 CoordLocation = IN.localTexcoord.xy * TARGET_SIZE;
				CoordLocation.y = 255 - CoordLocation.y;
				
				if( CoordLocation.y < 128 )
				{
					if( CoordLocation.x < 128 )
					{
						int x, y;
						CoordLocation.y = 127 - CoordLocation.y;
						float4 tot = 0.;
						[unroll]
						for( x = 0; x < 8; x++ )
						[unroll]
						for( y = 0; y < 8; y++ )
						{
							tot += _FloorMap.Load( int3( CoordLocation * 8 + int2(x,y), 0 ) );
						}
						return tot*_FloorIntensity;
					}
					else if( CoordLocation.x >= 156 && CoordLocation.x < 228 )
					{
						//Visual Screen
						int x, y;
						float4 tot = 0.;
						[unroll]
						for( x = 0; x < 4; x++ )
						[unroll]
						for( y = 0; y < 4; y++ )
						{
							float2 xc = (CoordLocation - int2( 156, 0 ));
							xc += 0.25 * float2(x,y);
							xc /= float2( 72, 128 );
							tot += tex2D(_ScreenMap,xc );
						}
						return tot*_ScreenIntensity;
					}
				}
				else if( CoordLocation.y >= 144 )
				{
					//ColorChord Light Data  For now, just random junk.
					int2 light = CoordLocation>>4;
					int lightno = light.x + ((light.y-9)<<4);
					return float4( HSVtoRGB( float3( lightno*.1 + frac(_Time.x*10.), 1., _LampsIntensity ) ), 1. );
				}
				
				//In bleed boundary we have a black guard.
				return 0.;
			}


            ENDCG
        }
    }
}
