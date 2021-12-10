Shader "Snowland/SnowCalc_CRT"
{

	//X and Y of target texture are bins per octave, and octaves respectively.

    Properties
    {
        _DepthTop ("Top Depth", 2D) = "white" {}
        _DepthBot ("Bottom Depth", 2D) = "white" {}
		_ResetTrigger ("Reset Trigger (Set to 1 to reset)", float ) = 0.0
		
		_CameraSpanDimension( "Camera Span Dimension", float ) = 16.0
		_CameraFar( "Camera Far", float ) = 20.0
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

			#define _SelfTexture2D _SelfTexture2D_Dummy
            #include "UnityCustomRenderTexture.cginc"
			#undef _SelfTexture2D
			
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
			#pragma target 5.0

			#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))
			
            #include "UnityCG.cginc"
			
			Texture2D<float> _DepthTop;
			Texture2D<float> _DepthBot;
			Texture2D<float4> _SelfTexture2D;
			float4 _SelfTexture2D_TexelSize;
			float _ResetTrigger;
			float _CameraSpanDimension;
			float _CameraFar;
			
            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				if( _ResetTrigger > 0.5 ) return fixed4( 0., 0., 0., 1. );
				int2 licord = IN.localTexcoord.xy / _SelfTexture2D_TexelSize.xy;
				int2 licordz = float2( licord.x, _SelfTexture2D_TexelSize.w - licord.y );
				// Top is where the snow rests.
				float vTop = (_DepthTop[licord])*_CameraFar;
				float vTopL = vTop-(_DepthTop[licord+int2(-1,0)])*_CameraFar;
				float vTopR = vTop-(_DepthTop[licord+int2( 1,0)])*_CameraFar;
				float vTopU = vTop-(_DepthTop[licord+int2(0,-1)])*_CameraFar;
				float vTopD = vTop-(_DepthTop[licord+int2(0, 1)])*_CameraFar;

				float topDiff = max( max( abs( vTopL ), abs( vTopR ) ), max( abs(vTopU), abs(vTopD )) )*100;

				float vBot = (1.-_DepthBot[licordz])*_CameraFar;
				float4 prev = _SelfTexture2D[licord];
				
				float4 prevmax = max(
					max( _SelfTexture2D[licord+int2(-1,0)],	_SelfTexture2D[licord+int2( 1,0)] ),
					max( _SelfTexture2D[licord+int2(0,-1)], _SelfTexture2D[licord+int2(0, 1)] ) ); 
				float4 prevmin = min(
					min( _SelfTexture2D[licord+int2(-1,0)],	_SelfTexture2D[licord+int2( 1,0)] ),
					min( _SelfTexture2D[licord+int2(0,-1)], _SelfTexture2D[licord+int2(0, 1)] ) ); 
				
				float4 dat = prev;
				
				

				//Pat down
				if( prev.x + prev.y > vBot && vBot > vTop )
					prev.y = vBot - prev.x;
				
				float depth = prev.y;

				float maxdepth = saturate( 1.0-prev.w*1.3 );
				float deltottop = maxdepth - depth;
				depth += deltottop*unity_DeltaTime.x*.01;
				if( depth > maxdepth ) depth = maxdepth;
				
				if( depth < 0 ) depth = 0;
				
				depth = min( prevmin.y + .02, depth );
				dat.x = vTop;
				dat.y = depth;
				dat.z = 0.0;
				dat.w = max( clamp(topDiff,0,1), prevmax.w-.018);
				
				return dat;
			}


            ENDCG
        }
    }
}
