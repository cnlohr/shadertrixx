Shader "Custom/LaplacianFloorCalc"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
        _DepthMap ("Depth Map Of Players", 2D) = "white" {}
        _LaplacianMap ("Last Frame's Data", 2D) = "white" {}

		_ResetTrigger ("Reset Trigger (Set to 1 to reset)", float ) = 0.0
		_IIRDecay ("IIR Decay 0.9 to 1.0", float ) = 0.999
		_TimeConstant ("Time Constant", float ) = 0.5
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
			
			Texture2D<float> _DepthMap;
			Texture2D<float4> _LaplacianMap;
			float2 _LaplacianMap_TexelSize;
			float2 _DepthMap_TexelSize;
			float _ResetTrigger;
			float _IIRDecay;
			float _TimeConstant;
			
            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				if( _ResetTrigger > 0.5 ) return fixed4( 0., 0., 0., 1. );

				int2 DepthCoord = float2(IN.localTexcoord.x,1.-IN.localTexcoord.y) / _DepthMap_TexelSize;
				int2 LaplacianCoord = IN.localTexcoord.xy / _LaplacianMap_TexelSize;
				float vin = _DepthMap.Load( int3( DepthCoord, 0 ) );
				
				//vin is like depth
				//This clamps depth.
				if( vin > .999 ) vin = 0.0;
				if( vin > 0.01 ) vin = 1.0;
				else vin = 0;
				
                float4 Last =   _LaplacianMap.Load( int3( LaplacianCoord, 0 ) );
                float4 Left1 =  _LaplacianMap.Load( int3( LaplacianCoord + int2(-1,0), 0 ) );
                float4 Up1 =    _LaplacianMap.Load( int3( LaplacianCoord + int2(0,-1), 0 ) );
                float4 Right1 = _LaplacianMap.Load( int3( LaplacianCoord + int2(1,0), 0 ) );
                float4 Down1 =  _LaplacianMap.Load( int3( LaplacianCoord + int2(0,1), 0 ) );

				float timestep = _TimeConstant;

				float velocity = Last.z;
				float diff = vin-Last.y;
				float value = Last.x + diff*.3;

				float laplacian = 
					2.0*(
						(Left1.x+Right1.x)/2.0-value.x+(Up1.x+Down1.x)/2.0-value.x);
		
				velocity+=laplacian*timestep;
				value+=velocity*timestep;
			
				float4 ov = float4( value*_IIRDecay, vin, velocity*_IIRDecay, 1. );

				//ov = fixed4(0.,0.,0.,1.);
				//ov.r = 0.;
                return ov;
				
			}


            ENDCG
        }
    }
}
