Shader "Custom/fallingcherryblossoms"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
		_Cutoff ("Alpha Cutoff", float) = 0.1
		_AlbedoBoost ("Albedo Boost", float)=1.1
		_EmissionBoost( "Emission Boost", float) = 0.1
		_TANoiseTex ("TANoise", 2D) = "white" {}
		_SpinSpeed ("Spin Speed", float)= 5.0
		_FlySpeed ("Fly Speed", float ) = .6
		_FallSpeed( "Fall Speed", float ) = 0.1
		_FlyMux ("Fly Distance", float) = 1.
		_FallDistance ("Fall Distance", float)=5
		_BillboardSize("Billboard Size", float)=.03

		_SpawnMuxX ("Spawn Distance X", float) = 1.
		_SpawnMuxY ("Spawn Distance Y", float) = 1.
		_SpawnMuxZ ("Spawn Distance Z", float) = 1.
		
		_BillboardVariance( "Billboard Variance", float ) = 1.
    }
    SubShader
    {
		AlphaToMask True 
		
        Blend SrcAlpha OneMinusSrcAlpha
       // ColorMask RGB

    //     AlphaTest Greater [_Cutoff] // specify alpha test: 
            // fragment passes if alpha is greater than _Cutoff 
		//Blend SrcColor One 
		//ZWrite Off

        Tags { "RenderType"="Opaque" }
		///Tags {"Queue" = "Transparent" "RenderType"="Transparent" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard
		#pragma vertex vert

		/* Outsider here, originally

			//Blend SrcAlpha OneMinusSrcAlpha
		*/

        #pragma target 4.0


		#include "../tanoise/tanoise.cginc"
		#include "../hashwithoutsine/hashwithoutsine.cginc"

        sampler2D _MainTex;
		
/*		struct appdata
		{
			float4 vertex : POSITION;
			float4 normal : NORMAL;
			float4 tangent : TANGENT;
			float2 texcoord : TEXCOORD0;
			float2 texcoord1 : TEXCOORD1;
			float2 texcoord2 : TEXCOORD2;
		};
*/

        struct Input
        {
            float2 uv_MainTex;
			float4 Normal;
			UNITY_FOG_COORDS(1)
			float4 Vertex : SV_POSITION;
			float4 debug;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
		float _EmissionBoost;
		float _AlbedoBoost;
		float _SpinSpeed;
		float _FlySpeed;
		float _FlyMux;
		float _FallSpeed;
		float _FallDistance;
		float _BillboardSize;
		float _SpawnMuxX;
		float _SpawnMuxY;
		float _SpawnMuxZ;
		float _BillboardVariance;
		
        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)
		
		
		// Rotation with angle (in radians) and axis
		//https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
		float3x3 AngleAxis3x3(float angle, float3 axis)
		{
			float c, s;
			sincos(angle, s, c);

			float t = 1 - c;
			float x = axis.x;
			float y = axis.y;
			float z = axis.z;

			return float3x3(
				t * x * x + c,      t * x * y - s * z,  t * x * z + s * y,
				t * x * y + s * z,  t * y * y + c,      t * y * z - s * x,
				t * x * z - s * y,  t * y * z + s * x,  t * z * z + c
			);
		}


		void vert (inout appdata_full v, out Input o)
		{
			float3 vin = v.vertex.xyz;
			//v.vertex.y *= 2.;
			//float fvam = fmod( v.texcoord.y, 0.5 )*.2;
			//float3 WorldSpace = mul( unity_ObjectToWorld, v.vertex )*1000.;
			//v.vertex.xz += float2( sin( _Time.y*2.3+WorldSpace.z*20 ), sin( v.vertex.x*10+_Time.y * 3.2 +WorldSpace.z*8) )*fvam;

			//This computes the center of the particle.
			float3 particlecenterworld = mul( unity_ObjectToWorld,float4(  (round( v.vertex.xyz * 2000 ) ) / 2000, 1. ) );
			float3 randomseed = hash33( particlecenterworld );

			//particlecenterworld could be ignored now if we want.
			
			float3 positional_offset = (
					tanoise2_hq(
						float2(
							randomseed.y*100+randomseed.z*10.,
							_Time.y*_FlySpeed+randomseed.x*20
						)
					) -0.5 ) * float3( _FlyMux, _FlyMux, _FlyMux );
					
			positional_offset += 
							( tanoise2_hq( float2( randomseed.y*100+randomseed.z*10., randomseed.x*20 )  ) - 0.5 )*
							float3( _SpawnMuxX, _SpawnMuxY, _SpawnMuxZ );
			
			particlecenterworld = positional_offset + mul( unity_ObjectToWorld, float4(0.,0.,0.,1.) );
			
			particlecenterworld.y += -glsl_mod(_FallSpeed * _Time.y + randomseed*1000, _FallDistance);

			
			float3 hitworld = particlecenterworld;
			
			
			//BILLBOARDING
				float3 hitworld_relative_to_camera = -hitworld + _WorldSpaceCameraPos;
				float3 viewangle = normalize( hitworld_relative_to_camera );
				float3 down = float3( 0, -1, 0 );
				float3 left = normalize( cross( down, viewangle ) );
				
				float2 thisuv = v.texcoord;
				if( thisuv.y < 0.0 )
				{
					thisuv.y = - thisuv.y;
					//Also be aware this is side B.
				}
				
				float2 rcuv = thisuv * 2.0 - 1.0;

				//If we want to keep it pointed straight at the camera, do this, otherwise,
				//use real up.
				float3 ldown = cross( viewangle, left );
				
				float3 usedown = ldown;//lerp( down, ldown, _TrackDownUp );
				float thisbillboardsize = _BillboardSize + _BillboardVariance * randomseed.x;
				float3 worldshift = 
					float3( 
							float3(rcuv.x * left ) +
							float3(-rcuv.y * usedown ) 
						) * thisbillboardsize * 1.0;
						
				//Now rotate worldshift to pirouette around.
				float3x3 rotmat = AngleAxis3x3( _Time.y * _SpinSpeed + randomseed.x * 6.28, normalize(randomseed*2.-1. ) );
				worldshift = mul( rotmat, worldshift );
				v.normal = mul( unity_WorldToObject, mul( rotmat, mul( unity_ObjectToWorld, v.normal ) ) );

				float3 BillboardVertex = -hitworld_relative_to_camera + _WorldSpaceCameraPos+ worldshift;
				hitworld = BillboardVertex;
			v.vertex = mul( unity_WorldToObject, float4( hitworld, 1. ) );

			//v.vertex = mul( unity_WorldToObject, float4( particlecenterworld + float3(thisuv.xy*0.2,0.), 1. ) );

			v.texcoord.y = v.texcoord.y * .5;
			UNITY_INITIALIZE_OUTPUT(Input,o);
			
			o.debug = float4( (floor(vin * 4000 + 0.5 ) )/2-6., 1. );
		}
		
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
			fixed4 cbase = tex2D (_MainTex, IN.uv_MainTex);
			
			//fixed4 cbase = IN.debug;
			
            fixed4 c = cbase * _Color * _AlbedoBoost;
            o.Albedo = c.rgb;
			o.Emission = c * _EmissionBoost;

            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;

			if( cbase.a < 0.5 ) discard;
            o.Alpha = cbase.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
