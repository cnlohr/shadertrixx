Shader "cnlohr/SparkleCeiling"
{
    Properties
    {
        _TexData ("Data", 2D) = "white" {}
		_TwinkleSpeed ("Twinkle Speed", float) = 2.0
		_DeParallax ("Parallax", Range(0,1)) = 0.9
		_DPComp ("Parallax Layer Comp", Range(0,.3)) = 0.1
		_Scale( "Scale", float ) = 1.0
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
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
			
			#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y)))) 

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
				float2 parallaxuv : PUV;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _TexData;
            float4 _TexData_ST;
            float4 _TexData_TexelSize;
			float _TwinkleSpeed;
			float _DeParallax;
			float _Scale;
			float _DPComp;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _TexData);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				float3 worldVec = normalize( worldPos - _WorldSpaceCameraPos );

				o.parallaxuv = worldVec.xz * float2( 1,-1) / worldVec.y;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
			
			float3 huey( float fv )
			{
				return float3( sin( fv ), sin( fv + 2.094393 ), sin( fv + 4.188787 ) ) * 0.25 + 0.75;
			}
			
			float4 ComputeUVLayer( float2 uv, float offset )
			{
                // sample the texture
				float2 coord = uv * _TexData_TexelSize.zw;
				float2 fr = frac(coord + 0.5);
				float2 fw = max(abs(ddx(coord)), abs(ddy(coord)));
				uv += (saturate((fr-(1-fw)*0.5)/fw) - fr) * _TexData_TexelSize.xy;
                float3 col = tex2D(_TexData, uv);

				float inten = col.g*256 + col.b;
				
				inten = glsl_mod(inten + offset, 256.0);
				inten = min( inten, 4-inten );
				return float4( saturate(inten)*huey(((uv.x+uv.y)*100.0+inten*2.0)), col.r );
			}

            fixed4 frag (v2f i) : SV_Target
            {
				float2 uv1 = lerp( i.uv, i.parallaxuv, _DeParallax ) / _Scale;
				float4 colo = ComputeUVLayer( uv1, _Time.y*_TwinkleSpeed );
				float3 col = lerp( 0.0, colo.xyz, colo.www );
				
				// TRY COMMENTING THESE OUT if you don't want extra layers.
				uv1 = lerp( i.uv, i.parallaxuv, _DeParallax - _DPComp*1 ) / _Scale;
				colo = ComputeUVLayer( uv1, _Time.y*_TwinkleSpeed+50 );
				col += lerp( 0.0, colo.xyz, colo.www );

				uv1 = lerp( i.uv, i.parallaxuv, _DeParallax - _DPComp*2 ) / _Scale;
				colo = ComputeUVLayer( uv1, _Time.y*_TwinkleSpeed+100 );
				col += lerp( 0.0, colo.xyz, colo.www );
				
				
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return float4( col, 1.0 );
            }
            ENDCG
        }
    }
}
