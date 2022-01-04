Shader "Merlin/MSDF Text Mesh Font"
{
    Properties
    {
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
		[HDR]_Color("Text Color", Color) = (1, 1, 1, 1)
		[NoScaleOffset]_MSDFTex("MSDF Texture", 2D) = "black" {}
		[HideIninspector]_PixelRange("Pixel Range", Float) = 4.0
    }
    SubShader
    {
        Tags { "RenderType"="Cutout" "Queue"="AlphaTest" 
			   "IgnoreProjector" = "True" }

        Pass
        {
			//Blend SrcAlpha OneMinusSrcAlpha
			AlphaToMask On

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
				float4 vertex : SV_POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

			float4 _Color;
			sampler2D _MSDFTex; float4 _MSDFTex_TexelSize;
			float _PixelRange;

			float median(float r, float g, float b) 
			{
				return max(min(r, g), min(max(r, g), b));
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color * _Color;

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
				float2 msdfUnit = _PixelRange / _MSDFTex_TexelSize.zw;

				float4 sampleCol = tex2D(_MSDFTex, i.uv);
				float sigDist = median(sampleCol.r, sampleCol.g, sampleCol.b) - 0.5;
				sigDist *= max(dot(msdfUnit, 0.5/fwidth(i.uv)), 1); // Max to handle fading out to quads in the distance
				float opacity = clamp(sigDist + 0.5, 0.0, 1.0);
				float4 color = float4(i.color.rgb, i.color.a * opacity);

				clip(color.a - 0.005);

				return color;
            }
            ENDCG
        }
    }
}
