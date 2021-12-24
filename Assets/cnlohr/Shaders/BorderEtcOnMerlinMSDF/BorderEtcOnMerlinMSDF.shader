// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// http://forum.unity3d.com/threads/3d-text-that-takes-the-depth-buffer-into-account.9931/
// slightly modified so that it has a color parameter,
// start with white sprites and you can color them
// if having trouble making font sprite sets http://answers.unity3d.com/answers/1105527/view.html
 
Shader "GUI/BorderEtcOnMerlinMSDF"
{
    Properties
    {
		[NoScaleOffset]_MSDFTex("MSDF Texture", 2D) = "black" {}
        _FadeNear ("Fade Near", float) = 2.0
        _FadeCull ("Fade Cull", float) = 3.0
        _FadeSharpness ("Fade Range", float ) = 1
        [HDR]_Colorize ("Colorize", Color) = (1,1,1,1)
		[HideInInspector]_PixelRange("Pixel Range", Float) = 4.0
    }
    SubShader
    {
		// shadow caster rendering pass, implemented manually
		// using macros from UnityCG.cginc
		Pass
		{
			Tags {"LightMode"="ShadowCaster"}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"
			#pragma multi_compile_instancing

			struct v2f { 
				V2F_SHADOW_CASTER;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}

        Tags { "RenderType"="Transparent" "Queue"="Transparent"}
   
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
       
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
           
            fixed4 _Colorize;
            float _FadeCull;
			float _PixelRange;
            float _FadeNear, _FadeSharpness;
			sampler2D _MSDFTex; float4 _MSDFTex_TexelSize;

            
            struct v2g {
                float4 pos : SV_POSITION;
                fixed4 color : COLOR;
                float2 uv : TEXCOORD0;
                float3 camrelpos : TEXCOORD1;
            };
            struct g2f {
                float4 pos : SV_POSITION;
                fixed4 color : COLOR;
                float2 uv : TEXCOORD0;
                float3 camrelpos : TEXCOORD1;
            };
       
            struct appdata {
                float4 vertex : POSITION;
                fixed4 color : COLOR;
                float2 texcoord : TEXCOORD0;
            };
       
            v2g vert (appdata v)
            {
                v2g o;
                o.pos = (v.vertex);
                o.color = v.color;
                o.uv    = v.texcoord;
                o.camrelpos = _WorldSpaceCameraPos - mul( unity_ObjectToWorld, v.vertex );
                return o;
            }

            #pragma geometry geom

            // I tried doing an approach with a geometry shader, I didn't like how it looked.

            [maxvertexcount(3)]            
            void geom(triangle v2g p[3], inout TriangleStream<g2f> triStream, uint id : SV_PrimitiveID)
            {
				// Expand quads around chars.
				float extraborderize = 1.1;
				float2 uvcenter = (p[0].uv+p[1].uv+p[2].uv)/3;
				float2 uv0 = p[0].uv-uvcenter;
				float2 uv1 = p[1].uv-uvcenter;
				float2 uv2 = p[2].uv-uvcenter;
				uv0 *= extraborderize;
				uv1 *= extraborderize;
				uv2 *= extraborderize;
				p[0].uv = uv0 + uvcenter;
				p[1].uv = uv1 + uvcenter;
				p[2].uv = uv2 + uvcenter;

                float4 center = (p[0].pos+p[1].pos+p[2].pos)/3;
                float4 v0 = p[0].pos-center;
                float4 v1 = p[1].pos-center;
                float4 v2 = p[2].pos-center;
                v1 *= extraborderize;
                v0 *= extraborderize;
                v2 *= extraborderize;
                p[0].pos = UnityObjectToClipPos( v0+center );
                p[1].pos = UnityObjectToClipPos( v1+center );
                p[2].pos = UnityObjectToClipPos( v2+center );
				
				// Don't draw geometry if too far.
				if( length( _WorldSpaceCameraPos - mul( unity_ObjectToWorld, center ) ) > _FadeCull )
                {
					return;
                }
				
                triStream.Append( p[0] );
                triStream.Append( p[1] );
                triStream.Append( p[2] );
            }

			//MSDF https://github.com/MerlinVR/Unity-MSDF-Fonts
			
			float median(float r, float g, float b)
			{
				return max(min(r, g), min(max(r, g), b));
			}

			float MSDFn( float2 texcoord, out float sigmux )
			{
				float2 msdfUnit = _PixelRange / _MSDFTex_TexelSize.zw;
				float4 sampleCol = ((tex2D( _MSDFTex, texcoord ).rgba)-.25)*2;
				float sigDist = median(sampleCol.r, sampleCol.g, sampleCol.b) - 0.5;
				sigmux = max(dot(msdfUnit, 0.5 / fwidth(texcoord)), 1);
				sigDist *= sigmux; // Max to handle fading out to quads in the distance
				//float opacity = clamp(sigDist + 0.5, 0.0, 1.0);
				return sigDist;
			}

            fixed4 frag (g2f o) : COLOR
            {
                // this gives us text or not based on alpha, apparently
				float4 colo = 0.;
	
				// Black outline			
				float sigmux;
				float MSDF = MSDFn( o.uv, sigmux );
				colo.a = MSDF+.33*sigmux;
				colo.rgb = MSDF-.2*sigmux;
				colo = saturate(colo);
				colo.a *= pow( saturate( 1 + (_FadeNear - length( o.camrelpos )) ), 2 );
				o.color = colo;
                o.color *= _Colorize;         
                return o.color;
            }
            ENDCG
        }
    }
}
 
