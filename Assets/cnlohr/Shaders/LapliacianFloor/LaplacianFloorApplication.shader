Shader "Custom/LaplacianFloorApplication"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
		
		_GIEmissionMux( "GI Emission Mux", float ) = 30.0
		_GIEmissionLOD( "GI Emission LOD", float ) = 5.0
		_RegEmissionMux( "Regular Emission Mux", float ) = 2.0
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
		
	    Pass
        {
            Name "META"
            Tags {"LightMode"="Meta"}
            Cull Off
            CGPROGRAM
 
            #include"UnityStandardMeta.cginc"
 
            sampler2D _GIAlbedoTex;
            fixed4 _GIAlbedoColor;
			float  _GIEmissionMux;
			float  _GIEmissionLOD;
            float4 frag_meta2 (v2f_meta i): SV_Target
            {
                // We're interested in diffuse & specular colors
                // and surface roughness to produce final albedo.
               
                FragmentCommonData data = UNITY_SETUP_BRDF_INPUT (i.uv);
                UnityMetaInput o;
                UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);
                fixed4 c = tex2D (_GIAlbedoTex, i.uv);
                o.Albedo = fixed3(c.rgb * _GIAlbedoColor.rgb);
                o.Emission = 
					tex2Dlod (_MainTex, float4( i.uv.xy, 0., _GIEmissionLOD )) * _GIEmissionMux;
                return UnityMetaFragment(o);
            }
           
            #pragma vertex vert_meta
            #pragma fragment frag_meta2
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature ___ _DETAIL_MULX2
            ENDCG
        }
       
	   
       
        Tags {"RenderType"="Opaque"}
        LOD 200
 
        CGPROGRAM
        // Physically-based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows nometa
        // Use Shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0
 
        sampler2D _MainTex;
 
        struct Input {
            float2 uv_MainTex;
        };
       
        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
		float _RegEmissionMux;
		
        void surf (Input IN,inout SurfaceOutputStandard o){
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex)* _Color;
            o.Albedo = c.rgb;
			o.Emission = c.rgb*_RegEmissionMux;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
	}
    FallBack "Diffuse"
}
