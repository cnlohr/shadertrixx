// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// Modified to support MSDF fonts - Merlin, also MIT license

Shader "Merlin/UI/MSDF UI Font"
{
    Properties
    {
        [HideInInspector]_MainTex ("Sprite Texture", 2D) = "white" {}
        [HDR]_Color ("Tint", Color) = (1,1,1,1)

		[NoScaleOffset]_MSDFTex("MSDF Texture", 2D) = "black" {}
		[HideInInspector]_PixelRange("Pixel Range", Float) = 4.0

        _StencilComp ("Stencil Comparison", Float) = 8
        _Stencil ("Stencil ID", Float) = 0
        _StencilOp ("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255

        _ColorMask ("Color Mask", Float) = 15

        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 1
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask [_ColorMask]

        Pass
        {
            Name "Default"
        CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Target 3.5 for centroid support on OpenGL ES
            #pragma target 3.5

            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            #pragma multi_compile __ UNITY_UI_CLIP_RECT
            #pragma multi_compile __ UNITY_UI_ALPHACLIP

            struct appdata_t
            {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR;
                float2 texcoord  : TEXCOORD0;
                float4 worldPosition : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _Color;
            float4 _TextureSampleAdd;
            float4 _ClipRect;
			sampler2D _MSDFTex; float4 _MSDFTex_TexelSize;
			float _PixelRange;

            v2f vert(appdata_t v, uint vertID : SV_VertexID)
            {
                v2f OUT;
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                OUT.worldPosition = v.vertex;
                OUT.vertex = UnityObjectToClipPos(OUT.worldPosition);

				OUT.color = v.color * _Color;
                OUT.texcoord = v.texcoord;

                return OUT;
            }

            sampler2D _MainTex;

			float median(float r, float g, float b)
			{
				return max(min(r, g), min(max(r, g), b));
			}


            half4 frag(v2f IN) : SV_Target
            {
                float2 texcoord = IN.texcoord;

				float2 msdfUnit = _PixelRange / _MSDFTex_TexelSize.zw;

				float4 sampleCol = tex2D(_MSDFTex, texcoord);
				float sigDist = median(sampleCol.r, sampleCol.g, sampleCol.b) - 0.5;
				sigDist *= max(dot(msdfUnit, 0.5 / fwidth(texcoord)), 1); // Max to handle fading out to quads in the distance
				float opacity = clamp(sigDist + 0.5, 0.0, 1.0);
				float4 color = float4(1, 1, 1, opacity);

				color += _TextureSampleAdd;
				color *= IN.color;

                #ifdef UNITY_UI_CLIP_RECT
                color.a *= UnityGet2DClipping(IN.worldPosition.xy, _ClipRect);
                #endif

                #ifdef UNITY_UI_ALPHACLIP
                clip (color.a - 0.001);
                #endif

                return color;
            }
        ENDCG
        }
    }

    Fallback "UI/Default"
}
