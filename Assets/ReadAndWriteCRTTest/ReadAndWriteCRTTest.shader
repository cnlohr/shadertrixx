Shader "Custom/ReadAndWriteCRTTest"
{
    Properties
    {
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
            Name "Generate Clock"
            CGPROGRAM
			
            #include "UnityCustomRenderTexture.cginc"

			#pragma target 4.0
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag

            #include "UnityCG.cginc"

			uniform half4 _SelfTexture2D_TexelSize; 

            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				float2 uv = IN.localTexcoord.xy;
				int2 coordinate = round( uv/_SelfTexture2D_TexelSize.xy + .5 );

				return fmod( _Time.zzzz+uv.y, 1. );
            }
            ENDCG
        }


        Pass
        {
            Name "Copy Memory"
            CGPROGRAM
			
            #include "UnityCustomRenderTexture.cginc"

			#pragma target 4.0
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag

            #include "UnityCG.cginc"

			uniform half4 _SelfTexture2D_TexelSize; 
			float4 ReadCoord( int2 coordinate )
			{
				return tex2D(  _SelfTexture2D, coordinate*_SelfTexture2D_TexelSize );
			}

            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				float2 uv = IN.globalTexcoord.xy;
				int2 coordinate = round( uv/_SelfTexture2D_TexelSize.xy - 0.5 );
				//return float4( coordinate, 0., 0. );
				return ReadCoord( int2( coordinate.x-1, coordinate.y ) )+0.1;
            }
            ENDCG
        }
		
        Pass
        {
            Name "UV"
            CGPROGRAM
			
            #include "UnityCustomRenderTexture.cginc"

			#pragma target 4.0
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag

            #include "UnityCG.cginc"

			uniform half4 _SelfTexture2D_TexelSize; 
			float4 ReadCoord( int2 coordinate )
			{
				return tex2D(  _SelfTexture2D, coordinate*_SelfTexture2D_TexelSize );
			}

            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				float2 uv = IN.globalTexcoord.xy;
				return float4( uv, 0., 1. );
            }
            ENDCG
        }
    }
}
