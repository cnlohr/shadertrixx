Shader "cnlohr/DepthViewer"
{
    Properties
    {
		[KeywordEnum(Norm, Depth, Lines, World)] _OutMode ("Out Mode", Int) = 1
    }


    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue" = "Overlay" }


        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // make fog work
            #pragma multi_compile_fog

			#pragma multi_compile_local _OUTMODE_NORM _OUTMODE_DEPTH _OUTMODE_LINES _OUTMODE_WORLD

            #include "UnityCG.cginc"

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
				float4 screenPosition : TEXCOORD1;
				float3 worldDirection : TEXCOORD2;
            };

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;
            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
				
				
				// Subtract camera position from vertex position in world
				// to get a ray pointing from the camera to this vertex.
				o.worldDirection = mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos;

				// Save the clip space position so we can use it later.
				// (There are more efficient ways to do this in SM 3.0+, 
				// but here I'm aiming for the simplest version I can.
				// Optimized versions welcome in additional answers!)
				o.screenPosition = o.vertex;//UnityObjectToClipPos(v.vertex);

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
				float4 col;

				// Compute projective scaling factor...
				float perspectiveDivide = 1.0f / i.screenPosition.w;

				// Scale our view ray to unit depth.
				float3 direction = i.worldDirection * perspectiveDivide;

				// Calculate our UV within the screen (for reading depth buffer)
				float2 screenUV = (i.screenPosition.xy * perspectiveDivide) * 0.5f + 0.5f;

				// No idea, Seems to fix lox's stuff.
				if (_ProjectionParams.x < 0)
					screenUV.y = 1 - screenUV.y; 

				// VR stereo support
				screenUV = UnityStereoTransformScreenSpaceTex(screenUV);

				// Read depth, linearizing into worldspace units.    
				float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV)));

				#if defined( _OUTMODE_NORM ) || defined( _OUTMODE_LINES )

					float2 invss = 1./_ScreenParams.xy;
					float depthmx = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV+float2(-invss.x,0))));
					float depthmy = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV+float2(0,-invss.y))));
					float depthpx = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV+float2(invss.x,0))));
					float depthpy = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV+float2(0,invss.y))));
					
					
					float3 cpmx = direction * depthmx;
					float3 cpmy = direction * depthmy;
					float3 cppx = direction * depthpx;
					float3 cppy = direction * depthpy;

					float3 normwx = (cppx - cpmx);
					float3 normwy = (cppy - cpmy);

					float2 comp = float2(
						dot( normwx, -direction ),
						dot( normwy, -direction ) );
						
					float rtdist = depth;
					float3 camnorm = float3( comp, depth*length(invss)  );

					#ifdef _OUTMODE_NORM
						float3 norm = cross( normwx, normwy );
						col = float4( normalize(camnorm), 1. );
					#endif
					
					#ifdef _OUTMODE_LINES

					//Find distance between adjacent points and center to identify deflections.
					//This does not work.  I don' tknow why.
					//float deltadepthx = length(cross(normalize(normwx),normalize(direction*depth-cpmx)) );
					//float deltadepthy = length(cross(normalize(normwy),normalize(direction*depth-cpmy)) );

					//Cheap find difference in midpoint - this does work, sort of but has issues at glancing angles on surfaces.
					float deltadepthx = ((depthmx-depthpx)/2 - (depth-depthpx))/depth;
					float deltadepthy = ((depthmy-depthpy)/2 - (depth-depthpy))/depth;
					float deldep = length( float2( deltadepthx, deltadepthy ) );
					col = deldep.xxxx*200;
					#endif
				#endif


				#ifdef _OUTMODE_WORLD
					// Advance by depth along our view ray from the camera position.
					// This is the worldspace coordinate of the corresponding fragment
					// we retrieved from the depth buffer.
					float3 worldspace = direction * depth + _WorldSpaceCameraPos;
					col = float4(frac(worldspace), 1.0f);
					clip( depth >= 999 ? -1 : 1 );
				#elif defined( _OUTMODE_DEPTH )
					depth -= length(i.worldDirection);
					col = depth.xxxx*.1;
				#endif
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
				
				col = min( col, 1.5 );
                return col;
            }
            ENDCG
        }
    }
}
