Shader "Custom/ShadertrixxFloor"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_Emission ("Emission (RGB)", Color ) = (1,1,1,1)
	}
	SubShader
	{
		// shadow caster rendering pass, implemented manually
		// using macros from UnityCG.cginc
		Pass
		{
			Tags {"LightMode"="ShadowCaster"}
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"

			struct v2f { 
				V2F_SHADOW_CASTER;
				float4 uv : TEXCOORD0;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				o.uv = v.texcoord;
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
		
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		struct Input
		{
			float2 uv_MainTex;
		};

		half _Glossiness;
		half _Metallic;
		float4 _Emission;
		float4 _Color;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)

		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			float4 cD = 0;
			float4 cE = 0;
			float2 uv = IN.uv_MainTex;
			
			fixed2 derivX = ddx( uv.xy );
			fixed2 derivY = ddy( uv.xy );
			float delta_max_sqr = max(dot(derivX, derivX), dot(derivY, derivY));
			float invsq = 1./sqrt(delta_max_sqr);
			//float2 ftsize = _MainTex_TexelSize.zw / _ResolutionDecimation;
			float2 ftsize = 50 / 1;
			invsq /= length( ftsize );

			//Don't aggressively show the pixels. (-.5)
			float LoD = invsq;


			float2 uvc = abs(frac( uv + 0.5 ) - 0.5);
			float muvc = min( uvc.x, uvc.y );

			float2 uvc1 = abs(frac( uv*2 + 0.5 ) - 0.5);
			float muvc1 = min( uvc1.x, uvc1.y );

			float2 uvc2 = abs(frac( uv*4 + 0.5 ) - 0.5);
			float muvc2 = min( uvc2.x, uvc2.y );
			
			float minuvc = min( min( muvc, muvc1 ), muvc2 );
			cD = lerp( saturate( (minuvc*60 - 1)*LoD ), 1, saturate(-LoD+.4) )*_Color;
			cE = saturate((muvc-.45)*40*LoD)*_Emission;
			
			
					
			o.Albedo = cD.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Emission = cE.rgb;
			o.Alpha = cD.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
