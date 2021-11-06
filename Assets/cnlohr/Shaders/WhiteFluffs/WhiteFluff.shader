Shader "Unlit/WhiteFluff"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_BillboardSizeAdd( "Billboard Size", float) = 0
		_TANoiseTex ("TANoise", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Transparency" }
        LOD 100

        Pass
        {
            Tags {"LightMode"="ForwardBase"}
			ZWrite Off
			//Blend SrcAlpha OneMinusSrcAlpha
			Blend SrcColor One 
			
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

			#include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"
			#include "/Assets/AudioLink/Shaders/AudioLink.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
				float4 debugcolor : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			float _BillboardSizeAdd;

			float max3 (in float3 v) {
			  return max (max (v.x, v.y), v.z);
			}
			
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

            v2f vert (appdata v)
            {
                v2f o;
				float3 ilocalpos = (floor( v.vertex * 10. + 0.5 ) )/10.; //Where it should center around.
				float3 iworldpos = mul( unity_ObjectToWorld, float4( ilocalpos, 1. ) );

				float SyncTime = AudioLinkDecodeDataAsSeconds( ALPASS_GENERALVU_NETWORK_TIME );

				float3 ingridsize = float3( 50*.15, 50*.045, 50*.25 );
				float outgridsize = 20.;
				float nrelem = 10.;
				float fadeoutdistratio = .4;
				float maxfaderatio = 0.9; //final fadeout at this far.
				float _FlySpeed = 0.05;
				float FlyMux = 10.;
				float4 fluffcolor = float4(0.3,0.3,0.4,1.0); //If not overridden.
				float farview = outgridsize * nrelem/16.;
				float billboardsize = _BillboardSizeAdd;


				//We don't use unity_StereoCameraToWorld here because we don't want things to look like flat impostors.
				float3 PlayerCenterCamera = _WorldSpaceCameraPos.xyz;
				
				
				float3 worldpos = glsl_mod( (iworldpos/ingridsize)*outgridsize/nrelem - PlayerCenterCamera, outgridsize )
					+ PlayerCenterCamera - outgridsize/2.;
				float3 worldfloor = floor(worldpos+0.5)*outgridsize;
					
				//This is like a grid around the user.
				float3 calcworld = worldpos;
					
				//Calcworld is the virtual position.

				//Now place the real world position.

				float3 hitworld = calcworld;

				float3 positional_offset = (
					tanoise2_hq(
						float2(
							worldfloor.y*10+worldfloor.z*1.,
							SyncTime*_FlySpeed+worldfloor.x*2
						)
					) -0.5 ) * FlyMux;
				hitworld += positional_offset;


				//Uncomment to debug (Set objects to their centers)
				//hitworld = calcworld;
				
				
				float fadeout = max3( abs(_WorldSpaceCameraPos-hitworld) / farview );
				//If fadeout approaches 1 - need to fade out.  Otherwise we're close.
				
				float fadeamount = pow( min( max(maxfaderatio-fadeout,0.)/fadeoutdistratio, 1.),.99);
				//o.debugcolor = float4(max(hitworld*0.5,0.),1.);
				float3 gicolor = SHEvalLinearL0L1_SampleProbeVolumeVert( fixed4(0.,1.,0.,1.), hitworld );
				gicolor += SHEvalLinearL0L1_SampleProbeVolumeVert( fixed4(0.,-1.,0.,1.), hitworld );
				if( length(gicolor)>0.8 ) gicolor = normalize(gicolor)*0.8;
				o.debugcolor = float4(gicolor, 1.)*1.4*fadeamount.xxxx;
				//o.debugcolor = fadeamount.xxxx * fluffcolor;
				
				float3 hitworld_relative_to_camera = -hitworld + _WorldSpaceCameraPos;
				float3 viewangle = normalize( hitworld_relative_to_camera );
				float3 down = float3( 0, -1, 0 );
				float3 left = normalize( cross( down, viewangle ) );
				float2 rcuv = v.uv * 2.0 - 1.0;

				//If we want to keep it pointed straight at the camera, do this, otherwise,
				//use real up.
				float3 ldown = cross( viewangle, left );
				
				float3 usedown = ldown;//lerp( down, ldown, _TrackDownUp );

				float3 BillboardVertex = 
					-hitworld_relative_to_camera + _WorldSpaceCameraPos+
						( 
							float4(rcuv.x * left, 0 ) +
							float4(-rcuv.y * usedown, 0 ) 
						) * billboardsize * 1.0;
				float4 vout = mul( UNITY_MATRIX_VP, float4( BillboardVertex, 1.0 ) );
				o.vertex = vout;
				
	
					
//                o.vertex = UnityObjectToClipPos(v.vertex +
//					float4( sin(SyncTime/5.*2.555),cos(_Time.y/5.*3.2314),sin(_Time.y/5.*4.9581 ), 0. )*.1 );
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
				
                fixed4 col = i.debugcolor * (1.-length(i.uv*2.-1.));
				if( col.a > 0.1 )
				{
					//Do nothing
				}
				else
				{
					discard;
				}
				col.a = 1.;
				
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
