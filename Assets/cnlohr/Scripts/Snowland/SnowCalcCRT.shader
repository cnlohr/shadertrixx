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
			#include "/Assets/cnlohr/Shaders/hashwithoutsine/hashwithoutsine.cginc"
			
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
				float4 dat = prev;
				
				float4 pl = _SelfTexture2D[licord+int2(-1,0)];
				float4 pr = _SelfTexture2D[licord+int2( 1,0)];
				float4 pu = _SelfTexture2D[licord+int2(0,-1)];
				float4 pd = _SelfTexture2D[licord+int2(0, 1)];

				float4 prevmax = max(
					max( pl, pr ),
					max( pu, pd ) ); 
				float4 prevmin = min(
					min( pl, pr ),
					min( pu, pd ) ); 
				float4 prevavg = 0.25*(
					pl + pr + pu + pd ); 
				
				float depth = prev.y;

				
				// Allow snow to schluff from one cell to another if it's a significant slope.
				#define maxslope 0.1
				float diffl = depth - pl.y;
				float diffr = depth - pr.y;
				float diffu = depth - pu.y;
				float diffd = depth - pd.y;
				if( diffl > maxslope ) depth -= (diffl - maxslope)*0.2;
				if( diffr > maxslope ) depth -= (diffr - maxslope)*0.2;
				if( diffu > maxslope ) depth -= (diffu - maxslope)*0.2;
				if( diffd > maxslope ) depth -= (diffd - maxslope)*0.2;
				if( diffl <-maxslope ) depth -= (diffl + maxslope)*0.2;
				if( diffr <-maxslope ) depth -= (diffr + maxslope)*0.2;
				if( diffu <-maxslope ) depth -= (diffu + maxslope)*0.2;
				if( diffd <-maxslope ) depth -= (diffd + maxslope)*0.2;


				// Amount to push below bottom.
				// i.e. push this much further than a person's foot.
				const float minbelow = 0.03; //about 1 inch


				//Pat down
				if( prev.x + depth > vBot - minbelow && vBot > vTop )
					depth = vBot - prev.x - minbelow;
				

				float maxdepth = prev.w;
				float deltottop = maxdepth - depth;
				float peakdepth = csimplex3( float3( IN.localTexcoord.xy*15., 0.0 ) )*0.4+0.6; 

				if( dat.z < 1.4 )
					depth = peakdepth/2;
				
				float snowspeed = max( 0, csimplex3( float3( IN.localTexcoord.xy*5.+_Time.y*.1, _Time.y*.02 ) ) );
				snowspeed *= .1; //Speed to grow snow
				depth += deltottop*unity_DeltaTime.x*snowspeed; //Grow snow, slowly.

				if( depth > maxdepth ) depth = maxdepth;
				if( depth < -minbelow ) depth = -minbelow;


				dat.x = vTop;
				dat.y = lerp( depth, prevavg.y, 0.01 );
				if( dat.z < 1.5 )
					dat.z+=0.1;
				
				// This limits where the snow *can* go, i.e. this looks for steps, etc.
				if( vTop <= 0.0 )
					dat.w = 0;
				else
					dat.w = 
						lerp(
							lerp( peakdepth, prevavg.w, 0.9999 ),
							min( prevmin.w + 0.1, peakdepth ), 0.02 );
							
				return dat;
			}


            ENDCG
        }
    }
}
