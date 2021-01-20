Shader "Custom/PoesLampsToSee"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _NormalTex ("Normal (RGB)", 2D) = "white" {}
        _MetallicTex ("Metallic (RGB)", 2D) = "white" {}
        _EmissionTex ("Emission Tex (RGB)", 2D) = "white" {}
        _EmissionMap ("Emission Map (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
		_Emissivitivity ("Emissivitivity", float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Lambert vertex:vert fullforwardshadows 
			//Not Standard, not available with vertex:vert

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;
        sampler2D _NormalTex;
        sampler2D _MetallicTex;
        sampler2D _EmissionTex;
		sampler2D _EmissionMap;
		
        struct Input
        {
            float2 uv_MainTex;
			float3 custom; //Not sure why this has to be float3.
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
		half _Emissivitivity;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)


		void vert (inout appdata_full v, out Input o) {
			//v.vertex.xyz += v.normal * _Amount;
			UNITY_INITIALIZE_OUTPUT(Input,o);
			o.custom = float3( v.texcoord1.xy, 0. );
		}
	  
        void surf (Input IN, inout SurfaceOutput o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
			
			float2 lightmaploc = IN.custom.xy;
			o.Emission = 
				tex2D(_EmissionTex, IN.uv_MainTex) *
				tex2D( _EmissionMap,  lightmaploc ) * _Emissivitivity;

            // Metallic and smoothness come from slider variables
            //o.Metallic = tex2D (_MetallicTex, IN.uv_MainTex) * _Metallic;
			o.Normal = UnpackNormal ( tex2D (_NormalTex, IN.uv_MainTex) );
            //o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
