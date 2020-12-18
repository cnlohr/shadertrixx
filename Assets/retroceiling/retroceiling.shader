// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/retroceiling"
{
    Properties
    {
		parallax ("Parallax", float) = 1.0
        _Imagery ("Texture", 2D) = "white" {}
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

            #include "UnityCG.cginc"
			
			#define glsl_mod(x,y) abs(((x)-(y)*floor((x)/(y)))) 

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 pos : TEXCOORD1;
				float3 viewangle : TEXCOORD2;
				float3 normal : TEXCOORD3;
            };

            sampler2D _Imagery;
			uniform half2 _Imagery_TexelSize; 
            float4 _NoiseTex_ST;
			half parallax;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
				o.pos = v.vertex.xyz/v.vertex.w;
                o.uv = v.uv;
				o.viewangle = mul( unity_ObjectToWorld, v.vertex )- _WorldSpaceCameraPos.xyz;
				o.normal = mul ((float4x4)unity_ObjectToWorld, v.normal );
                return o;
            }

			half pattern1( float2 uv )
			{
				uv = glsl_mod( uv, 1.0 );
				return floor(1.1-min( uv.x, uv.y ));
			}

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
				fixed4 col = 0.0;
				half2 vaxy = i.viewangle.xy/i.viewangle.z*parallax;
				
				half intensity = 0.0;
				intensity += tex2D( _Imagery, float3( i.uv, 0.0 ) ).r;
				intensity += tex2D( _Imagery, float3( i.uv+vaxy, 0.0 ) ).g;
				intensity += tex2D( _Imagery, float3( i.uv+vaxy*2., 0.0 ) ).b;
				intensity += pattern1( i.uv+vaxy*3. );

				//Create a pattern.
				
				col = pow( intensity, .4 );
				col = fixed4(col.r*0.5, col.r*0.5-0.5, col.r*0.5-0.5, 1.0);
                return col;
            }
            ENDCG
        }
    }
}
