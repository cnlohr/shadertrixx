Shader "Custom/LaplacianFloorCalcOut"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
        _LaplacianMap ("Last Frame's Data", 2D) = "white" {}
		_OutputTextureIntensity ("Intensity", float ) = 0.06
		_HUEVariance( "Hue Variance", float ) = .8
		_HUETerm( "Hue Shift", float ) = 0.7
		_ABSTerm( "ABS Term", float ) = .5
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
			
            #include "UnityCG.cginc"
			
			Texture2D<float4> _LaplacianMap;
			float2 _LaplacianMap_TexelSize;
			float _OutputTextureIntensity;
			float _HUEVariance;
			float _HUETerm;
			float _ABSTerm;


			float3 HSVtoRGB(float3 HSV)
			{
				float3 RGB = 0;
				float C = HSV.z * HSV.y;
				float H = HSV.x * 6;
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
				int2 LaplacianCoord = IN.localTexcoord.xy / _LaplacianMap_TexelSize;
				
				float Last = 0.;
				int2 xy;
				for( xy.x = -1; xy.x <=1; xy.x++ )
				{
					for( xy.y = -1; xy.y <=1; xy.y++ )
					{
						float4 v = _LaplacianMap.Load( int3( LaplacianCoord + xy, 0 ) );
						Last += v / (length(xy)+1);
					}
				}
			
				float4 Filtered = Last*_OutputTextureIntensity;

				return fixed4( HSVtoRGB( 
					float3( 
						glsl_mod( Filtered.z*_HUEVariance+_HUETerm+Filtered.x + 600., 1.), 
						1., abs(Filtered.x)*_ABSTerm
					) ), 1.);
			}


            ENDCG
        }
    }
}
