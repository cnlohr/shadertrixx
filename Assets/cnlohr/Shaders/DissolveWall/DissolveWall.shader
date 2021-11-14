Shader "Custom/DissolveWall"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _EmissionQty ("EmissionQty", float) = 0.0
		_EmissionOffset ("Emission Offset", float) = 0.0
		_GenOffset("Gen Offset", Range(0,2)) = 0.0
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



        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows alpha

		#include "/Assets/cnlohr/Shaders/hashwithoutsine/hashwithoutsine.cginc"
		#include "/Assets/AudioLink/Shaders/AudioLink.cginc"
        #pragma target 5.0

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
			float3 worldPos;
        };

        float _Glossiness;
        float _Metallic;
		float _EmissionQty, _EmissionOffset;
		float _GenOffset;
        fixed4 _Color;
		
		

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
			float dist = length( _WorldSpaceCameraPos - IN.worldPos );
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			
			dist = min( dist, 2.3 );

			float alpha = (csimplex3( IN.worldPos*5 + float3( 20, 20, 100+frac( AudioLinkDecodeDataAsSeconds( ALPASS_GENERALVU_NETWORK_TIME ) / 10000 ) * 5000 ) )*.75 + dist-_GenOffset);
            o.Albedo = c.rgb;
			o.Emission = saturate(c.rgb*_EmissionQty-_EmissionOffset)*saturate(alpha+1);
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
			
            o.Alpha = saturate(alpha);
        }
        ENDCG
    }
    FallBack "Diffuse"
}
