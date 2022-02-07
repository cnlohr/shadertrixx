// From bgolus' Different methods for getting World Normal from Depth Texture, without any external script dependencies.
// https://gist.github.com/bgolus/a07ed65602c009d5e2f753826e8078a0

Shader "bgolus/WorldNormalFromDepth"
{
    Properties {
        [KeywordEnum(3 Tap, 4 Tap, Improved, Accurate)] _ReconstructionMethod ("Normal Reconstruction Method", Float) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100

        Pass
        {
            Cull Off
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _RECONSTRUCTIONMETHOD_3_TAP _RECONSTRUCTIONMETHOD_4_TAP _RECONSTRUCTIONMETHOD_IMPROVED _RECONSTRUCTIONMETHOD_ACCURATE

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;

            float getRawDepth(float2 uv) { return SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, float4(uv, 0.0, 0.0)); }

            // inspired by keijiro's depth inverse projection
            // https://github.com/keijiro/DepthInverseProjection
            // constructs view space ray at the far clip plane from the screen uv
            // then multiplies that ray by the linear 01 depth
            float3 viewSpacePosAtScreenUV(float2 uv)
            {
#if defined(USING_STEREO_MATRICES)
                float3 viewSpaceRay = mul(unity_StereoCameraInvProjection[UNITY_MATRIX_P._13 < 0], float4(uv * 2.0 - 1.0, 1.0, 1.0) * _ProjectionParams.z);
#else
                float3 viewSpaceRay = mul(unity_CameraInvProjection, float4(uv * 2.0 - 1.0, 1.0, 1.0) * _ProjectionParams.z);
#endif
                float rawDepth = Linear01Depth( getRawDepth(uv) );
                // Added by CNL - discard skybox.
                if( rawDepth >= .99999 ) discard;
                return viewSpaceRay * rawDepth;
            }
            float3 viewSpacePosAtPixelPosition(float2 vpos)
            {
                float2 uv = vpos * _CameraDepthTexture_TexelSize.xy;
                return viewSpacePosAtScreenUV(uv);
            }

        #if defined(_RECONSTRUCTIONMETHOD_3_TAP)

            // naive 3 tap normal reconstruction
            // accurate mid triangle normals, slightly diagonally offset on edges
            // artifacts on depth disparities

            // unity's compiled fragment shader stats: 41 math, 3 tex
            half3 viewNormalAtPixelPosition(float2 vpos)
            {
                // get current pixel's view space position
                half3 viewSpacePos_c = viewSpacePosAtPixelPosition(vpos + float2( 0.0, 0.0));

                // get view space position at 1 pixel offsets in each major direction
                half3 viewSpacePos_r = viewSpacePosAtPixelPosition(vpos + float2( 1.0, 0.0));
                half3 viewSpacePos_u = viewSpacePosAtPixelPosition(vpos + float2( 0.0, 1.0));

                // get the difference between the current and each offset position
                half3 hDeriv = viewSpacePos_r - viewSpacePos_c;
                half3 vDeriv = viewSpacePos_u - viewSpacePos_c;

                // get view space normal from the cross product of the diffs
                half3 viewNormal = normalize(cross(hDeriv, vDeriv));

                return viewNormal;
            }

        #elif defined(_RECONSTRUCTIONMETHOD_4_TAP)

            // naive 4 tap normal reconstruction
            // accurate mid triangle normals compared to 3 tap
            // no diagonal offset on edges, but sharp details are softened
            // worse artifacts on depth disparities than 3 tap
            // probably little reason to use this over the 3 tap approach

            // unity's compiled fragment shader stats: 50 math, 4 tex
            half3 viewNormalAtPixelPosition(float2 vpos)
            {
                // get view space position at 1 pixel offsets in each major direction
                half3 viewSpacePos_l = viewSpacePosAtPixelPosition(vpos + float2(-1.0, 0.0));
                half3 viewSpacePos_r = viewSpacePosAtPixelPosition(vpos + float2( 1.0, 0.0));
                half3 viewSpacePos_d = viewSpacePosAtPixelPosition(vpos + float2( 0.0,-1.0));
                half3 viewSpacePos_u = viewSpacePosAtPixelPosition(vpos + float2( 0.0, 1.0));

                // get the difference between the current and each offset position
                half3 hDeriv = viewSpacePos_r - viewSpacePos_l;
                half3 vDeriv = viewSpacePos_u - viewSpacePos_d;

                // get view space normal from the cross product of the diffs
                half3 viewNormal = normalize(cross(hDeriv, vDeriv));

                return viewNormal;
            }

        #elif defined(_RECONSTRUCTIONMETHOD_IMPROVED)

            // base on János Turánszki's Improved Normal Reconstruction
            // https://wickedengine.net/2019/09/22/improved-normal-reconstruction-from-depth/
            // this is a minor optimization over the original, using only 2 comparisons instead of 8
            // at the cost of two additional vector subtractions
            // sharpness of 3 tap with better handling of depth disparities
            // worse artifacts on convex edges than either 3 tap or 4 tap

            // unity's compiled fragment shader stats: 62 math, 5 tex
            half3 viewNormalAtPixelPosition(float2 vpos)
            {
                // get current pixel's view space position
                half3 viewSpacePos_c = viewSpacePosAtPixelPosition(vpos + float2( 0.0, 0.0));

                // get view space position at 1 pixel offsets in each major direction
                half3 viewSpacePos_l = viewSpacePosAtPixelPosition(vpos + float2(-1.0, 0.0));
                half3 viewSpacePos_r = viewSpacePosAtPixelPosition(vpos + float2( 1.0, 0.0));
                half3 viewSpacePos_d = viewSpacePosAtPixelPosition(vpos + float2( 0.0,-1.0));
                half3 viewSpacePos_u = viewSpacePosAtPixelPosition(vpos + float2( 0.0, 1.0));

                // get the difference between the current and each offset position
                half3 l = viewSpacePos_c - viewSpacePos_l;
                half3 r = viewSpacePos_r - viewSpacePos_c;
                half3 d = viewSpacePos_c - viewSpacePos_d;
                half3 u = viewSpacePos_u - viewSpacePos_c;

                // pick horizontal and vertical diff with the smallest z difference
                half3 hDeriv = abs(l.z) < abs(r.z) ? l : r;
                half3 vDeriv = abs(d.z) < abs(u.z) ? d : u;

                // get view space normal from the cross product of the two smallest offsets
                half3 viewNormal = normalize(cross(hDeriv, vDeriv));

                return viewNormal;
            }

        #elif defined(_RECONSTRUCTIONMETHOD_ACCURATE)

            // based on Yuwen Wu's Accurate Normal Reconstruction 
            // https://atyuwen.github.io/posts/normal-reconstruction/
            // basically as accurate as you can get!
            // no artifacts on depth disparities
            // no artifacts on edges
            // artifacts on triangles that are <3 pixels across

            // unity's compiled fragment shader stats: 66 math, 9 tex
            half3 viewNormalAtPixelPosition(float2 vpos)
            {
                // screen uv from vpos
                float2 uv = vpos * _CameraDepthTexture_TexelSize.xy;

                // current pixel's depth
                float c = getRawDepth(uv);

                // get current pixel's view space position
                half3 viewSpacePos_c = viewSpacePosAtScreenUV(uv);

                // get view space position at 1 pixel offsets in each major direction
                half3 viewSpacePos_l = viewSpacePosAtScreenUV(uv + float2(-1.0, 0.0) * _CameraDepthTexture_TexelSize.xy);
                half3 viewSpacePos_r = viewSpacePosAtScreenUV(uv + float2( 1.0, 0.0) * _CameraDepthTexture_TexelSize.xy);
                half3 viewSpacePos_d = viewSpacePosAtScreenUV(uv + float2( 0.0,-1.0) * _CameraDepthTexture_TexelSize.xy);
                half3 viewSpacePos_u = viewSpacePosAtScreenUV(uv + float2( 0.0, 1.0) * _CameraDepthTexture_TexelSize.xy);

                // get the difference between the current and each offset position
                half3 l = viewSpacePos_c - viewSpacePos_l;
                half3 r = viewSpacePos_r - viewSpacePos_c;
                half3 d = viewSpacePos_c - viewSpacePos_d;
                half3 u = viewSpacePos_u - viewSpacePos_c;

                // get depth values at 1 & 2 pixels offsets from current along the horizontal axis
                half4 H = half4(
                    getRawDepth(uv + float2(-1.0, 0.0) * _CameraDepthTexture_TexelSize.xy),
                    getRawDepth(uv + float2( 1.0, 0.0) * _CameraDepthTexture_TexelSize.xy),
                    getRawDepth(uv + float2(-2.0, 0.0) * _CameraDepthTexture_TexelSize.xy),
                    getRawDepth(uv + float2( 2.0, 0.0) * _CameraDepthTexture_TexelSize.xy)
                );

                // get depth values at 1 & 2 pixels offsets from current along the vertical axis
                half4 V = half4(
                    getRawDepth(uv + float2(0.0,-1.0) * _CameraDepthTexture_TexelSize.xy),
                    getRawDepth(uv + float2(0.0, 1.0) * _CameraDepthTexture_TexelSize.xy),
                    getRawDepth(uv + float2(0.0,-2.0) * _CameraDepthTexture_TexelSize.xy),
                    getRawDepth(uv + float2(0.0, 2.0) * _CameraDepthTexture_TexelSize.xy)
                );

                // current pixel's depth difference from slope of offset depth samples
                // differs from original article because we're using non-linear depth values
                // see article's comments
                half2 he = abs((2 * H.xy - H.zw) - c);
                half2 ve = abs((2 * V.xy - V.zw) - c);

                // pick horizontal and vertical diff with the smallest depth difference from slopes
                half3 hDeriv = he.x < he.y ? l : r;
                half3 vDeriv = ve.x < ve.y ? d : u;

                // get view space normal from the cross product of the best derivatives
                half3 viewNormal = normalize(cross(hDeriv, vDeriv));

                return viewNormal;
            }

        #endif


            half4 frag (v2f i) : SV_Target
            {
                // get view space normal at the current pixel position
                half3 viewNormal = viewNormalAtPixelPosition(i.pos.xy);

                // transform normal from view space to world space
                half3 WorldNormal = mul((float3x3)unity_MatrixInvV, viewNormal);
                
                // alternative that should work when using this for post processing
                // we have to invert the view normal z because Unity's view space z is flipped
                // thus the above code using unity_MatrixInvV is doing this flip, but the 
                // unity_CameraToWorld does not flip the z, so we have to do it manually
                // half3 WorldNormal = mul((float3x3)unity_CameraToWorld, viewNormal * half3(1.0, 1.0, -1.0));

                // visualize normal (assumes you're using linear space rendering)
                return half4(GammaToLinearSpace(WorldNormal.xyz * 0.5 + 0.5), 1.0);
            }
            ENDCG
        }
    }
}
