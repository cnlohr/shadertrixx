Shader "Unlit/BarycentricLines"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma geometry geo
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2g
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 pos : SV_POSITION;
            };

            struct g2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
				float3 bary : TEXCOORD3;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2g vert (appdata v)
            {
                v2g o;
                o.pos = v.vertex;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
			
			
			[maxvertexcount(3)]
			void geo(triangle v2g p[3], inout TriangleStream<g2f> triStream, uint id : SV_PrimitiveID)
			{
				g2f pIn;
				pIn.vertex =  UnityObjectToClipPos( p[0].pos );
				pIn.uv = p[0].uv;
				pIn.bary = float3( 1, 0, 0 );
				triStream.Append(pIn);

				pIn.vertex =  UnityObjectToClipPos( p[1].pos );
				pIn.uv = p[1].uv;
				pIn.bary = float3( 0, 1, 0 );
				triStream.Append(pIn);

				pIn.vertex =  UnityObjectToClipPos( p[2].pos );
				pIn.uv = p[2].uv;
				pIn.bary = float3( 0, 0, 1 );
				triStream.Append(pIn);
			}
			
			

            fixed4 frag (g2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = 1.;
				
								
				const float extrathickness = -0.01;
				const float sharpness = 5.;//1./100.0;
				float baryo = min( min( i.bary.x, i.bary.y ), i.bary.z );
				baryo = baryo;
				baryo = ( baryo + extrathickness ) * sharpness / pow( length( ddx( i.bary ) ) * length( ddy( i.bary ) ), .25 );
				baryo = clamp( baryo, 0.0, 1.0 );
	
				col.rgb = baryo;
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
