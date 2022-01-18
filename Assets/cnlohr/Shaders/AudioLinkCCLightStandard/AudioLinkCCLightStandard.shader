Shader "cnlohr/AudioLinkCCLightStandard"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_MetallicGlossMap("Metallic", 2D) = "white" {}
		[Normal] _BumpMap("Normal Map", 2D) = "bump" {}
		_EmissionMap("Emission", 2D) = "black" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_NoAudioLinkFadeSpeed( "No AduioLink Fade Speed", float ) = 0.1
		[ToggleUI] _DisableAudioLinkOverride( "Disable AudioLink Override", float ) = 0
		[ToggleUI] _UseModularLights( "Use Modular (less stable, but more interesting)", float ) = 1
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM

		#pragma surface surf Standard fullforwardshadows
		#pragma target 5.0

		#include "/Assets/AudioLink/Shaders/AudioLink.cginc"

		sampler2D _MainTex, _MetallicGlossMap, _EmissionMap, _BumpMap;

		struct Input
		{
			float2 uv_MainTex;
		};

		float _Glossiness;
		float _Metallic;
		float _NoAudioLinkFadeSpeed;
		float _DisableAudioLinkOverride;
		float _UseModularLights;
		float4 _Color;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)

		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			// Albedo comes from a texture tinted by color
			
			float4 col = _Color;
			if( AudioLinkIsAvailable() && !_DisableAudioLinkOverride )
				col.rgb *= AudioLinkData( (_UseModularLights>0.5)?ALPASS_CCLIGHTS:ALPASS_THEME_COLOR0 ).rgb;
			else
				col.rgb *= AudioLinkHSVtoRGB( float3( frac( _Time.y * _NoAudioLinkFadeSpeed ), 1, 1 ) );
			float4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = tex2D (_MetallicGlossMap, IN.uv_MainTex);
			o.Emission = tex2D( _EmissionMap, IN.uv_MainTex ) * col;
			o.Smoothness = _Glossiness;
			o.Normal = tex2D( _BumpMap, IN.uv_MainTex);
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
