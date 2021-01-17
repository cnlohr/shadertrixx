Shader "Custom/LaplacianFloorCalcOut"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
        _LaplacianMap ("Last Frame's Data", 2D) = "white" {}
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
                float4 Last =   _LaplacianMap.Load( int3( LaplacianCoord, 0 ) );
                float4 Left1 =  _LaplacianMap.Load( int3( LaplacianCoord + int2(-1,0), 0 ) );
                float4 Up1 =    _LaplacianMap.Load( int3( LaplacianCoord + int2(0,-1), 0 ) );
                float4 Right1 = _LaplacianMap.Load( int3( LaplacianCoord + int2(1,0), 0 ) );
                float4 Down1 =  _LaplacianMap.Load( int3( LaplacianCoord + int2(0,1), 0 ) );
				
				float4 Filtered = Last/10. + (Left1+Up1+Right1+Down1)/4.;

				return fixed4( HSVtoRGB( float3( Filtered.z*2.+.6+Filtered.x, 1., abs(Filtered.x)) ), 1.);
			}


            ENDCG
        }
    }
}
