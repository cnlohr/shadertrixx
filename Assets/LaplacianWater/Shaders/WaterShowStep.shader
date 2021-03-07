Shader "Custom/WaterShow_TrySurface"
{
    Properties
    {
        _WaterCalcTex ("Calc Data", 2D) = "white" {}
        _WaterBottomTex ("Bottom Surface (RGB)", 2D) = "white" {}
		_Depth ("Water Depth", float ) = 0.33
		_Metallic ("Surface Metallicity", float ) = .66
		_Smoothness ("Surface Smoothness", float ) = .96
		_Murkiness( "Murkiness", float ) = 0.22
		_WaterMurkColor ("Water Murk Color", Color ) = (0.26,0.19,0.16,0.0)
		_IndexOfRefraction ("Water Index of Refraction", float ) = 1.33333
		_RippleIntensity ("Riple Intensity", float ) = 0.5
		_WaterBottomScaleX ("Water Bottom Scale X", float ) = 3
		_WaterBottomScaleY ("Water Bottom Scale Y", float ) = 3
		_BrightBoost("Albedo Boost", float)= 0.04
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

		#include "UnityCG.cginc"

        struct Input
        {
		    float3 viewDir;
            float2 uv_WaterBottomTex;
			float2 uv_WaterCalcTex;
			float3 worldPos;
        };

		sampler2D _WaterCalcTex;
		sampler2D _WaterBottomTex;

		float4 _WaterMurkColor;
		float _Murkiness;
		float _IndexOfRefraction;
		//float4 _WaterCalcTex_ST;
		//float4 _WaterBottomTex_ST;
		float _Depth, _Metallic, _Smoothness, _RippleIntensity;
		float _WaterBottomScaleX, _WaterBottomScaleY;
		float _BrightBoost;
		uniform float4 _WaterCalcTex_TexelSize;

        void surf (Input IN, inout SurfaceOutputStandard o)
		{
			// sample the texture
		
			//.xz is the interesting thing. (.x is amount) (.y is depth) (.z is the wavey bit)
			fixed4 amt  = tex2D(_WaterCalcTex, IN.uv_WaterCalcTex).xyzw; 
			fixed4 amtX = tex2D(_WaterCalcTex, IN.uv_WaterCalcTex + float2(_WaterCalcTex_TexelSize.x,0.0) ).xyzw; 
			fixed4 amtY = tex2D(_WaterCalcTex, IN.uv_WaterCalcTex + float2(0.0,_WaterCalcTex_TexelSize.y) ).xyzw; 
			fixed3 ripplenorm = fixed3( amtX.x - amt.x, amtY.x - amt.x, 0.0 );
			ripplenorm *= _RippleIntensity;
			if( length( ripplenorm ) > 0.999 ) ripplenorm /= length( ripplenorm )*1.01;
			ripplenorm.z = sqrt( 1. - length( ripplenorm ) );

			float3 viewVec = normalize( IN.viewDir ); 
			float3 viewVecWorld = normalize( mul( IN.viewDir, unity_ObjectToWorld ) );
			
			fixed3 viewVecUnderWater;

			//Snell's law.
			// n1 sin ( theta incident ) = n2 sin ( theta refracted )
			// The computation of the angles is annoying, especially to "set" the
			// angle on the other end.  I.e. calculating the angle isn't that bad.
			// basically just length( cross( n, i ) ) but, to rotate the correct amount
			// on the other end is painful. .. Or is it?
			
			//As vectors:
			// Stolen from: https://physics.stackexchange.com/a/436252
			// (n cross t)=μ(n cross i)
			// Solves to:
			// t=sqrt( 1−μ^2*(1−(n dot i)^2 ) )*n+μ*(i−(n dot i)*n)
			{
				float3 n = ripplenorm;
				float3 i = viewVec;
				float mu = 1./_IndexOfRefraction;
				float ndoti = dot( n, i );
				float det = 1 - mu*mu*(1-ndoti*ndoti);
				det = max( 0.3, det );
				if( det < 0 )
				{
					o.Albedo = _WaterMurkColor + _BrightBoost;
					return;
				}
				else
				{
					viewVecUnderWater = sqrt( det )*n + mu*(i-ndoti*n);
				}
			}
			
			float2 floor_deflection = (viewVecUnderWater.xy/viewVecUnderWater.z) * -1 * _Depth;
			float2 floorlookup = IN.uv_WaterBottomTex + floor_deflection;
			float DistanceToBottom = length( float3( floor_deflection.xy, _Depth ) ) + amt.z * _Depth;
			
			fixed4 watbot = tex2D(_WaterBottomTex, floorlookup*float2(_WaterBottomScaleX,_WaterBottomScaleY ));

			fixed4 nv = fixed4( watbot );
			
            o.Albedo =
				//nv;
				//float4( viewVec, 1.0 );
				//float4( floor_deflection, 0.0, 1.0);
				//DistanceToBottom;
				_BrightBoost + lerp( nv, _WaterMurkColor, pow( clamp( DistanceToBottom * _Murkiness, 0, 1 ), 0.4 ) );
            o.Metallic = _Metallic;
            o.Smoothness = _Smoothness;
			o.Normal = normalize( float3( ripplenorm.xyz ) );
            o.Alpha = 1.0;
		}

		ENDCG
	}
}
