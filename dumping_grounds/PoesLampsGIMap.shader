// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/PoesLampsXMess"
{
    Properties
    {
        _MainTex ("Texture Reg", 2D) = "white" {}
		_GIAlbedoTex ("Texture GI Albedo", 2D) = "white" {}
		_GIEmissionTex ("Texture GI Emission", 2D) = "white" {}
		_GIEmissionMux ("GI Emission Mux", float) = 10.0 
		_GIAlbedoMux ("GI Emission Mux", float) = 10.0 
		
    }
    SubShader
    {
	
	    Pass
        {
            Name "META"
            Tags {"LightMode"="Meta"}
            Cull Off
            CGPROGRAM
 
            #include"UnityStandardMeta.cginc"
 
			 
			struct v2f_meta2
			{
				float4 pos      : SV_POSITION;
				float4 uv       : TEXCOORD0;
			#ifdef EDITOR_VISUALIZATION
				float2 vizUV        : TEXCOORD1;
				float4 lightCoord   : TEXCOORD2;
			#endif
				float4 ecolor : TEXCOORD3;
			};

            sampler2D _GIAlbedoTex;
			sampler2D _GIEmissionTex;
            fixed4 _GIAlbedoTex_ST;
            float _GIAlbedoMux;
			float _GIEmissionMux;
			
            float4 frag_meta2 (v2f_meta2 i): SV_Target
            {
                // We're interested in diffuse & specular colors
                // and surface roughness to produce final albedo.
               
                FragmentCommonData data = UNITY_SETUP_BRDF_INPUT (i.uv);
                UnityMetaInput o;
                UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);
                fixed4 c = tex2D (_GIAlbedoTex, i.uv);
                o.Albedo = fixed3(c.rgb * _GIAlbedoMux);

				c = tex2D(_GIEmissionTex, i.uv);
                o.Emission = fixed3(c.rgb * _GIEmissionMux);
				
                return UnityMetaFragment(o);
            }
			

			v2f_meta2 vert_meta2 (VertexInput v)
			{
				v2f_meta2 o;
				o.pos = UnityMetaVertexPosition(v.vertex, v.uv1.xy, v.uv2.xy, unity_LightmapST, unity_DynamicLightmapST);
				o.uv = TexCoords(v);
				if( o.uv.y > 0.5 )
				o.ecolor = float4( 
					sin( (o.uv.x)*3. + _Time.z )*10.,
					sin( (o.uv.x)*3. + _Time.z + 2.1 )*10.,
					sin( (o.uv.x)*3. + _Time.z + 4.2 )*10.,
					1.)*.2;
				else
				o.ecolor = float4( 
					sin( (o.uv.x)*3. - _Time.z )*10.,
					sin( (o.uv.x)*3. - _Time.z + 2.1 )*10.,
					sin( (o.uv.x)*3. - _Time.z + 4.2 )*10.,
					1.)*.1;
			#ifdef EDITOR_VISUALIZATION
				o.vizUV = 0;
				o.lightCoord = 0;
				if (unity_VisualizationMode == EDITORVIZ_TEXTURE)
					o.vizUV = UnityMetaVizUV(unity_EditorViz_UVIndex, v.uv0.xy, v.uv1.xy, v.uv2.xy, unity_EditorViz_Texture_ST);
				else if (unity_VisualizationMode == EDITORVIZ_SHOWLIGHTMASK)
				{
					o.vizUV = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
					o.lightCoord = mul(unity_EditorViz_WorldToLight, mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)));
				}
			#endif
				return o;
			}
           
            #pragma vertex vert_meta2
            #pragma fragment frag_meta2
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature ___ _DETAIL_MULX2
            ENDCG
        }
		
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
			AlphaToMask True 
            CGPROGRAM


            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float2 uv3 : TEXCOORD2;
                float2 uv4 : TEXCOORD3;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
				float4 color : TEXCOORD1;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _GIAlbedoTex;
			sampler2D _GIEmissionTex;
            fixed4 _GIAlbedoTex_ST;
            float _GIAlbedoMux;
			float _GIEmissionMux;

            v2f vert (appdata v)
            {
                v2f o;
				float4 worldspace = mul( unity_ObjectToWorld, v.vertex);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				float3 origpos = float3( v.uv3, v.uv4.x );
				origpos = origpos.xyz;
				//o.color = float4( worldspace.xyz, 1 );
				//o.color = float4( worldspace.xxx, 1. );
                UNITY_TRANSFER_FOG(o,o.vertex);
				o.vertex = 0;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {

                // sample the texture
                fixed4 col = tex2D(_GIEmissionTex, i.uv);
				//col = float4( 1.-i.uv, 0., 1. );
				col.a = 1.;
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}