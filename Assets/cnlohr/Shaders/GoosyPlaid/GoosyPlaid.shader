Shader "Custom/GoosyPlaid"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
		_WorldScale ("World Scale", Range(0,10)) = 1.0
		_StippleMix ("Stippality", Range(0,1)) = 0.5
		_StippleFreq( "Stipple Frequency", float ) = 10.
		_PlaidWatch( "Which Plaid", float ) = 0
		_Emission ("Emission", float) = 0.
		_Albedo ("Albedo", float ) = 1.
		_Amplitude ("Amplitude", float) = 1
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
		#pragma vertex vert
        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

		#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y)))) 

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
			float3 localPos;
			float3 worldPos;
        };

        half _Glossiness;
        half _Metallic;
		half _StippleMix;
		half _StippleFreq;
		half _WorldScale;
		half _Emission, _Albedo;
        fixed4 _Color;
		float _PlaidWatch;
		float _Amplitude;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

 
		void vert (inout appdata_full v, out Input o) 
		{
			UNITY_INITIALIZE_OUTPUT(Input,o);
			o.localPos = v.vertex.xyz;
			o.worldPos =  mul(  unity_ObjectToWorld, v.vertex.xyzw );
		}
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			float3 worldpos = IN.worldPos*10.*_WorldScale;

			static const float4 plaidoffsets[3] = {
				float4( .5, .1, 0., 0 ),
				float4( -.1, 0, .3, -.1 ),
				float4( 0., 0, .7, -.1 ) };
			static const float4 plaidmuxAs[3] = {
				float4( .6, .76, 0., 0 ),
				float4( .6006, 1.01, .75, .6006 ),
				float4( .6006, 1.4, .75, .7 ) };
			static const float4 plaidmuxBs[3] = {
				float4( .42, .2, 0., 0 ),
				float4( 0, 0., 0., 0. ),
				float4( 0, 0., 0., 0. ) };
			static const float4 plaidscalAs[3] = {
				float4( 5., 5., 5., 0 ),
				float4( 4., 4., 8., 2 ),
				float4( 4., 4., 8., 2 ) };
			static const float4 plaidscalBs[3] = {
				float4( 20., 20., 20., 0 ),
				float4( 20., 20., 20., 20. ),
				float4( 20., 20., 20., 20. ) };
			static const float4 plaidoffsetAs[3] = {
				float4( 0., UNITY_PI, UNITY_PI, 0 ),
				float4( 0., 0., -UNITY_PI*.5, -UNITY_PI/4. ),
				float4( 0., 0., -UNITY_PI*.5, -UNITY_PI/4. ) };
			static const float4 plaidoffsetBs[3] = {
				float4( UNITY_HALF_PI, UNITY_HALF_PI, UNITY_HALF_PI, 0 ),
				float4( UNITY_HALF_PI, UNITY_HALF_PI, UNITY_HALF_PI, 0 ),
				float4( UNITY_HALF_PI, UNITY_HALF_PI, UNITY_HALF_PI, UNITY_HALF_PI ) };
			static const float4 wildcardColors[3] = {
				float4( 0, 0, 0, 0 ),
				float4( 1.1, 1.1, 1.1, 1. ),
				float4( 1.1, 1.1, 0.0, 1. ) };


			int fpi = floor( _PlaidWatch );//clamp( floor( _PlaidWatch ), 0, 1 );
			float fpv = _PlaidWatch - fpi;

			float4 plaidoffset   = lerp( plaidoffsets  [fpi], plaidoffsets  [fpi+1], fpv );
			float4 plaidmuxA     = lerp( plaidmuxAs    [fpi], plaidmuxAs    [fpi+1], fpv );
			float4 plaidmuxB     = lerp( plaidmuxBs    [fpi], plaidmuxBs    [fpi+1], fpv );
			float4 plaidscalA    = lerp( plaidscalAs   [fpi], plaidscalAs   [fpi+1], fpv );
			float4 plaidscalB    = lerp( plaidscalBs   [fpi], plaidscalBs   [fpi+1], fpv );
			float4 plaidoffsetA  = lerp( plaidoffsetAs [fpi], plaidoffsetAs [fpi+1], fpv );
			float4 plaidoffsetB  = lerp( plaidoffsetBs [fpi], plaidoffsetBs [fpi+1], fpv );
			float4 wildcardColor = lerp( wildcardColors[fpi], wildcardColors[fpi+1], fpv );

			//Next up is REDPLAD (lower frequency random bits)
			float3 plaidred = 
				sin( worldpos * plaidscalA.r + plaidoffsetA.r ) * plaidmuxA.r + plaidoffset.r+
				sin( worldpos * plaidscalB.r + plaidoffsetB.r ) * plaidmuxB.r;
			plaidred = max( 0., plaidred );
			plaidred = glsl_mod( plaidred, 1. );
			plaidred = step( 0.5, plaidred );

			float3 plaidgreen = 
				sin( worldpos * plaidscalA.g + plaidoffsetA.g ) * plaidmuxA.g + plaidoffset.g +
				sin( worldpos * plaidscalB.g + plaidoffsetB.g ) * plaidmuxB.g;
			plaidgreen = max( 0., plaidgreen );
			plaidgreen = glsl_mod( plaidgreen, 1. );
			plaidgreen = step( 0.5, plaidgreen );

			float3 plaidblue = 
				sin( worldpos * plaidscalA.b + plaidoffsetA.b ) * plaidmuxA.b + plaidoffset.b +
				sin( worldpos * plaidscalB.b + plaidoffsetB.b ) * plaidmuxB.b;
			plaidblue = max( 0., plaidblue );
			plaidblue = glsl_mod( plaidblue, 1. );
			plaidblue = step( 0.5, plaidblue );

			float3 plaidwild = 
				sin( worldpos * plaidscalA.a + plaidoffsetA.a ) * plaidmuxA.a + plaidoffset.a +
				sin( worldpos * plaidscalB.a + plaidoffsetB.a ) * plaidmuxB.a;
			plaidwild = max( 0., plaidwild );
			plaidwild = glsl_mod( plaidwild, 1. );
			plaidwild = step( 0.5, plaidwild );


			float4 cnonstipple = fixed4( 
				dot( plaidred, plaidred )/3,
				dot( plaidgreen, plaidgreen )/3,
				dot( plaidblue, plaidblue )/3,
				1. );

			float3 plaidwildc = wildcardColor * dot( plaidwild, plaidwild ) / 3.;
			cnonstipple += float4( plaidwildc, 0. );

			float stipplesel = glsl_mod( ( worldpos.x+worldpos.y+worldpos.z )*_StippleFreq, 1. );
			float3 sippleselect = 
				(stipplesel < 0.3333 )?float3( 1., 0., 0. ):
				(stipplesel < 0.6666 )?float3( 0., 1., 0. ):
					float3( 0., 0., 1. );
			plaidred *= sippleselect;
			plaidgreen *= sippleselect;
			plaidblue *= sippleselect;
			plaidwildc *= sippleselect.xxx;
			float4 cstipple = fixed4( 
				dot( plaidred, plaidred ),
				dot( plaidgreen, plaidgreen ),
				dot( plaidblue, plaidblue ),
				1. ) + float4( plaidwildc, 0. );

			float4 plaid = lerp( cnonstipple, cstipple, _StippleMix );
			c = lerp( c, plaid, 1.-c.a);
            o.Albedo = c.rgb * _Albedo * _Amplitude;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
			o.Emission = c.rgb * _Emission * _Amplitude;
            o.Alpha = c.a * _Amplitude;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
