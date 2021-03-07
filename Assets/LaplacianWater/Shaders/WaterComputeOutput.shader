Shader "Custom/WaterComputeOutput"
{
    Properties
    {
        _CopiedTex ("Data Frame of Previous", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

		ZWrite Off

        Pass
        {
            CGPROGRAM
            #include "UnityCustomRenderTexture.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
			#pragma target 4.0
            #include "UnityCG.cginc"

            sampler2D _CopiedTex;
			uniform float4 _CopiedTex_ST;
			uniform float4 _CopiedTex_TexelSize;

            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				float2 uv = IN.localTexcoord;

				fixed2 texcoord = fixed2( 1.0 - uv.r, uv.g );
                fixed4 ov = tex2D(_CopiedTex, uv );
                fixed4 Left1 = tex2D(_CopiedTex, uv -fixed2(_CopiedTex_TexelSize.x,0.) );
                fixed4 Up1 = tex2D(_CopiedTex, uv   -fixed2(0.,_CopiedTex_TexelSize.y) );
                fixed4 Right1 = tex2D(_CopiedTex, uv+fixed2(_CopiedTex_TexelSize.x,0.) );
                fixed4 Down1 = tex2D(_CopiedTex, uv +fixed2(0.,_CopiedTex_TexelSize.y) );

			   
				//Don't filter
			    //return ov;
                //return (ov + Left1 + Up1)/3.;
				//Triangle filter (we think this is best)
				return (ov + (Left1 + Up1 + Down1 + Right1)*0.5)/3.;
                //return (ov + Left1 + Up1 + Down1 + Right1)/5.;
            }
            ENDCG
        }
    }
}
