Shader "Snowland/SnowTop"
{
    Properties
    {
        _SnowCalcCRT ("Texture", 2D) = "white" {}
		_BottomCameraOffset( "Bottom Camera Y Offset", float ) = -0.5
		_CameraSpanDimension( "Camera Span Dimension", float ) = 70.0
		_SnowlandOffset( "Snowland Offset", Vector) = (8.6, -3.3, -16.5, 0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGINCLUDE
			#pragma require geometry
			#pragma require tessHW
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
				float4 wpos : TEXCOORD4;
				uint4 batchID : TEXCOORD5;
				float tessamt : TEXCOORD6;
            };

            struct g2f
            {
                float4 rpos : TEXCOORD0;
                UNITY_FOG_COORDS(1)
				float3 bary : TEXCOORD3;
                float4 vertex : SV_POSITION;
				float2 tc : TEXCOORD4;
				float4 wpos : TEXCOORD5;
            };

            sampler2D _SnowCalcCRT;
			float4 _SnowCalcCRT_TexelSize;
			float _BottomCameraOffset;
			float _CameraSpanDimension;
			float4 _SnowlandOffset;

            vtx vert (appdata v)
            {
                vtx o;
                o.pos = v.vertex;
                UNITY_TRANSFER_FOG(o,o.vertex);
				o.batchID = uint4( v.vertexID / 6, 0, 0, 0 );
				//o.wpos = float4( mul( unity_ObjectToWorld, v.vertex.xyz, 1. );
				o.wpos = mul( unity_ObjectToWorld,( v.vertex.xyzw ) );
				
				float howOrtho = UNITY_MATRIX_P._m33; // instead of unity_OrthoParams.w
				#if defined(USING_STEREO_MATRICES)
					float3 PlayerCenterCamera = (
						float3(unity_StereoCameraToWorld[0][0][3], unity_StereoCameraToWorld[0][1][3], unity_StereoCameraToWorld[0][2][3]) +
						float3(unity_StereoCameraToWorld[1][0][3], unity_StereoCameraToWorld[1][1][3], unity_StereoCameraToWorld[1][2][3]) ) * 0.5;
				#else
					float3 PlayerCenterCamera = _WorldSpaceCameraPos.xyz;
				#endif


			
				//Difference:              5   7    11    13    17     19    23    24?
				//Number of subdivisons: 1   6   13    24    37     54    73    96	120?
				#define tessellationAmountMax 15
				#define tessellationAmountMin 0


				float tm = 1;

				// Only tessellate for normal cameras.
				if( howOrtho < 0.5 )
				{
					float worldist = length( (o.wpos - PlayerCenterCamera) * float3( 1, .5, 1 ) );
					tm = 10./worldist;
					tm = clamp( tm, tessellationAmountMin, tessellationAmountMax );
				}
				
				o.tessamt = tm;
                return o;
            }

			struct tessFactors
			{
				float edgeTess[3] : SV_TessFactor;
				float insideTess : SV_InsideTessFactor;
			};

			tessFactors hullConstant(InputPatch<vtx, 3> I, uint triID : SV_PrimitiveID)
			{
				tessFactors o = (tessFactors)0;
				float3 tm = float3( I[0].tessamt, I[1].tessamt, I[2].tessamt );
				tm -= .1;
				tm = clamp( tm,tessellationAmountMin+0.01, tessellationAmountMax );
				o.edgeTess[0] = tm[2]+tm[1];
				o.edgeTess[1] = tm[0]+tm[2];
				o.edgeTess[2] = tm[0]+tm[1];
				o.insideTess = (tm.x+tm.y+tm.z)/2.-.1;
				return o;
			}
		 
			[domain("tri")]
			[partitioning("fractional_odd")] // Or fractional_odd
			[outputtopology("triangle_cw")]
			[patchconstantfunc("hullConstant")]
			[outputcontrolpoints(3)]
			vtx hull( InputPatch<vtx, 3> IN, uint uCPID : SV_OutputControlPointID )
			{
				vtx o = (vtx)0;
				o.pos = IN[uCPID].pos;
				o.wpos = IN[uCPID].wpos;
				o.batchID = IN[uCPID].batchID.xyzw;
				return o;
			}
	 
			[domain("tri")]
			vtx dom( tessFactors HSConstantData, const OutputPatch<vtx, 3> IN, float3 bary : SV_DomainLocation )
			{
				vtx o = (vtx)0;
				
				float3 barya = bary;
				#if 0
				if( barya.z + barya.y < 1 )
				{
					barya.zy /= (floor(HSConstantData.edgeTess[0])+1-frac(HSConstantData.edgeTess[0]))/floor(HSConstantData.edgeTess[0]);
					barya.x = 1. - barya.y - barya.z;
				}
				if( barya.x + barya.z < 1 )
				{
					barya.xz /= (floor(HSConstantData.edgeTess[1])+1-frac(HSConstantData.edgeTess[1]))/floor(HSConstantData.edgeTess[1]);
					barya.y = 1. - barya.x - barya.z;
				}
				if( barya.x + barya.y < 1 )
				{
					barya.xy /= (floor(HSConstantData.edgeTess[2])+1-frac(HSConstantData.edgeTess[2]))/floor(HSConstantData.edgeTess[2]);
					barya.z = 1. - barya.x - barya.y;
				}
				#endif
				o.pos  = barya.x * IN[0].pos +  barya.y * IN[1].pos +  barya.z * IN[2].pos;
				o.wpos = barya.x * IN[0].wpos + barya.y * IN[1].wpos + barya.z * IN[2].wpos;
			//	o.batchID = uint4( IN[0].batchID.x, bary.xy*float2((TESS_DIVX+0.5), (TESS_DIVY+0.5)), IN[0].batchID.w);
				return o;
			}
			
			float4 CalcPos( float4 opos, out float2 tc, out float4 wpos )
			{
				wpos = mul( unity_ObjectToWorld, opos );
				tc = (wpos.xz-_SnowlandOffset.xz)/_CameraSpanDimension+0.5;
				float4 SnowData = tex2Dlod(_SnowCalcCRT, float4(tc, 0.0, 0.) );
				float howOrtho = UNITY_MATRIX_P._m33; // instead of unity_OrthoParams.w
				if( howOrtho < 0.5 )
				{
					wpos.y += SnowData.y;  // Only give snow depth if not on ortho cameara.
				}
				float4 ov = UnityWorldToClipPos( wpos );
				return ov;
			}

			
			[maxvertexcount(3)]
			void geo(triangle vtx p[3], inout TriangleStream<g2f> triStream, uint id : SV_PrimitiveID)
			{
				float3 n0, n1, n2;
				float2 tc0, tc1, tc2;
				float4 wp0 = 1, wp1 = 1, wp2 = 1;
				float4 cp0 =  CalcPos( p[0].pos, tc0, wp0 );
				float4 cp1 =  CalcPos( p[1].pos, tc1, wp1 );
				float4 cp2 =  CalcPos( p[2].pos, tc2, wp2 );
				
				//if( length( cp0 ) == 0 || length( cp1 ) == 0 || length( cp2 ) == 0 ) return;
				//if( length( float3( hp0 - hp1, hp1 - hp2, hp0 - hp2 ) ) > 0.2 ) return;
				g2f pIn;
				pIn.vertex = cp0;
				pIn.rpos = p[0].pos;
				pIn.wpos = wp0;
				pIn.bary = float3( 1, 0, 0 );
				pIn.tc = tc0;
				triStream.Append(pIn);

				pIn.vertex = cp1;
				pIn.rpos = p[1].pos;
				pIn.wpos = wp1;
				pIn.bary = float3( 0, 1, 0 );
				pIn.tc = tc1;
				triStream.Append(pIn);

				pIn.vertex = cp2;
				pIn.rpos = p[2].pos;
				pIn.wpos = wp2;
				pIn.bary = float3( 0, 0, 1 );
				pIn.tc = tc2;
				triStream.Append(pIn);
			}
			
			ENDCG
			CGPROGRAM
			
						// normal should be normalized, w=1.0
			//NOTE: We can't do this here -> We aren't using sample probe volumes :(
			half3 SHEvalLinearL0L1_SampleProbeVolumeVert (half4 normal, float3 worldPos)
			{
				const float transformToLocal = unity_ProbeVolumeParams.y;
				const float texelSizeX = unity_ProbeVolumeParams.z;

				//The SH coefficients textures and probe occlusion are packed into 1 atlas.
				//-------------------------
				//| ShR | ShG | ShB | Occ |
				//-------------------------

				float3 position = (transformToLocal == 1.0f) ? mul(unity_ProbeVolumeWorldToObject, float4(worldPos, 1.0)).xyz : worldPos;
				float3 texCoord = (position - unity_ProbeVolumeMin.xyz) * unity_ProbeVolumeSizeInv.xyz;
				texCoord.x = texCoord.x * 0.25f;

				// We need to compute proper X coordinate to sample.
				// Clamp the coordinate otherwize we'll have leaking between RGB coefficients
				float texCoordX = clamp(texCoord.x, 0.5f * texelSizeX, 0.25f - 0.5f * texelSizeX);

				// sampler state comes from SHr (all SH textures share the same sampler)
				texCoord.x = texCoordX;
				half4 SHAr = UNITY_SAMPLE_TEX3D_SAMPLER_LOD(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord, 0.);

				texCoord.x = texCoordX + 0.25f;
				half4 SHAg = UNITY_SAMPLE_TEX3D_SAMPLER_LOD(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord, 0.);

				texCoord.x = texCoordX + 0.5f;
				half4 SHAb = UNITY_SAMPLE_TEX3D_SAMPLER_LOD(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord, 0.);

				// Linear + constant polynomial terms
				half3 x1;
				x1.r = dot(SHAr, normal);
				x1.g = dot(SHAg, normal);
				x1.b = dot(SHAb, normal);

				return x1;
			}

            fixed4 frag (g2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = 1.;
				
				float3 worldPos = i.wpos;//mul( unity_ObjectToWorld, float4( i.rpos.xyz, 1. ) ).xyz;

				// For drawing barycentric lines.
				const float extrathickness = -0.01;
				const float sharpness = 5.;//1./100.0;
				float baryo = min( min( i.bary.x, i.bary.y ), i.bary.z );
				baryo = baryo;
				baryo = ( baryo + extrathickness ) * sharpness / pow( length( ddx( i.bary ) ) * length( ddy( i.bary ) ), .25 );
				baryo = clamp( baryo, 0.0, 1.0 );
	
				col.rgb = baryo;
				
				float2 tc = i.tc;
				float4 SnowData = tex2Dlod(_SnowCalcCRT, float4(tc, 0.0, 0.) );

				float3 normal;
				float4 dnx = tex2Dlod(_SnowCalcCRT, float4(tc - float2( _SnowCalcCRT_TexelSize.x, 0 ), 0.0, 0.) ) - 
							tex2Dlod(_SnowCalcCRT, float4(tc + float2( _SnowCalcCRT_TexelSize.x, 0 ), 0.0, 0.) );
				float4 dny = tex2Dlod(_SnowCalcCRT, float4(tc - float2( 0, _SnowCalcCRT_TexelSize.y ), 0.0, 0.) ) - 
							tex2Dlod(_SnowCalcCRT, float4(tc + float2( 0, _SnowCalcCRT_TexelSize.y ), 0.0, 0.) );

				float3 n = float3( dnx.y, .05, dny.y ); //0.02 controls the vividity of the normals.
				n = normalize( n );
				normal = mul( unity_ObjectToWorld, n );
				
				
				col.rgb *= SHEvalLinearL0L1_SampleProbeVolumeVert (float4(normal,1.), worldPos);
				//col.xyz = worldPos;
				//XXX TODO: Fix normals here.

				//col.rgb = (saturate(dot(_WorldSpaceLightPos0.xyz, normal))+.1)*.8;
				
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
		
		Pass
		{
			Tags {"LightMode"="ShadowCaster"}
			Cull Off
			CGPROGRAM
			

            fixed4 frag (g2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = 1.;
                return col;
            }
            ENDCG
		}
    }
}
