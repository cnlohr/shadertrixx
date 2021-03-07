Shader "Custom/WaterComputeStep"
{
    Properties
    {
        _MainTex ("Depth Map Of Players", 2D) = "white" {}
        _MaskTex ("Water Mask (White=Solid)", 2D) = "black" {}
        _CopiedTex ("Data Frame of Previous", 2D) = "white" {}
		_ResetTrigger ("Reset Trigger (Set to 1 to reset)", float ) = 0.0
		_IIRDecay ("IIR Decay 0.9 to 1.0", float ) = 0.999
		_TurbulatorIntensity ("Turbulator Intensity", float) = 1.0
		_TimeConstant ("Time Constant", float ) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

		ZWrite Off

        Pass
        {
            CGPROGRAM
            #include "UnityCustomRenderTexture.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
			#pragma target 4.0
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            sampler2D _CopiedTex;
			sampler2D _MaskTex;
            float4 _MainTex_ST;
			float _ResetTrigger;
			float _IIRDecay;
			float _TimeConstant;
			float _TurbulatorIntensity;
			uniform float4 _CopiedTex_TexelSize;

            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				if( _ResetTrigger > 0.5 ) return fixed4( 0., 0., 0., 1. );
				float2 uv = IN.localTexcoord;
				
                // sample the texture
				fixed2 texcoord = fixed2( 1.0 - uv.r, uv.g );
				fixed4 mask = tex2D(_MaskTex, texcoord );
                fixed4 nv = tex2D(_MainTex, texcoord );
                fixed4 ov = tex2D(_CopiedTex, uv );
                fixed4 Left1 = tex2D(_CopiedTex, uv -fixed2(_CopiedTex_TexelSize.x,0.) );
                fixed4 Up1 = tex2D(_CopiedTex, uv   -fixed2(0.,_CopiedTex_TexelSize.y) );
                fixed4 Right1 = tex2D(_CopiedTex, uv+fixed2(_CopiedTex_TexelSize.x,0.) );
                fixed4 Down1 = tex2D(_CopiedTex, uv +fixed2(0.,_CopiedTex_TexelSize.y) );

				fixed timestep = _TimeConstant;

				fixed velocity = ov.z;

				//Use a simple cutoff ot determine if person is splashing.
				fixed vin = (nv.x>0.15)*1.;
				
				//If we have any blue, then we need to create waves.
				if( mask.b > 0.0 )
				{
					vin = mask.b * sin(_Time.y*20.*mask.g)*2.*_TurbulatorIntensity;
				}
				
				vin *= 2.;

#if 1
				//Normal water
				fixed diff = vin - ov.y;
#else
				//Really cool, stark effect with lower frequency ripples.  Was a bug.
				//fixed diff = vin- (float)(clamp(ov.y,0,0.1));
				fixed diff = vin - clamp(ov.y,0,.5);
#endif				
				
				fixed value = ov.x + diff*.3;

				fixed laplacian = 
					2.0*(
						(Left1.x+Right1.x)/2.0-value.x+(Up1.x+Down1.x)/2.0-value.x);

				laplacian = lerp( laplacian, 0.0, mask );
		
				velocity+=laplacian*timestep;
				value+=velocity*timestep;
			

				ov = fixed4( value*_IIRDecay, vin, velocity*_IIRDecay, 1. );

#if 0
				//Charles's weird thing
				fixed avgv = (ovA.b + ovB.b + ovC.b + ovD.b)/4.0;
				
				//Calm it down over time.
				ov.b = ov.b*.99+vin*.01;
				
				ov.b += (ovC.r - ovA.r + ovD.g - ovB.g)*.01;

				fixed dx = (ovA.b-vin) + (vin-ovC.b);
				fixed dy = (ovB.b-vin) + (vin-ovD.b);

				ov.r += dx * 1.0;
				ov.g += dy * 1.0;
				ov.rg = ov.rg + ovA.rg + ovB.rg +
					ovC.rg+ ovD.rg;
				ov.rg/=5;
#endif
				//ov = fixed4(0.,0.,0.,1.);
				//ov.r = 0.;
                return ov;
            }
            ENDCG
        }
    }
}
