Shader "Snowland/SnowTop"
{
    Properties
    {
        _SnowCalcCRT ("Texture", 2D) = "white" {}
		_CameraSpanDimension( "Camera Span Dimension", float ) = 16.0
		_BottomCameraOffset( "Bottom Camera Y Offset", float ) = -0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma geometry geo
			
			#pragma hull hull
			#pragma domain dom


            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
				uint vertexID : SV_VertexID;
            };

            struct vtx
            {
                UNITY_FOG_COORDS(1)
                float4 pos : SV_POSITION;
				uint4 batchID : TEXCOORD5;
            };

            struct g2f
            {
                float4 rpos : TEXCOORD0;
                UNITY_FOG_COORDS(1)
				float3 bary : TEXCOORD3;
                float4 vertex : SV_POSITION;
				float3 normal : NORMAL;
            };

            sampler2D _SnowCalcCRT;
			float4 _SnowCalcCRT_TexelSize;
			float _CameraSpanDimension;
			float _BottomCameraOffset;

            vtx vert (appdata v)
            {
                vtx o;
                o.pos = v.vertex;
                UNITY_TRANSFER_FOG(o,o.vertex);
				o.batchID = uint4( v.vertexID / 6, 0, 0, 0 );
                return o;
            }
			
			//Difference:              5   7    11    13    17     19    23    24?
			//Number of subdivisons: 1   6   13    24    37     54    73    96	120?
			#define tessellationAmount 50

			struct tessFactors
			{
				float edgeTess[3] : SV_TessFactor;
				float insideTess : SV_InsideTessFactor;
			};

			tessFactors hullConstant(InputPatch<vtx, 3> I, uint triID : SV_PrimitiveID)
			{
				tessFactors o = (tessFactors)0;
				o.edgeTess[0] = tessellationAmount;
				o.edgeTess[1] = tessellationAmount;
				o.edgeTess[2] = tessellationAmount;
				o.insideTess = tessellationAmount;
				return o;
			}
		 
			[domain("tri")]
			[partitioning("integer")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("hullConstant")]
			[outputcontrolpoints(3)]
			vtx hull( InputPatch<vtx, 3> IN, uint uCPID : SV_OutputControlPointID )
			{
				vtx o = (vtx)0;
				o.pos = IN[uCPID].pos;
				o.batchID = IN[uCPID].batchID.xyzw;
				return o;
			}
	 
			[domain("tri")]
			vtx dom( tessFactors HSConstantData, const OutputPatch<vtx, 3> IN, float3 bary : SV_DomainLocation )
			{
				vtx o = (vtx)0;
	
				o.pos = bary.x * IN[0].pos + bary.y * IN[1].pos + bary.z * IN[2].pos;
			//	o.batchID = uint4( IN[0].batchID.x, bary.xy*float2((TESS_DIVX+0.5), (TESS_DIVY+0.5)), IN[0].batchID.w);
				return o;
			}
			
			float4 CalcPos( float4 opos, out float3 normal )
			{
				float2 tc = opos.xz+0.5;
				float4 SnowData = tex2Dlod(_SnowCalcCRT, float4(tc, 0.0, 0.) );
				opos.y += SnowData.x + SnowData.y + _BottomCameraOffset - 0.02;//XXX Offset to acutally push snow.
				float4 ov = UnityObjectToClipPos( opos  * float4(_CameraSpanDimension,1,_CameraSpanDimension,1) );
				if( SnowData.w > 0.9 ) ov = 0.;
				
				
				float4 dnx = tex2Dlod(_SnowCalcCRT, float4(tc - float2( _SnowCalcCRT_TexelSize.x, 0 ), 0.0, 0.) ) - 
							tex2Dlod(_SnowCalcCRT, float4(tc + float2( _SnowCalcCRT_TexelSize.x, 0 ), 0.0, 0.) );
				float4 dny = tex2Dlod(_SnowCalcCRT, float4(tc - float2( 0, _SnowCalcCRT_TexelSize.y ), 0.0, 0.) ) - 
							tex2Dlod(_SnowCalcCRT, float4(tc + float2( 0, _SnowCalcCRT_TexelSize.y ), 0.0, 0.) );
				float3 n = float3( dnx.y, .03, dny.y );
				n = normalize( n );
				normal = mul( unity_ObjectToWorld, n );
				return ov;
			}

			
			[maxvertexcount(3)]
			void geo(triangle vtx p[3], inout TriangleStream<g2f> triStream, uint id : SV_PrimitiveID)
			{
				float3 n0, n1, n2;
				float4 cp0 =  CalcPos( p[0].pos, n0 );
				float4 cp1 =  CalcPos( p[1].pos, n1 );
				float4 cp2 =  CalcPos( p[2].pos, n2 );
				
				if( length( cp0 ) == 0 || length( cp1 ) == 0 || length( cp2 ) == 0 ) return;
				g2f pIn;
				pIn.vertex = cp0;
				pIn.rpos = p[0].pos;
				pIn.bary = float3( 1, 0, 0 );
				pIn.normal = n0;
				triStream.Append(pIn);

				pIn.vertex = cp1;
				pIn.rpos = p[1].pos;
				pIn.bary = float3( 0, 1, 0 );
				pIn.normal = n1;
				triStream.Append(pIn);

				pIn.vertex = cp2;
				pIn.rpos = p[2].pos;
				pIn.bary = float3( 0, 0, 1 );
				pIn.normal = n2;
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
				
				float2 tc = i.rpos.xz+0.5;
				float4 SnowData = tex2Dlod(_SnowCalcCRT, float4(tc, 0.0, 0.) );

				col.rgb = SnowData.yyy;		
				col.rgb = (saturate(dot(_WorldSpaceLightPos0.xyz, i.normal))+.1)*.8;
				
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
