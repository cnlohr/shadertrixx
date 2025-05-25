# shadertrixx

CNLohr's repo for his Unity assets and other shader notes surrounding VRChat, Unity and/or Basis.  This largely contains stuff made by other people but I have kind of collected.

Quick links to other useful resources and infodumps. Some information may be duplicated between locations.
- https://shaderwiki.skuld.moe/index.php/Main_Page
- https://github.com/pema99/shader-knowledge
- https://tips.orels.sh
- https://hilll.dev/thoughts/unity-shaders

## The most important trick

```hlsl
#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y)))) 
```

This makes a well behaved `mod` function that rounds down even when negative.  For instance, `glsl_mod(-0.3, 1)` is 0.7.

Also note: Using this trick in some situations actually produces smaller code than regular mod!!

Thanks, @d4rkpl4y3r - this originally actually comes from an epic bgolus forum post: https://forum.unity.com/threads/translating-a-glsl-shader-noise-algorithm-to-hlsl-cg.485750/

## Alert for early 2022

VRChat is switching to SPS-I.  Please perform the following to test your shaders against SPS-I. Do the following: Project Settings->Player->XR Settings: Add a mock HMD as an output and drag it to the top, then switch to single pass instanced in the dropdown below.

### Add instancing support

Add this to your appdata:
```hlsl
UNITY_VERTEX_INPUT_INSTANCE_ID;
```

Add this to your `v2f` struct:
```hlsl
UNITY_VERTEX_OUTPUT_STEREO;
```

Add this to your `vertex` shader:
```hlsl
UNITY_SETUP_INSTANCE_ID( v );
UNITY_INITIALIZE_OUTPUT( v2f, o );
UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );
```

In your `fragment` - or ANY other shaders that ostensibly take in the `v2f` struct, i.e. `patch`, `hull`:
```hlsl
UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );
```

If you are using a `domain` shader, you will need something like this:
```hlsl
UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(patch[0], data)
UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(data)
```

### Converting Camera Depth Texture
```hlsl
Was:
	sampler2D _CameraDepthTexture;
	float depth = LinearEyeDepth( UNITY_SAMPLE_DEPTH( tex2D( _CameraDepthTexture, screenUV ) ) );

Or:
	Texture2D _CameraDepthTexture;
	float depth = LinearEyeDepth( _CameraDepthTexture.Sample( sampler_CameraDepthTexture, screenUV ) );

Now:
	UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );
	float depth = LinearEyeDepth( SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, screenUV) );
```

*NOTE*: You may want to consider `GetLinearZFromZDepth_WorksWithMirrors` (see below).

## Struggling with shader type mismatches?

You can put this at the top of your shader to alert you to when you forgot a `float3` and wrote `float` by accident.

```hlsl
#pragma warning (default : 3206) // implicit truncation
```

## Basics of shader coding:

* Unity shader fundamentals: https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html
* From @Orels: quick reference for HLSL: https://developer.download.nvidia.com/cg/index_stdlib.html
* List of intrinsic functions: https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-intrinsic-functions
* The common built-in header for unity-provided functions: https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityCG.cginc
* Unity's built-in shader variables: https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html
* Defining parameters for your shader/material: https://docs.unity3d.com/Manual/SL-Properties.html
* Unity surface shader examples: https://docs.unity3d.com/Manual/SL-SurfaceShaderExamples.html
* List of all pragmas that you can use in shaders, become familiar with these: https://docs.unity3d.com/Manual/SL-PragmaDirectives.html

Unity's overview page: https://docs.unity3d.com/2019.4/Documentation/Manual/shader-writing.html

## Additional tricks

CNLohr Notes:
 * If you are going crazy fighting with the compiler, just try to use `#pragma skip_optimizations d3d11` and it will sometimes produce much clearer errors.
 * Sometimes adding `#pragma enable_d3d11_debug_symbols` will get the compiler to stop misbehaving.

From @Lyuma
 * `[flatten]` (UNITY_FLATTEN macro) to force both cases of an if statement or
 * force a branch with `[branch]` (UNITY_BRANCH macro);
 * force loop to unroll with `[unroll]` (UNITY_UNROLL) or
 * force a loop with `[loop]` (UNITY_LOOP)
 * force a jump table with `[forcecase]`
 * there's also `[call]` for if or switch statements I think, not sure exactly how it works.

### Treating textures as a linear array

From @d4rkpl4y3r - Use the order it's stored in VRAM (or generally close to it).  You can use `MortonIndex32` to get the coordinate associated with a linear element, and `DeinterleaveWithZero32` to go from a coordinate to a linear value.

```c
// adapted from: https://lemire.me/blog/2018/01/08/how-fast-can-you-bit-interleave-32-bit-integers/
uint InterleaveWithZero32(uint word)
{
    word = (word ^ (word << 8)) & 0x00ff00ff;
    word = (word ^ (word << 4)) & 0x0f0f0f0f;
    word = (word ^ (word << 2)) & 0x33333333;
    word = (word ^ (word << 1)) & 0x55555555;
    return word;
}

// adapted from: https://stackoverflow.com/questions/3137266/how-to-de-interleave-bits-unmortonizing
uint DeinterleaveWithZero32(uint word)
{
    word &= 0x55555555;
    word = (word | (word >> 1)) & 0x33333333;
    word = (word | (word >> 2)) & 0x0f0f0f0f;
    word = (word | (word >> 4)) & 0x00ff00ff;
    word = (word | (word >> 8)) & 0x0000ffff;
    return word;
}

uint2 MortonIndex32(uint index)
{
    return uint2(DeinterleaveWithZero32(index), DeinterleaveWithZero32(index >> 1));
}

uint DemortonIndex32(uint2 index)
{
    return InterleaveWithZero32(index.x) | (InterleaveWithZero32(index.y) << 1);
}
```

And if you want to advance along without unfurling everything...
```c
uint2 NextMortonIndex(uint2 index)
{
    uint2 mask = index ^ (index + 1);
    return index ^ uint2(mask.x & mask.y, (mask.x >> 1) & mask.y);
}
```


### Lyuma Beautiful Retro Pixels Technique

If you want to use pixels but make the boundaries between the pixels be less ugly, use this:
```hlsl
float2 coord = i.tex.xy * _MainTex_TexelSize.zw;
float2 fr = frac(coord + 0.5);
float2 fw = max(abs(ddx(coord)), abs(ddy(coord)));
i.tex.xy += (saturate((fr-(1-fw)*0.5)/fw) - fr) * _MainTex_TexelSize.xy;
```

Note: This technique is based off of this shader here: https://gist.github.com/lyuma/18bf52da92428340bab524a025b24101 which is originally based off of a shader by Lox.

You should also see Pixel Standard by S-ilent. https://twitter.com/silent0264/status/1386150307386720256

There is a similar technique from Bgolus, https://www.shadertoy.com/view/ltBfRD which introduces two functions:
```glsl
vec2 uv_aa_linear( vec2 uv, vec2 res, float width )
{
    uv = uv * res;
    vec2 uv_floor = floor(uv + 0.5);
    uv = uv_floor + clamp( (uv - uv_floor) / fwidth(uv) / width, -0.5, 0.5);
    return uv / res;
}

vec2 uv_aa_smoothstep( vec2 uv, vec2 res, float width )
{
    uv = uv * res;
    vec2 uv_floor = floor(uv + 0.5);
    vec2 uv_fract = fract(uv + 0.5);
    vec2 uv_aa = fwidth(uv) * width * 0.5;
    uv_fract = smoothstep(
        vec2(0.5) - uv_aa,
        vec2(0.5) + uv_aa,
        uv_fract
        );
    
    return (uv_floor + uv_fract - 0.5) / res;
}
```

Which looks really convincing, but the technique needs to be paired with something else if you ever expect your texture pixels to take less than 1px on the screen.


### Are you in a mirror?
Thanks, @Lyuma and @merlinvr for this one.

```hlsl
bool isMirror()
{
	return unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f;
}
```

Or a more succinct but confusing way from @OwenTheProgrammer
```hlsl
bool isMirror()
{
	//return unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f;
	return (asuint(unity_CameraProjection[2][0]) || asuint(unity_CameraProjection[2][1]));
}
```
Which translates to:
```
0: or r0.x, cb0[6].z, cb0[7].z
1: movc o0.xyzw, r0.xxxx, l(1.000000,1.000000,1.000000,1.000000), l(0,0,0,0)
2: ret 
```

For VRChat specifically we can use the shader globals more more a reliable mirror check.

```hlsl
uniform float _VRChatMirrorMode;

bool isMirror() { return _VRChatMirrorMode != 0; }
```

### Detecting if you are on Desktop, VR, Camera, etc.

For detecting eyes it is recommended to use the canonical [unity_StereoEyeIndex and related macros](https://docs.unity3d.com/Manual/SinglePassInstancing.html) for getting the correct information.

A helpful comment from error.mdl on why the old `UNITY_MATRIX_P._13` method is not reliable for detecting eyes:
> That component (UNITY_MATRIX_P._13) represents how much the projection center is shifted towards the left or right ((r + l) / (r -l)). 
> In most cases the projection center is always closer to the user's nose giving the widest peripheral vision, and this is what you're relying on. 
> However for single-screen headsets like the quest 2 and rift-s, (I think?) changing the IPD to larger values 
> shifts the center of the projection matrix outward, and for very high IPDs it could actually be inverted.

With that and some additional advice from d4rkpl4y3r and vetting from techanon we get:

```hlsl
bool isVR()
{
	#if defined(USING_STEREO_MATRICES)
		return true;
	#else
		return false;
	#endif
}

bool isRightEye()
{
	#if defined(USING_STEREO_MATRICES)
		return unity_StereoEyeIndex == 1;
	#else
		return false;
	#endif
}

bool isLeftEye() { return !isRightEye(); }

bool isDesktop() { return !isVR() && abs(UNITY_MATRIX_V[0].y) < 0.0000005; }
```

We use `#if defined(USING_STEREO_MATRICES)` instead of `#if UNITY_SINGLE_PASS_STEREO` 
in order to cover situations where multiview is involved, such as Quest.

For VRChat specifically, we can update the methods to use some shader globals to handle mirror situations more reliably.
Desktop will have left-eye/right-eye always be respectively true/false.

```hlsl
uniform float _VRChatMirrorMode;
uniform float3 _VRChatMirrorCameraPos;

bool isMirror() { return _VRChatMirrorMode != 0; }

bool isVR()
{
	#if defined(USING_STEREO_MATRICES)
		return true;
	#else
		return _VRChatMirrorMode == 1;
	#endif
}

bool isRightEye()
{
	#if defined(USING_STEREO_MATRICES)
		return unity_StereoEyeIndex == 1;
	#else
		return isVR() && mul(unity_WorldToCamera, float4(_VRChatMirrorCameraPos, 1)).x < 0;
	#endif
}
```

Add camera detection to the mix.  
Thanks, @scruffyruffles for this!

```hlsl
bool isVRHandCamera()
{
	return !isVR() && abs(UNITY_MATRIX_V[0].y) > 0.0000005;
}

bool isVRHandCameraPreview()
{
	return isVRHandCamera() && _ScreenParams.y == 720;
}

bool isPanorama()
{
	// Crude method
	// FOV=90=camproj=[1][1]
	return unity_CameraProjection[1][1] == 1 && _ScreenParams.x == 1075 && _ScreenParams.y == 1025;
}
```


With the [VRChat shader globals](https://creators.vrchat.com/worlds/vrc-graphics/vrchat-shader-globals) we can update one of the methods for more reliability.

```hlsl
uniform float _VRChatCameraMode;

bool isVRHandCamera()
{
	// old method
	// return !isVR() && abs(UNITY_MATRIX_V[0].y) > 0.0000005;
	// new method using the VRChat shader globals
	return _VRChatCameraMode == 1;
}
```

### Layers
Thanks, Lyuma!
```
First of all, make sure you have layers set up,
The common practice now is to add them by hand, using this reference:

http://vrchat.wikidot.com/worlds:layers

(The numbers are what matter). Edit -> Project Settings... -> Tags and Layers on the left pane.
The only important ones for avatars are:
9 -> Player
10 -> PlayerLocal
12 -> UIMenu
18 -> MirrorReflection
PlayerLocal = your local avatar with head chopped off
MirrorReflection = your local avatar as it appears in mirrors and cameras
Player = remote players
UIMenu = auxiliary layer that can be used for avatar UI (for example, a camera preview)
```


### Three's Utility Functions
```hlsl
//invert function from https://answers.unity.com/questions/218333/shader-inversefloat4x4-function.html, thank you d4rk
float4x4 inverse(float4x4 input)
{
	#define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
	//determinant(float3x3(input._22_23_23, input._32_33_34, input._42_43_44))

	float4x4 cofactors = float4x4(
		minor(_22_23_24, _32_33_34, _42_43_44),
		-minor(_21_23_24, _31_33_34, _41_43_44),
		minor(_21_22_24, _31_32_34, _41_42_44),
		-minor(_21_22_23, _31_32_33, _41_42_43),

		-minor(_12_13_14, _32_33_34, _42_43_44),
		minor(_11_13_14, _31_33_34, _41_43_44),
		-minor(_11_12_14, _31_32_34, _41_42_44),
		minor(_11_12_13, _31_32_33, _41_42_43),

		minor(_12_13_14, _22_23_24, _42_43_44),
		-minor(_11_13_14, _21_23_24, _41_43_44),
		minor(_11_12_14, _21_22_24, _41_42_44),
		-minor(_11_12_13, _21_22_23, _41_42_43),

		-minor(_12_13_14, _22_23_24, _32_33_34),
		minor(_11_13_14, _21_23_24, _31_33_34),
		-minor(_11_12_14, _21_22_24, _31_32_34),
		minor(_11_12_13, _21_22_23, _31_32_33)
	);
	#undef minor
	return transpose(cofactors) / determinant(input);
}

float4x4 worldToView()
{
	return UNITY_MATRIX_V;
}

float4x4 viewToWorld()
{
	return UNITY_MATRIX_I_V;
}

float4x4 viewToClip()
{
	return UNITY_MATRIX_P;
}

float4x4 clipToView()
{
	return inverse(UNITY_MATRIX_P);
}

float4x4 worldToClip()
{
	return UNITY_MATRIX_VP;
}

float4x4 clipToWorld()
{
	return inverse(UNITY_MATRIX_VP);
}
```

Determine vertical FoV.  Thanks @scruffyruffles
```hlsl
float t = unity_CameraProjection[1][1];
float fov = degrees( atan( 1.0 / t ) );
```

Thanks to several people in the shader discord... If in the `ShadowCaster` and you want to differentiate between rendering from the camera's point of view or from the light's point of view for a direcitonal light, you can check which you are running from with:

* `any(unity_LightShadowBias) == false` if rendering `_CameraDepthTexture` (Camera's point of view)
* `any(unity_LightShadowBias) == true`  if rendering some shadow map (From a light's point of view)

### Eye Center Position

Compute the position of the center of someone's face, for making effects that involve camera position changing geometry but are stereo fusable.
VRChat also provides a few global uniforms that we can use to make the PlayerCenterCamera work as expected in mirrors.

Thanks, @d4rkpl4y3r

```hlsl
uniform float _VRChatMirrorMode;
uniform float3 _VRChatMirrorCameraPos;

bool isMirror() { return _VRChatMirrorMode != 0; }

#if defined(USING_STEREO_MATRICES)
	float3 PlayerCenterCamera = ( unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1] ) / 2;
#else
	float3 PlayerCenterCamera = isMirror() ? _VRChatMirrorCameraPos : _WorldSpaceCameraPos.xyz;
#endif
```

Alternatively to get the raw value (I do not know why it was originally written this way)

For stereo view:
```hlsl
float3 PlayerCenterCamera = (
	float3(unity_StereoCameraToWorld[0][0][3], unity_StereoCameraToWorld[0][1][3], unity_StereoCameraToWorld[0][2][3]) +
	float3(unity_StereoCameraToWorld[1][0][3], unity_StereoCameraToWorld[1][1][3], unity_StereoCameraToWorld[1][2][3]) ) * 0.5;
```

## tanoise

Very efficient noise based on Toocanzs noise. https://github.com/cnlohr/shadertrixx/tree/main/Assets/cnlohr/Shaders/tanoise

## Defining Avatar Scale

The "magic ratio" is `view_y = head_to_wrist / 0.4537` (in t-pose) all unitless.

"It's mentioned many places that armspan is the defining scale, but that comment is more specific (armspan is 2 * head_to_wrist, and the ratio to height)" - Ben

## single-file C header library for unity texture writing

https://gist.github.com/cnlohr/c88980e560ecb403cae6c6525b05ab2f

## Multiply vector-by-quaterion

From @axlecrusher effectively using :
```hlsl
// Rotate v by q
float3 vector_quat_rotate( float3 v, float4 q )
{
	return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}

// Anti-rotate v by q
float3 vector_quat_unrotate( float3 v, float4 q )
{
	return v + 2.0 * cross(q.xyz, cross(q.xyz, v) - q.w * v);
}
```

Create a 2x2 rotation, can be applied to a 3-vector by saying vector.xz or other swizzle.  Not sure where this one came from
```hlsl
fixed2x2 mm2( fixed th ) // farbrice neyret magic number rotate 2x2
{
	fixed2 a = sin(fixed2(1.5707963, 0) + th);
	return fixed2x2(a, -a.y, a.x);
}
```
## Create a quaternion from two axes

Assuming to/from are normalized.

```hlsl
float3 half = normalize( from + to );
float4 quat = float4( cross( to, half ), dot( to, half ) );
```

Note that this does not do well in heavy opposition.


## Is your UV within the unit square?

```hlsl
any(i.uvs < 0 || i.uvs > 1)
```
```
0: lt r0.xy, v0.xyxx, l(0.000000, 0.000000, 0.000000, 0.000000)
1: lt r0.zw, l(0.000000, 0.000000, 1.000000, 1.000000), v0.xxxy
2: or r0.xy, r0.zwzz, r0.xyxx
3: or r0.x, r0.y, r0.x
4: sample_indexable(texture2d)(float,float,float,float) r0.y, v0.xyxx, t0.xwyz, s0
5: movc o0.xyzw, r0.xxxx, l(0,0,0,0), r0.yyyy
6: ret 
```
(From @d4rkpl4y3r)

And the much less readable and more ambiguous on edge conditions version:
```hlsl
any(abs(i.uvs-.5)>.5)
```
```
0: add r0.xy, v0.xyxx, l(-0.500000, -0.500000, 0.000000, 0.000000)
1: lt r0.xy, l(0.500000, 0.500000, 0.000000, 0.000000), |r0.xyxx|
2: or r0.x, r0.y, r0.x
3: sample_indexable(texture2d)(float,float,float,float) r0.y, v0.xyxx, t0.xwyz, s0
4: movc o0.xyzw, r0.xxxx, l(0,0,0,0), r0.yyyy
5: ret 
```
(From @scruffyruffles)

Or even more succinct, but very confusing:
```hlsl
saturate(v) == v
```
```
0: mov_sat r0.xy, v1.xyxx
1: eq r0.xy, r0.xyxx, v1.xyxx
2: and r0.x, r0.x, r0.y
3: and o0.xyzw, r0.xxxx, l(0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000)
4: ret 
```
But because you may not have the prototype you want you may need to add something like:
```hlsl
int withinUnitSquare(float2 uv)
{
	return (saturate(uv.x) == uv.x) & (saturate(uv.y) == uv.y);
}
```
(From @OwenTheProgrammer)

## Shadowcasting

Make sure to add a shadowcast to your shader, otherwise shadows will look super weird on you.  Just paste this bad boy in your subshader. This handles everything for SPS-I.

This is credit to @mochie

```hlsl
Pass
{
	Tags { "LightMode" = "ShadowCaster" }
	CGPROGRAM
	#pragma multi_compile_instancing
	#pragma multi_compile_shadowcaster

	#pragma vertex vert
	#pragma fragment frag

	#include "UnityCG.cginc"

	struct appdata
	{
		float4 vertex : POSITION;
		float3 normal : NORMAL;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	struct v2f
	{
		float4 pos : SV_POSITION;
		UNITY_VERTEX_INPUT_INSTANCE_ID 
		UNITY_VERTEX_OUTPUT_STEREO
	};

	v2f vert (appdata v)
	{
		v2f o = (v2f)0;
		UNITY_SETUP_INSTANCE_ID(v);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
		TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
		return o;
	}

	float4 frag (v2f i) : SV_Target
	{
		UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
		return 0;
	}
	ENDCG
}
```

## Instancing

To enable instancing, you must have in your shader:
 * `#pragma multi_compile_instancing` in all all passes.
 * Optionally
```hlsl
UNITY_INSTANCING_BUFFER_START(Props)
	// put more per-instance properties here
UNITY_INSTANCING_BUFFER_END(Props)
```
 * An example thing you could put there, in the middle is:
```hlsl
UNITY_DEFINE_INSTANCED_PROP( float4, _InstanceID)
```
 * I've found it to be super janky to try to access the variable in the fragment/surf shader, but it does seem to work in the vertex shader.
 * In your vertex shader:
```hlsl
UNITY_SETUP_INSTANCE_ID(v);
```
 * Access variables with `UNITY_ACCESS_INSTANCED_PROP(Props, _InstanceID).x;`
 * Access which instance it is in the list with `unity_InstanceID` - note this will change from frame to frame.
 * To change the value see following example:
```cs

using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class MaterialPropertyInstanceIDIncrementer : UdonSharpBehaviour
{
	void Start()
	{
		MaterialPropertyBlock block;
		MeshRenderer mr;
		int id = GameObject.Find( "BrokeredUpdateManager" ).GetComponent<BrokeredUpdateManager>().GetIncrementingID();
		block = new MaterialPropertyBlock();
		mr = GetComponent<MeshRenderer>();
		//mr.GetPropertyBlock(block);  //Not sure if this is needed
		block.SetVector( "_InstanceID", new Vector4( id, 0, 0, 0 ) );
		mr.SetPropertyBlock(block);
	}
}
```
## Surface Shaders hate advanced features

Are you trying to use Texture.Load with a surface shader? Does it say something like `Unexpected identifier "Texture2D". Expected one of: typedef const void inline uniform nointerpolation extern shared static volatile row_major column_major struct or a user-defined type`

Just wrap your stuff in a
```hlsl
#ifndef SHADER_TARGET_SURFACE_ANALYSIS
	// Do something awesome.
#endif
```

## Surface Shader Pragmas

This contains a comprehensive list of pragmas you can use with surface shaders: https://docs.unity3d.com/Manual/SL-SurfaceShaders.html I.e. `nometa` `fullforwardshadows` `alpha`.


## Default Texture Parameters

Default values available for texture properties:
```
red
gray
grey
linearGray
linearGrey
grayscaleRamp
greyscaleRamp
bump
blackCube
lightmap
unity_Lightmap
unity_LightmapInd
unity_ShadowMask
unity_DynamicLightmap
unity_DynamicDirectionality
unity_DynamicNormal
unity_DitherMask
_DitherMaskLOD
_DitherMaskLOD2D
unity_RandomRotation16
unity_NHxRoughness
unity_SpecCube0
unity_SpecCube1
```

And of course, "white" and "black"

IE `_MainTex ("Texture", 2D) = "unity_DynamicLightmap" {}`

Thanks, @Pema

## Raycasting with Orthographic and Normal Cameras

If you want your raycaster/raytracer to work with a shadow map or other orthographic camera, you will need to consider that the ray origin is not `_WorldSpaceCameraPos`.  This neat code compiled by BenDotCom ( @bbj ) shows how you can do this computation in a vertex shader, however, the code works with trivial substitution in a geometry or fragment shader as well.

```hlsl
o.vertex = UnityObjectToClipPos(v.vertex);
o.objectOrigin = mul(unity_ObjectToWorld, float4(0.0,0.0,0.0,1.0) );

// I saw these ortho shadow substitutions in a few places, but bgolus explains them
// https://bgolus.medium.com/rendering-a-sphere-on-a-quad-13c92025570c
float howOrtho = UNITY_MATRIX_P._m33; // instead of unity_OrthoParams.w
float3 worldSpaceCameraPos = UNITY_MATRIX_I_V._m03_m13_m23; // instead of _WorldSpaceCameraPos
float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
float3 cameraToVertex = worldPos - worldSpaceCameraPos;
float3 orthoFwd = -UNITY_MATRIX_I_V._m02_m12_m22; // often seen: -UNITY_MATRIX_V[2].xyz;
float3 orthoRayDir = orthoFwd * dot(cameraToVertex, orthoFwd);
// start from the camera plane (can also just start from o.vertex if your scene is contained within the geometry)
float3 orthoCameraPos = worldPos - orthoRayDir;
o.rayOrigin = lerp(worldSpaceCameraPos, orthoCameraPos, howOrtho );
o.rayDir = normalize( lerp( cameraToVertex, orthoRayDir, howOrtho ) );
```
## How to compute camera forward in object space

Thanks, @orels1

```hlsl
float3 viewDir = -UNITY_MATRIX_IT_MV[2].xyz; // Camera Forward. 
```

## This SLERP function, found by ACiiL,
```hlsl
////============================================================
//// blend between two directions by %
//// https://www.shadertoy.com/view/4sV3zt
//// https://keithmaggio.wordpress.com/2011/02/15/math-magician-lerp-slerp-and-nlerp/
float3 slerp(float3 start, float3 end, float percent)
{
	float d = dot(start, end);
	d = clamp(d, -1.0, 1.0);
	float theta = acos(d)*percent;
	float3 RelativeVec = normalize(end - start*d);
	return ((start*cos(theta)) + (RelativeVec*sin(theta)));
}
```

## Disable Batching

From error.mdl - This fixes issues where shaders need to get access to their local coordinates at the cost of a small amount of performance.

```hlsl
Tags { "DisableBatching" = "True" }
```

## Screen Space Texture with SPS-I

There's a page here https://docs.unity3d.com/2020.1/Documentation/Manual/SinglePassInstancing.html that describes the SPS-I process for using screen space textures. 

pema notes:
 * On unity 2022, you can only use multipass and SPS-I, but VRChat has a custom build of unity, so they can additionally use SPS, which they do
 * SPS = 1 double-wide frame buffer, ping pong between the side of the frame buffer each draw call
 * SPS-I = texture2Darray framebuffer, 1 slice per eye, each drawcall is an instanced drawcall which renders to both slices simultaneously
 * Multipass = texture2Darray framebuffer, 1 slicer per eye, render one eye and then the other eye 

For completeness, in spite of brevity, here is the example the aforementioned website provides:

```hlsl
struct appdata
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID //Insert
};

struct v2f //v2f output struct
{
	float2 uv : TEXCOORD0;
	float4 vertex : SV_POSITION;
	UNITY_VERTEX_OUTPUT_STEREO //Insert
};

v2f vert (appdata v)
{
	v2f o;
	UNITY_SETUP_INSTANCE_ID(v); //Insert
	UNITY_INITIALIZE_OUTPUT(v2f, o); //Insert
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); //Insert
	o.vertex = UnityObjectToClipPos(v.vertex);
	o.uv = v.uv;
	return o;
}

UNITY_DECLARE_SCREENSPACE_TEXTURE(_MainTex); //Insert

fixed4 frag (v2f i) : SV_Target
{
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i); //Insert
	fixed4 col = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.uv); //Insert
	// invert the colors
	col = 1 - col; 
	return col;
}
```

## Mechanism for converting from clip space to view/object/world space.

Use the technique here: https://gist.github.com/d4rkc0d3r/886be3b6c233349ea6f8b4a7fcdacab3

**WARNING**: The above code is not mobile-compliant. And may not work on Quest.  If you have a quest version please contact me.

Then for instance, you could do the following to get to object space:
```hlsl
po.cppos = mul( mul( clipToViewMatrix, cp ), UNITY_MATRIX_IT_MV );
```
or
```hlsl
float4 vs = ClipToViewPos( cp );
vs /= vs.w;
po.cppos = mul( vs, UNITY_MATRIX_IT_MV );
```


## Best practice for getting depth of a given pixel from the depth texture.

Because `LinearEyeDepth` doesn't work in mirrors because it uses oblique matricies, it's recommended to use `GetLinearZFromZDepth_WorksWithMirrors`

```hlsl
UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );

// Inspired by Internal_ScreenSpaceeShadow implementation.  This was adapted by lyuma.
// This code can be found on google if you search for "computeCameraSpacePosFromDepthAndInvProjMat"
// Note: The output of this will still need to be adjusted.  It is NOT in world space units.
float GetLinearZFromZDepth_WorksWithMirrors(float zDepthFromMap, float2 screenUV)
{
	#if defined(UNITY_REVERSED_Z)
		zDepthFromMap = 1 - zDepthFromMap;

		// When using a mirror, the far plane is whack.  This just checks for it and aborts.
		if( zDepthFromMap >= 1.0 ) return _ProjectionParams.z;
	#endif

	float4 clipPos = float4(screenUV.xy, zDepthFromMap, 1.0);
	clipPos.xyz = 2.0f * clipPos.xyz - 1.0f;
	float4 camPos = mul(unity_CameraInvProjection, clipPos);
	return -camPos.z / camPos.w;
}
```

You can compute `i.screenPosition` and `i.worldPos` can come from your `vertex` shader as:

```hlsl
o.vertex = UnityObjectToClipPos(v.vertex);
o.uv = v.uv;
...
o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

// Save the clip space position so we can use it later.
// This also handles situations where the Y is flipped.
float2 suv = o.vertex * float2( 0.5, 0.5*_ProjectionParams.x);

// Tricky, constants like the 0.5 and the second paramter
// need to be premultiplied by o.vertex.w.
o.screenPosition = TransformStereoScreenSpaceTex( suv+0.5*o.vertex.w, o.vertex.w );
```

In your `fragment` you will need `i.vertex` and `i.worldPos` can use it as follows:

```hlsl
float3 fullVectorFromEyeToGeometry = i.worldPos - _WorldSpaceCameraPos;
float3 worldSpaceDirection = normalize( i.worldPos - _WorldSpaceCameraPos );

// Compute projective scaling factor.
// perspectiveFactor is 1.0 for the center of the screen, and goes above 1.0 toward the edges,
// as the frustum extent is further away than if the zfar in the center of the screen
// went to the edges.
float perspectiveDivide = 1.0f / i.vertex.w;
float perspectiveFactor = length( fullVectorFromEyeToGeometry * perspectiveDivide );

// Calculate our UV within the screen (for reading depth buffer)
float2 screenUV = i.screenPosition.xy * perspectiveDivide;
float eyeDepthWorld =
	GetLinearZFromZDepth_WorksWithMirrors( 
		SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, screenUV), 
		screenUV ) * perspectiveFactor;
// eyeDepthWorld is in meters.

float3 worldPosEyeHitInDepthTexture = _WorldSpaceCameraPos + eyeDepthWorld * worldSpaceDirection;
```

NOTE: You must have a depth light on your scene, this is accomplished by having a directional light with shadows.  The light can be black.  If using hard shadows, it will be better.
NOTE: Only shaders with a shadowcaster pass will appear in the depth texture.
NOTE: screenPosition can also be used to access `_GrabTexture`!

## Surface Shader Extra Parameters

Sometimes when using surface shaders you want more than just `uv_MainTex`?  This also shows how to do vertex shaders in surface shaders.

Note: Don't forget to add `alpha` if you are using alpha!

```hlsl
#pragma surface surf Lambert vertex:vert

struct Input
{
	float3 viewDir;
	float4 color : COLOR;
	float2 uv_MainTex;
	float2 uv_Detail;
	float2 uv_BumpMap;
	float3 worldRefl;
	float3 worldPos;
	float4 screenPos;
	INTERNAL_DATA

	// Note: Additional parameters may be added here.
	float3 customColor;
};

float _Amount;

void vert (inout appdata_full v, out Input o)
{
	v.vertex.xyz += v.normal * _Amount;
	UNITY_INITIALIZE_OUTPUT(Input,o);
	o.customColor = abs(v.normal);
}

sampler2D _MainTex;

void surf (Input IN, inout SurfaceOutput o)
{
	o.Albedo = tex2D (_MainTex, IN.uv_MainTex).rgb * IN.customColor.rgb;
}
```

## Doing full-screen effects.

Thanks, @pema99 for this example shader which samples from the named `_GrabTexture` and renders it to your face with inverted colors.  This lets you perform neat visual effects on full-screen effects, for instance rumble shaders, etc. can be performed with this.

All you need to do is paste this on a quad.

NOTE: If you need to interact with objects which use the default grabpass, you will need to use a different name for your `_GrabTexture` for instance `_GrabTextureOverlay`

```hlsl
Shader "Unlit/meme"
{
	SubShader
	{
		Tags { "Queue" = "Overlay" }
		GrabPass { "_GrabTexture" }
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct v2f
			{
				float4 grabPos : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _GrabTexture;

			v2f vert (float2 uv : TEXCOORD0)
			{
				v2f o;
				o.vertex = float4(float2(1,-1)*(uv*2-1),0,1);
				o.grabPos = ComputeGrabScreenPos(o.vertex);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				return 1.0-tex2D(_GrabTexture, i.grabPos.xy / i.grabPos.w);
			}
			ENDCG
		}
	}
}
```

## Tessellation Shader Examples

ERROR.mdl provides this tessellation shader:

```hlsl

Shader "Error.mdl/Single Pass Stereo Instancing Example"
{
Properties
{
	_TesselationUniform("Tesselation Factor", Float) = 1
	_Color("Color", color) = (0,0.7,0.9,1)
}

SubShader
{
	Tags
	{
		"RenderType" = "Opaque"
		"Queue" = "Transparent+50"
	}
	LOD 100
	Blend SrcAlpha OneMinusSrcAlpha

	Pass
	{
		CGPROGRAM
		#pragma target 5.0

		#pragma vertex VertexProgram
		#pragma hull HullProgram
		#pragma domain DomainProgram
		#pragma geometry GeometryProgram
		#pragma fragment frag

		#include "UnityCG.cginc"

		struct appdata_t
		{
			float4 vertex : POSITION;
			float2 texcoord : TEXCOORD0;
			float3 normal : NORMAL;
			UNITY_VERTEX_INPUT_INSTANCE_ID
		};

		struct appdata_tess
		{
			float4 vertex : POSITION;
			float2 texcoord : TEXCOORD0;
			float3 normal : NORMAL;
			UNITY_VERTEX_INPUT_INSTANCE_ID
			UNITY_VERTEX_OUTPUT_STEREO
		};

		struct v2f
		{
			float4 vertex : SV_POSITION;
			float2 texcoord : TEXCOORD0;
			float3 normal : NORMAL;
			float3 wPos : TEXCOORD1;
			UNITY_FOG_COORDS(2)
			UNITY_VERTEX_OUTPUT_STEREO
		};

		struct TesFact
		{
			float edge[3] : SV_TessFactor;
			float inside : SV_InsideTessFactor;
		};

		float4 _Color;
		float _TesselationUniform;

		appdata_tess VertexProgram (appdata_t v)
		{
			appdata_tess t;
			UNITY_SETUP_INSTANCE_ID(v);
			UNITY_INITIALIZE_OUTPUT(appdata_tess, t);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(t);

			t.vertex = v.vertex;
			t.texcoord = v.texcoord;
			t.normal = v.normal;

			return t;
		}

		TesFact PatchConstFunc(InputPatch<appdata_tess, 3> patch)
		{
			UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[0]);
			UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[1]);
			UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[2]);
			TesFact f;
			float tessFactor = _TesselationUniform;
			f.edge[0] = tessFactor;
			f.edge[1] = tessFactor;
			f.edge[2] = tessFactor;
			f.inside = tessFactor;
			return f;
		}

		//Not the actual vertex program, is function called by the domain program to do all the stuff the vertex normally does 
		v2f DomainVert(appdata_tess v)
		{
			v2f o;
			UNITY_INITIALIZE_OUTPUT(v2f, o);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
			o.texcoord = v.texcoord;
			//float4 offset = tex2Dlod(_DepthTex, float4(o.texcoord.x,o.texcoord.y,0,0));
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.normal = UnityObjectToWorldNormal(v.normal);
			o.wPos = mul(unity_ObjectToWorld, v.vertex);
			UNITY_TRANSFER_FOG(o, o.vertex);
			return o;
		}

		[UNITY_domain("tri")]
		[UNITY_outputcontrolpoints(3)]
		[UNITY_outputtopology("triangle_cw")]
		[UNITY_partitioning("fractional_odd")]
		[UNITY_patchconstantfunc("PatchConstFunc")]
		appdata_tess HullProgram(InputPatch<appdata_tess, 3> patch,
			uint id : SV_OutputControlPointID)
		{
			UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[id]);
			return patch[id];
		}

		[UNITY_domain("tri")]
		v2f DomainProgram(
			TesFact factors,
			OutputPatch<appdata_tess, 3> patch,
			float3 barycentrCoords : SV_DomainLocation,
			uint pid : SV_PrimitiveID)
		{
			UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[0]);
			UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[1]);
			UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[2]);

			appdata_tess data;

#define DOMAIN_INTERPOLATE(fieldName) data.fieldName = \
	patch[0].fieldName * barycentrCoords.x + \
	patch[1].fieldName * barycentrCoords.y + \
	patch[2].fieldName * barycentrCoords.z;

			DOMAIN_INTERPOLATE(vertex);
			DOMAIN_INTERPOLATE(texcoord);
			DOMAIN_INTERPOLATE(normal);

			UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(patch[0], data)
			
			return DomainVert(data);
		}

		[maxvertexcount(3)]
		void GeometryProgram(triangle v2f p[3], inout LineStream<v2f> triStream)
		{

			UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(p[0]);
			UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(p[1]);
			UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(p[2]);

			triStream.Append(p[0]);
			triStream.Append(p[1]);
			triStream.Append(p[2]);
		}

		float4 frag(v2f i) : SV_Target
		{
			float facing = sign(dot(i.normal, _WorldSpaceCameraPos - i.wPos));
			return facing > 0 ? _Color : float4(0,0,0,0.2);
		}
		ENDCG
	}
}
}
```

## Triangles-From-Points Examples

Many times it's useful to just have a soup of points, that can be generated by a c# script, then you can take that point soup and bring it into 3D with a geometry shader.

As a note - you can also do this with a tessellation shader (See below) but, it is much slower.

For the following example, which emits 4.1M Tris, use this C# app 

```cs
#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

public class WorldgenGeoGen : MonoBehaviour
{
	[MenuItem("Tools/Create WorldgenGeoGen")]
	static void CreateMesh_()
	{
		int vertices = 4096; // Generate 4096 primitives
		Mesh mesh = new Mesh();
		mesh.vertices = new Vector3[1];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(10000, 10000, 10000));
		mesh.SetIndices(new int[vertices], MeshTopology.Points, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/vrc-rv32ima/WorldgenGeo/WorldgenGeo.asset");
	}
}
#endif
```
To output to an asset, then drop that asset on a renderable with this geometry shader:
```hlsl
Shader "ReferencePointToGeometryShader"
{
	Properties
	{
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Transparent"
			"Queue" = "Transparent"
		}
		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma target 5.0

			#pragma multi_compile_fog

			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geo

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID //SPS-I
			};

			struct v2g
			{
				UNITY_VERTEX_OUTPUT_STEREO //SPS-I
			};

			struct g2f
			{
				float4 vertex : SV_POSITION;
				UNITY_VERTEX_OUTPUT_STEREO //SPS-I
				float4 uvab : UVAB;
			};

			v2g vert(appdata v, uint vid : SV_VertexID /* Always 0 for points */ )
			{
				// For some reason vid and iid can't be trusted here.
				// We just have to trust SV_PrimitiveID in the next step.
				v2g o;
				UNITY_SETUP_INSTANCE_ID(v); //SPS-I
				UNITY_INITIALIZE_OUTPUT(v2g, o); //SPS-I
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); //SPS-I
				return o;
			}

			[maxvertexcount(96)]
			[instance(32)]
			void geo(point v2g input[1], inout TriangleStream<g2f> triStream,
				uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID /* Always 0 for points? */ )
			{
				float3 objectCenter = float3( geoPrimID/64, geoPrimID%64, instanceID );

				g2f p[3];

				int vtx;
				for( vtx = 0; vtx < 32; vtx++ )
				{
					p[0].vertex = mul( UNITY_MATRIX_VP, float4( objectCenter.xyz + float3( 0.0, 0.0, 0.0 ), 1.0 ) );
					p[1].vertex = mul( UNITY_MATRIX_VP, float4( objectCenter.xyz + float3( 0.0, 0.5, 0.0 ), 1.0 ) );
					p[2].vertex = mul( UNITY_MATRIX_VP, float4( objectCenter.xyz + float3( 0.5, 0.0, 0.0 ), 1.0 ) );

					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(p[0]); //SPS-I
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(p[1]); //SPS-I
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(p[2]); //SPS-I

					p[0].uvab = float4( 0.0, 0.0, 0.0, 1.0 );
					p[1].uvab = float4( 1.0, 0.0, 0.0, 1.0 );
					p[2].uvab = float4( 0.0, 1.0, 0.0, 1.0 );
					triStream.Append(p[0]);
					triStream.Append(p[1]);
					triStream.Append(p[2]);
					triStream.RestartStrip();
					objectCenter.z += 32;
				}
			}

			fixed4 frag (g2f i) : SV_Target
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i); //SPS-I

				fixed4 col = i.uvab;
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
```

### Tessellation shader to go from single-line-strip to tris:

**PLEASE NOTE THIS IS SLOW** This is much slower than having more source geometry to do the same thing!

Use this C# app:
```cs
#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

public class WorldgenGeoGen : MonoBehaviour
{
	[MenuItem("Tools/Create WorldgenGeoGen")]
	static void CreateMesh_()
	{
		int vertices = 2; // Single line strip.
		Mesh mesh = new Mesh();
		mesh.vertices = new Vector3[1];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(10000, 10000, 10000));
		mesh.SetIndices(new int[vertices], MeshTopology.Lines, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/vrc-rv32ima/WorldgenGeo/WorldgenGeo.asset");
	}
}
#endif
```

With this shader - note that we aren't taking full advantage of the geometry layer to emit extra geo, it's already slow enough.
```hlsl
// 1683us to display 131072 tris.
Shader "WorldgenGeo/WorldgenGeo_TESS_DO_NOT_USE"
{
	Properties
	{
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Transparet"
			"Queue" = "Transparent"
		}
		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma target 5.0

			#pragma multi_compile_fog

			#pragma vertex vert
			#pragma fragment frag
			#pragma domain DomainProgram
			#pragma hull HullProgram
			#pragma geometry geo

			#include "UnityCG.cginc"

			// INPUT: two-index line.
			struct appdata
			{
				float4 vertex : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID //SPS-I
				// Note: For 2-index line segments, SV_VertexID doesn't seem to update.
			};

			struct v2t
			{
				float4 vertex : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			#define TESS_FACTORX 64
			#define TESS_FACTORY 64

			struct TesFact
			{
				float edge[2] : SV_TessFactor;
			};

			struct t2g
			{
				UNITY_VERTEX_OUTPUT_STEREO //SPS-I
				uint pidX : PIDX;
				uint pidY : PIDY;
			};

			struct g2f
			{
				float4 vertex : SV_POSITION;
				UNITY_VERTEX_OUTPUT_STEREO //SPS-I
			};

			v2t vert(appdata v)
			{
				// For some reason vid and iid can't be trusted here.
				// We just have to trust SV_PrimitiveID in the next step.
				v2t o;
				UNITY_SETUP_INSTANCE_ID(v); //SPS-I
				UNITY_INITIALIZE_OUTPUT(v2t, o); //SPS-I
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); //SPS-I
				//o.id = vid;
				//o.iid = iid;
				return o;
			}

			TesFact PatchConstFunc(InputPatch<v2t, 1> patch)
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[0]);
				TesFact f;
				f.edge[0] = TESS_FACTORY;
				f.edge[1] = TESS_FACTORX-1;
				return f;
			}

			[UNITY_domain("isoline")]
			[UNITY_outputcontrolpoints(2)]
			[UNITY_outputtopology("point")]
			[UNITY_partitioning("integer")]
			[UNITY_patchconstantfunc("PatchConstFunc")]
			v2t HullProgram(InputPatch<v2t, 1> patch,
				uint id : SV_OutputControlPointID)
			{
				v2t o = patch[0];
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(o);
				return o;
			}

			[UNITY_domain("isoline")]
			t2g DomainProgram(
				TesFact factors,
				OutputPatch<v2t, 2> patch,
				float2 barycentrCoords : SV_DomainLocation,
				uint pid : SV_PrimitiveID)
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[0]);
				UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(patch[0], data)
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[1]);
				UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(patch[1], data)

				t2g o;
				UNITY_INITIALIZE_OUTPUT(t2g, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.pidX = round( barycentrCoords.x * (TESS_FACTORX-1) );
				o.pidY = round( barycentrCoords.y * TESS_FACTORY);
				return o;
			}

			[maxvertexcount(128)]
			[instance(32)]
			void geo(point t2g input[1], inout TriangleStream<g2f> triStream,
				uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
			{
				uint vid = input[0].pidX;
				uint vid2 = input[0].pidY;
				float3 objectCenter = float3( vid, vid2, instanceID );

				g2f p[3];

				p[0].vertex = mul( UNITY_MATRIX_VP, float4( objectCenter.xyz + float3( 0.0, 0.0, 0.0 ), 1.0 ) );
				p[1].vertex = mul( UNITY_MATRIX_VP, float4( objectCenter.xyz + float3( 0.0, 0.5, 0.0 ), 1.0 ) );
				p[2].vertex = mul( UNITY_MATRIX_VP, float4( objectCenter.xyz + float3( 0.5, 0.0, 0.0 ), 1.0 ) );

				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(p[0]); //SPS-I
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(p[1]); //SPS-I
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(p[2]); //SPS-I

				triStream.Append(p[0]);
				triStream.Append(p[1]);
				triStream.Append(p[2]);
			}

			fixed4 frag (g2f i) : SV_Target
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i); //SPS-I

				fixed4 col = 10.0;
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
```


## Using depth cameras on avatars.

If an avatar has a grab pass, and you're using a depth camera, you may fill people's logs with this:

```
Warning    -  RenderTexture.Create: Depth|ShadowMap RenderTexture requested without a depth buffer. Changing to a 16 bit depth buffer.
```

A way around this is to create a junk R8 texture with no depth buffer `rtDepthThrowawayColor`, and your normal depth buffer, `rtBotDepth` and frankenbuffer it into a camera.  NOTE: This will break camrea depth, so be sure to call `SetTargetBuffers()` in the order you want the camreas to evaluate.

```cs
CamDepthBottom.SetTargetBuffers( rtDepthThrowawayColor.colorBuffer, rtBotDepth.depthBuffer );
```


## Grabpasses

You can add a grabpass tag outside of any pass (this happens in the SubShader tag).  You should only use `_GrabTexture` on the transparent queue as to not mess with other shaders that use the `_GrabTexture`

```hlsl
Tags
{
	"RenderType" = "Transparent"
	"Queue" = "Transparent"
}

GrabPass
{
	"_GrabTexture"
}
```

You should use the `_GrabTexture` name so that it only has to get executed once instead of once for every material.

You can then index into it as a sampler2D.


```hlsl
sampler2D _GrabTexture;
```
...
```hlsl
float2 grabuv = i.uv;
#if !UNITY_UV_STARTS_AT_TOP
	grabuv.y = 1 - grabuv.y;
#endif
fixed4 col = tex2D(_GrabTexture, grabuv);
```

NOTE: In the below we use Texture2D - but this will go away soon.  You should use `UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );` in all situations moving forward

Or, alternatively, if you would like pixel-perfect operations:
```hlsl
SamplerState sampler_CameraDepthTexture;
#ifndef SHADER_TARGET_SURFACE_ANALYSIS
	Texture2D _CameraDepthTexture;
#else
	UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );
#endif
uniform float4 _CameraDepthTexture_TexelSize;
```
...
```hlsl
#ifndef SHADER_TARGET_SURFACE_ANALYSIS
	ScreenDepth = LinearEyeDepth(_CameraDepthTexture.Sample(sampler_CameraDepthTexture, screenPosNorm.xy));
#else
	ScreenDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, screenPosNorm.xy ));
#endif
```
And to check it:
```hlsl
#ifndef SHADER_TARGET_SURFACE_ANALYSIS
	_CameraDepthTexture.GetDimensions(width, width);
#endif
```

Or, if you want to grab into it from its place on the screen, like to do a screen-space effect, you can do this:

in Vertex shader:
```hlsl
o.grabposs = ComputeGrabScreenPos( o.vertex );
```
in Fragment shader:
```hlsl
col = tex2Dproj(_GrabTexture, i.grabposs );
```

Or use the method above to get grab coordinates.

## Reference Camera

Don't forget to drag your Main Camera into "Reference Camera" property on your VRCWorld.  Not having a reference camera will sometimes set zNear to be too far or other problems.  So having a reference camera is highly advised.

## Making Unity UI much faster

Go under Edit->Project Settings...->Editor->Sprite Packer->Mode->Always Enabled

## VRC Layers

http://vrchat.wikidot.com/worlds:layers

Want to do a camera compute loop?  Shove everything on the "Compute" layer and put it somewhere a long way away.

## Need to iterate on Udon Sharp faster?

Edit -> Preferences -> General -> Auto Refresh, uncheck.

Whenever you do need Unity to reload, ctrl+r

## Iterating through every instance of a behavior or udonsharpbehavior attached to all objects in a scene.

For instance getting all instances of the BrokeredBlockIDer behavior.
```cs
foreach( UnityEngine.GameObject go in GameObject.FindObjectsOfType(typeof(GameObject)) as UnityEngine.GameObject[] )
{
	foreach( BrokeredBlockIDer b in go.GetUdonSharpComponentsInChildren<BrokeredBlockIDer>() )
	{
		b.UpdateProxy();
		b.defaultBlockID = (int)Random.Range( 0, 182.99f );
		ct++;
		b._SetBlockID( b.defaultBlockID );
		b._UpdateID();
		b.ApplyProxyModifications();
	}
}
```

`GetUdonSharpComponentsInChildren` is the magic thing.  **PLEASE NOTE** You must use `UpdateProxy()` before reading from and `ApplyProxyModifications()` when done.

## Using CRTs with integer indexing:

```hlsl
// This changes _SelfTexture2D in 'UnityCustomRenderTexture.cginc' to Texture2D instead of sampler2D
// Thanks Lyuma!
#define _SelfTexture2D _JunkTexture
#include "UnityCustomRenderTexture.cginc"
#undef _SelfTexture2D
Texture2D<float4> _SelfTexture2D;

#include "UnityCG.cginc"
#include "AudioLink.cginc"
uniform half4 _SelfTexture2D_TexelSize;
```

## MRT

This demo is not in this project, but, I wanted to include notes on how to do multiple rendertextures.

1) Set up cameras pointed at whatever you want to compute.
2) Put the things on a layer which is not heavily used by anything else.
3) Make sure to cull that layer on all lights.
4) Use `SetReplacementShader` - this will prevent a mountain of `OnRenderObject()` callbacks.
5) Cull in camrea based on that layer.
6) Put camera on default layer.
7) Don't care about depth because when using MRTs, you want to avoid letting unity figure out the render order, unless you really don't care.
8) I find putting camera calcs on `UiMenu` to work best.

OPTION 1: Cameras ignore their depth and render order when you do this.  Instead they will execute in the order you call SetTargetBuffers on them.

NOTE: OPTION 2: TEST IT WITHOUT EXPLICIT ORDERING (manually executing .Render) FIRST AS THIS WILL SLOW THINGS DOWN  You will need to explicitly execute the order you want for all the cameras.  You can only do this in `Update` or `LateUpdate`, i.e.

```cs
CamCalcA.enabled = false;
CamCalcA.SetReplacementShader( <shader>, "" );
RenderBuffer[] renderBuffersA = new RenderBuffer[] { rtPositionA.colorBuffer, rtVelocityA.colorBuffer };
CamCalcA.SetTargetBuffers(renderBuffersA, rtPositionA.depthBuffer);
..
CamCalcA.Render()
CamCalcB.Render()
```


## Making camera computation loops performant

 * Put the camera, the culling mask and the object you're looking at on a unique layer from your scene in general.  Find all lights, and cull off that layer.  If a camera is on a layer that is lit by a light, things get slow.
 * Make sure your bounding box for your geometry you are computing on doesn't leak into other cameras.
 * Use the following script on your camera: `<camera>.SetReplacementShader( <shader>, "");` where `<camera>` is your camera and `<shader>` is the shader you are using on the object you care about.  As a warning, using a tag here will slow things back down.  This prevents a ton of callbacks like `OnRenderObject()` in complicated scenes.
 * Doing these things should make your camera passes take sub-200us in most situations.


# Working with git world repos

## My recommended packages and order:

1. Clone your repository and open it in Unity (note: use the empty default scene for these steps)
2. Open the project in Unity (whatever version VRchat says) If it asks you to upgrade to version 2 of the library, say YES.
3. Import VRC SDK Worlds: https://vrchat.com/home/download
4. Import Udon Sharp: https://github.com/MerlinVR/UdonSharp/releases
5. Import CyanEmu: https://github.com/CyanLaser/CyanEmu/releases
6. Import VRWorld Toolkit: https://github.com/oneVR/VRWorldToolkit/releases
7. Import AudioLink: https://github.com/llealloo/vrc-udon-audio-link/releases
8. At this point, you can open the scene.  Many people close and reopen unity at this point.
9. Under VR World Toolkit, run World Debugger and fix layers.
10. You should be bable to build out scenes.

Sometimes Esnya tools is useful, especially for finding broken refernces to Udon Scripts, etc. https://github.com/esnya/EsnyaUnityTools/releases 

MAJOR NOTE: EXPERIMENTAL: If you have prefabs missing script references, you will need to reimport your prefabs.  Simply select the prefab that is trobuled, click "Select Prefab Asset" then click "Reimport."  Alternatively, select the package your prefab is part of and say "reimport"

Side note:  If you want something like CyanEmu (to simulate vrchat in Unity) https://github.com/lyuma/Av3Emulator

## When opening worlds from git using the .gitignore file from here

1. Open project in Unity Hub for correct version of Unity.
3. Import VRC SDK
2. **Configure your player settings under editor preprocessor to include UDON**
4. Import UdonSharp
5. Import AudioLink
6. Import Esnya Tools
7. Import VRC World Toolkit
8. Run Window->UdonSharp->Refresh All UdonSharp Assets
9. Repeat 6 til no new assets.
10. Close and reopen Unity
11. Open Scene
12. EsnyaTools -> Repair Udon
13. VRWorldToolkit -> World Debugger
14. Fix all errors.

## Additional Links

These are links other people have given me, these links are surrounding U#.

 * https://github.com/jetdog8808/Jetdogs-Prefabs-Udon
 * https://github.com/Xytabich/UNet
 * https://github.com/FurryMLan/VRChatUdonSharp
 * https://github.com/Guribo/BetterAudio
 * https://github.com/squiddingme/UdonTether
 * https://github.com/cherryleafroad/VRChat_Keypad
 * https://github.com/aiya000/VRChat-Flya
 * https://github.com/MerlinVR/USharpVideo
 * https://github.com/Reimajo/EstrelElevatorEmulator/tree/master/ConvertedForUdon

Neat way to procedurally generate a ton of texture in a non-repeating way from a small source:
 * https://github.com/Error-mdl/UnityGaussianTex

Way more than you ever wanted to know about postprocessing:
 * https://gitlab.com/s-ilent/SCSS/-/wikis/Other/Post-Processing

Lit vertex shader
 * https://github.com/Xiexe/Unity-Lit-Shader-Templates

Interesting looking mesh tool (Still need to use)
 * https://github.com/lyuma/LyumaShader/blob/master/LyumaShader/Editor/LyumaMeshTools.cs
 
Basic global profiling scripts for Udon:
 * https://gist.github.com/MerlinVR/2da80b29361588ddb556fd8d3f3f47b5

This explaination of how the fallback system works (Linked by GenesisAria)
 * https://pastebin.com/92gwQqCM

Making procedural things like grids that behave correctly for going off in the distance.
 * https://www.iquilezles.org/www/articles/filterableprocedurals/filterableprocedurals.htm
 * https://www.iquilezles.org/www/articles/bandlimiting/bandlimiting.htm

Using LERP to do good noise / motion IIR filtering:
 * https://twitter.com/evil_arev/status/1128062338156900353
 * Slow/Lumpy: `a = lerp( a, b, 0.1f)`
 * Fast/Noisy: `a = lerp( a, b, 0.9f)`
 * Adaptive: `a = lerp( a, b, k*(abs(a-b)))`

Time-invariant IIR Lerp for smooth motion in a framerate-dependent way.
 * `constant = `how quickly you approach the value
 * `coeff = exp( -unity_DeltaTime * constant );`
 * coeff is very close to one for small timesteps, farther for bigger timesteps, so...
 * `a = lerp( b, a, coeff )`

### Not-shaders

From @lox9973 This flowchart of how mono behaviors are executed and in what order: https://docs.unity3d.com/uploads/Main/monobehaviour_flowchart.svg


## Notes on grabpass avatar->map data exfiltration

@d4rkpl4y3r notes that you can use queue < 2000 and zwrite off to exfiltrate data without horrible visual artifacts.  You can also use points to do the export instead of being limited to quads by exporting points from a geometry shader on the avatar with the following function:

```hlsl
float4 pixelToClipPos(float2 pixelPos)
{
	float4 pos = float4((pixelPos + .5) / _ScreenParams.xy, 0.5, 1);
	pos.xy = pos.xy * 2 - 1;
	pos.y = -pos.y;
	return pos;
}
```

(TODO: Expand upon this with actual demo)


## HALP The Unity compiler is emitting really bizarre assembly code.

Eh, just try using a different shader model, add a 
```hlsl
#pragma target 5.0
```
in your code or something.  Heck 5.0's been supported since the GeForce 400 in 2010.

## Udon events.

Re: `FixedUpdate`, `Update`, `LateUpdate`

From Merlin: https://docs.unity3d.com/ScriptReference/MonoBehaviour.html most of the events under Messages, with some exceptions like awake and things that don't make sense like the Unity networking related ones
you can look at what events UdonBehaviour.cs registers to see if they are actually there on Udon's side

## UdonSharp Get All Node Names

Edit->Project Settings->Player Settings->Configuration->Scripting Define Values

Add `UDONSHARP_DEBUG`

Then, reload.

Then, Window->Udon Sharp->Node Definition Grabber

Press the button. Your clipboard now contains a present.

Once you've done this, go back and remove `UDONSHARP_DEBUG`

## Getting big buffers

From @lox9973

BIG WARNING: After a lot of testing, we've found that this is slower than reading from a texture if doing intensive reads.  If you need to read from like 100 of these in a shader, probably best to move it into a texture first.

```hlsl
cbuffer SampleBuffer
{
	float _Samples[1023*4] : packoffset(c0);
	float _Samples0[1023] : packoffset(c0);
	float _Samples1[1023] : packoffset(c1023);
	float _Samples2[1023] : packoffset(c2046);
	float _Samples3[1023] : packoffset(c3069);
};

float frag(float2 texcoord : TEXCOORD0) : SV_Target
{
	uint k = floor(texcoord.x * _CustomRenderTextureInfo.x);
	float sum = 0;
	for(uint i=k; i<4092; i++)
		sum += _Samples[i] * _Samples[i-k];
	if(texcoord.x < 0)
		sum = _Samples0[0] + _Samples1[0] + _Samples2[0] + _Samples3[0]; // slick
	return sum;
}
```
and
```cs
void Update()
{
	source.GetOutputData(samples, 0);
	System.Array.Copy(samples, 4096-1023*4, samples0, 0, 1023);
	System.Array.Copy(samples, 4096-1023*3, samples1, 0, 1023);
	System.Array.Copy(samples, 4096-1023*2, samples2, 0, 1023);
	System.Array.Copy(samples, 4096-1023*1, samples3, 0, 1023);
	target.SetFloatArray("_Samples0", samples0);
	target.SetFloatArray("_Samples1", samples1);
	target.SetFloatArray("_Samples2", samples2);
	target.SetFloatArray("_Samples3", samples3);
}
```
https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-constants

CBuffers:
```hlsl
Properties
{
...

	_Spread00 ("Spine", Vector) = (40, 40, 40, 1)
	_Spread01 ("Head", Vector) = (40, 40, 80, 1)
	...
	_Spread50 ("IndexProximal", Vector) = (45, 20,  9, 1)
	_Spread51 ("IndexDistal", Vector) = (45,  9,  9, 1)

	_Finger00 ("LeftThumb", Vector) = (0, 0, 0, 0)
	_Finger01 ("RightThumb", Vector) = (0, 0, 0, 0)
	...
	_Finger40 ("LeftLittle", Vector) = (0, 0, 0, 0)
	_Finger41 ("RightLittle", Vector) = (0, 0, 0, 0)
}

CGPROGRAM
...
cbuffer SpreadBuffer
{
	float4 _Spread[6][2] : packoffset(c0);
	float4 _Spread00 : packoffset(c0);
	float4 _Spread01 : packoffset(c1);
	...
	float4 _Spread50 : packoffset(c10);
	float4 _Spread51 : packoffset(c11);
};

cbuffer FingerBuffer
{
	float4 _Finger[10] : packoffset(c0);
	float4 _Finger00 : packoffset(c0);
	...
	float4 _Finger40 : packoffset(c8);
	float4 _Finger41 : packoffset(c9);
}
ENDCG
```

## Keywords.

Keywords can be used to create variants of a shader to avoid runtime branches.  Never ever use `[Toggle(...)]` unless you are operating with a local keyword or a reserved keyword.  Even using local leywords are discouraged, in most situations, it is encouraged instead to use `[ToggleUI]` and branch based on the value.

**WARNING**
 > #pragma multi_compile and #pragma shader_feature lines in .cginc / .hlsl files are entirely ignored. They must be in the .shader file.
 > https://forum.unity.com/threads/how-to-put-all-the-pragma-multi_compile-in-an-include-file.1097356/

To use a non-local keyword, use from the following list: https://pastebin.com/83fQvZ3n

To use a local keyword, here is an example

In your properties block: 
```hlsl
[Toggle(_is_torso_local)] _is_torso_local ( "Torso (check)/Wall (uncheck)", int ) = 0
```

In your shader block, add:
```hlsl
#pragma multi_compile_local _ _is_torso_local
```
or, if you only want to build used features,
```hlsl
#pragma shader_feature_local _is_torso_local
```

And in your shader
```hlsl
#if _is_torso_local
	// Do something
#endif
```

If you have a sort of radio button option, you can use it like the following:

In your properties block:
```hlsl
[KeywordEnum(None, Simple, High Quality)] _SunDisk ("Sun", Int) = 2
```

In your shader block:
```hlsl
#pragma multi_compile_local _SUNDISK_NONE _SUNDISK_SIMPLE _SUNDISK_HIGH_QUALITY
```

In your code:
```hlsl
#if defined(_SUNDISK_SIMPLE)
	// Do stuff
```

## Variants you can ditch (thanks, Three)

If you're on an avatar you can likely ditch all these.

```hlsl
#pragma skip_variants DYNAMICLIGHTMAP_ON LIGHTMAP_ON LIGHTMAP_SHADOW_MIXING DIRLIGHTMAP_COMBINED
```

Also, it is likely `SHADOWS_SHADOWMASK` can be ignored, too.

## Unity keeps editing my shader files!

If Unity keeps editing your files on disk (changing semantics) and you want it to stop, use the `UNITY_SHADER_NO_UPGRADE` macro somewhere in your shader.

## VRChat "Build & Test" Overrides

You can insert additional parameters into VRC for "Build & Test" with the following (compiled TCC build of code included.) For instance, this one adds the `--fps=0` command-line parameter.
```c
#include <stdio.h>
#include <stdlib.h>

int main( int argc, char ** argv )
{
	char cts[8192];
	char * ctsp = cts;
	int i;
	ctsp += sprintf( ctsp, "vrchat.exe --fps=0" );
	for( i = 1; i < argc; i++ )
	{
		ctsp += sprintf( ctsp, " \"%s\"", argv[i] );
	}
	printf( "Launching: %s\n", cts );
	system( cts );
}
```
Command-line to compile application:
```
c:\tcc\tcc.exe vrc-uncapped.c
```

Then, in VRC SDK Settings, set the path to the VRC Exe to be vrc-uncapped.exe

### Launch Options of Interest

| Parameter | description |
|-----------|-------------|
| --fps=0 | Run uncapped FPS |
| --enable-sdk-log-levels | be more verbose |
| --enable-debug-gui | enable debug gui |
| --enable-udon-debug-logging | provide better stack tracing for udon apps |
| -screen-width 1280 | screen width |
| -screen-height 720 | screen nheight |
| --midi=tounity | specify midi input |
| -screen-fullscreen 1 | specify window full screen |
| --watch-avatars | reload avatars when updating (local testing only!) |
| --watch-worlds | reload worlds when updating (local testing only!) |
| --enable-verbose-logging | Enable detailed logging |
| --profile=# | where # is a profile slot number to allow you to have multiple logins and you can select one. |
| --osc=inPort:senderIP:outPort | Default is: --osc=9000:127.0.0.1:9001 |
| vrchat://launch?id= | Specify launch instance |

Other interesting command-line parameters are listed here: https://github.com/Float3/VRCLauncher/blob/main/README.md

## 3D CC0 / Public Domain Resources (Compatible with MIT-licensed projects)

### For PBR materials (Normal/Bump, Displacement, Diffuse, Roughness)
 * https://ambientcg.com/list (CC0, 1.0)
 * https://www.cgbookcase.com/ (CC0, 1.0)

### For 3D Models
 * https://quaternius.com/
 * https://www.kenney.nl/assets
 * https://www.davidoreilly.com/library

## Making audio play

Thanks, @lox9973 for informing me of this: https://gitlab.com/-/snippets/2115172

# ATTIC

(Stuff below here may no longer be valid)


## CRT Perf Testing (Unity 2018)
Test number results were performed on a laptop RTX2070.

**BIG NOTE**: CNLohr has observed lots of oddities and breaking things when you use the "period" functionality in CRTs.  I strongly recommend setting "period" to 0.

NSIGHT Tests were not performed in VR.

SINGLE CRT TESTS

Swapping buffers between passes:

 * SAME CRT: 1024x1024 RGBAF Running a CRT with with 25x .2x.2 update zones, double buffering every time yields a total run time of 
   * 2.25ms in-editor. 2.5ms in-game.
   * Each pass executed over a 10us window.
   * There was 100us between executions.
 * Same as above, except for 128x128.
   * 330us in-editor. 250us in-game.
   * Each pass executed over a 6us window.
   * There was 6us between executions.
 * Same as above, except for 20x20.
   * 340us in-editor. 270us in-game.
   * Each pass executed over a 6us window.
   * There was 6us between executions.

Not swapping buffers between passes:

 * SAME CRT: 1024x1024 RGBAF Running a CRT with with 25x .2x.2 update zones, double buffering only on last pass yields a total run time of 
   * 230-280us in-editor. 185us in-game.
   * Each pass executed over a 3.5us window.
   * There is no time between executions.
   * There was a 100us lag on the very last update.
 * Same as above, except for 128x128.
   * 63us in-editor. 22us (+/- a fair bit) in-game.
   * Each pass executed over a between 400ns and 1us window.
   * There are random lags surrounding this in game, but the lags are all tiny.

With chained CRTs, **but** using the same shader.  The mateials were set up so that each passing CRT.  All tests run 25 separate CRTs, using the last one.
 * 1024x1024 RGBAF running a CRT, but only .2x.2 of the update zone. (So it's a fair test).
   * ~80us in-editor, 140us in-game.
   * ~6.5us between passes.
   * First material uses a fixed material.
   * OBSERVATION: This looks cheaty, as it's all the same rendertarget.
 * Same, except forces the chain to be circular.
   * Same in-game perf.
 * Same, except verifying that each step is not stepped upon.
   * Unity a little slower (110us), 160us in-game.

 * Forced different rendertarget sizes, pinging between 1024x1024 and 512x512.
   * ~85us in-editor.
   * 120us in-game.

 * Forcefully inserting one double-buffered frame, to allow data tobe fed back in on itself
   * 190us in-editor
   * 250us in-game.
   * The frame with the double buffer incurs a huge pipeline hit of ~110us.

### Cameras
 * Created 25 cameras, pointed at 25 quads, each on an invisible layer.
 * No depth buffer, no clear.
 * Quad was only .2x.2
 * Basically same shader as chain CRT.
 * 1024x1024 RGBA32F
 
 * In-Editor 234us per camera. 5.8ms total.
 * In-Game 300us per camera. 7.8ms total.

Trying 128x128
 * In-Editor: 35us per camera. around 600us total.
 * In-game: ~30us per camera.  But, weird timing. Has stalls. Takes ~2.1ms total.

### Conclusions:
 * You can work with large CRTs that chain with virtually no overhead.
 * Small (say 128x128) buffers can double buffer almost instantly.
 * Larger buffers, for instance 1024x1024 RGBA32F take ~110us to double-buffer.
 * No penalty is paid by chaining CRTs target different texture sizes.
 * Note that all tests were performed with the same shader for all CRTs.
 * Cameras work surprisingly well for smaller textures and really poorly for big textures.

## FYI
 * For maximum platform support, make all edges of your RenderTexture divisible by 16.  (Note: ShaderFes, and VRSS)

## Run Unity in GLES3 mode to test for GLES3 compatibility.

Thanks, lox9973
```
Unity.exe -force-gles31 -projectpath ...
```

## General notes for working from git (NOTES ONLY)

 * Use .gitignore from cnballpit-vrc
 * Import the VRC SDK
 * Import the U# SDK
 * Import VRWorldToolkit
(Reopen project)
 * Run "Refresh all UdonSharp Assets"

## General 2019 Beta Info:

1. React to this post: https://discord.com/channels/189511567539306508/449348023147823124/500437451085578262
2. Read this https://discord.com/channels/189511567539306508/503009489486872583/865421330698731541
4. Download this: https://files.vrchat.cloud/sdk/U2019-VRCSDK3-WORLD-2021.07.15.13.46_Public.unitypackage
5. Download & Install Unity Hub: https://unity3d.com/get-unity/download
7. Install Unity 2019.4.28f1.
8. Backup your project.
9. Follow this guide: https://docs.vrchat.com/v2021.3.2/docs/migrating-from-2018-lts-to-2019-lts
Basically:
1. Open the project to an empty scene.
2. Import the BETA SDK - if you ever import the not beta SDK you will likely have to start over.
3. Import Udon sharp aftert the beta SDK.
4. Import CyanEmu.

Import anything else you need.

Then open your scene.


NOTE: If you are going from a fresh git tree of a project, you should open a blank scene, import the new beta SDK and all your modules then close unity and reopen your scene.

--> TODO --> Include in PR.
```cs
[MenuItem("Window/Udon Sharp/Refresh All UdonSharp Assets")]
static public void UdonSharpCheckAbsent()
{
	Debug.Log( "Checking Absent" );

	string[] udonSharpDataAssets = AssetDatabase.FindAssets($"t:{nameof(UdonSharpProgramAsset)}");
	string[] udonSharpNames = new string[udonSharpDataAssets.Length];
	Debug.Log( $"Found {udonSharpDataAssets.Length} assets." );

	_programAssetCache = new UdonSharpProgramAsset[udonSharpDataAssets.Length];

	for (int i = 0; i < _programAssetCache.Length; ++i)
	{
		udonSharpDataAssets[i] = AssetDatabase.GUIDToAssetPath(udonSharpDataAssets[i]);
	}

	foreach(string s in AssetDatabase.GetAllAssetPaths() )
	{
		if(!udonSharpDataAssets.Contains(s))
		{
			Type t = AssetDatabase.GetMainAssetTypeAtPath(s);
			if (t != null && t.FullName == "UdonSharp.UdonSharpProgramAsset")
			{
				Debug.Log( $"Trying to recover {s}" );
				Selection.activeObject = AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(s);
			}
		}
	}

	ClearProgramAssetCache();

	GetAllUdonSharpPrograms();
}
```

## Depth Textures & Getting Worldspace Info

If you define a sampler2D the following way, you can read the per-pixel depth.
```hlsl
UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );
```

### Option 1: Use a varying, `screenPosition`

**NOTE**: this `screenPosition` can also be used to access `_GrabTexture`!

Struct:
```hlsl
float4 screenPosition : TEXCOORD1; // Trivially refactorable to a float2
float3 worldDirection : TEXCOORD2;
```

Vertex Shader:
```hlsl
// Subtract camera position from vertex position in world
// to get a ray pointing from the camera to this vertex.
o.worldDirection = mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos;

// Save the clip space position so we can use it later.
// This also handles situations where the Y is flipped.
float2 suv = o.vertex * float2( 0.5, 0.5*_ProjectionParams.x);

// Tricky, constants like the 0.5 and the second paramter
// need to be premultiplied by o.vertex.w.
o.screenPosition = float4( TransformStereoScreenSpaceTex(
	suv+0.5*o.vertex.w, o.vertex.w), 0, o.vertex.w );

```

Fragment Shader:
```hlsl
// Compute projective scaling factor...
float perspectiveDivide = 1.0f / i.vertex.w;

// Calculate our UV within the screen (for reading depth buffer)
float2 screenUV = i.screenPosition.xy * perspectiveDivide;

// Read depth, linearizing into worldspace units.
float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV)));

// Scale our view ray to unit depth.
float3 direction = i.worldDirection * perspectiveDivide;
float3 worldspace = direction * depth + _WorldSpaceCameraPos;
```

### Option 2: Re-use .vertex

This approach is slower by about 8-10 fragment ops, but requires no additional varying if all you want is the screenUV for depth or grab passes.  If you want world space, you will still need to compute that in the vertex shader and use one varying.  It would require multiple matrix-vector multiplies and the needed matricies are unavailable in the normal pipeline.

Vertex Shader:
```hlsl
// Subtract camera position from vertex position in world
// to get a ray pointing from the camera to this vertex.
o.worldDirection = mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos;
```

Fragment Shader:

```hlsl
// Compute projective scaling factor...
float perspectiveDivide = 1.0f / i.vertex.w;

// Scale our view ray to unit depth.
float3 direction = i.worldDirection * perspectiveDivide;

// Calculate our UV within the screen (for reading depth buffer)
float2 screenUV = (i.vertex.xy / _ScreenParams.xy);

// Flip y in any situation where y needs to be flipped for reading depth. (OpenGL, no-MSAA, no-HDR)
screenUV = float2( screenUV.x*.5, _ProjectionParams.x * .5 + .5 - screenUV.y * _ProjectionParams.x );

// Read depth, linearizing into worldspace units.
float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV)));

// VR stereo support
screenUV = TransformStereoScreenSpaceTex( screenUV, 1.0 );
```
## Fullscreening a quad from it's UVs

```hlsl
v2f vert(appdata v)
{
	v2f o;
	o.pos = float4(float2(1, -1) * (v.uv * 2 - 1), 0, 1);

	return o;
}
```

# Wicked awesome trick to read-modify-write from a shader

This can store up to 3 IDs per pixel, and it maintains the last 3.

This was done to handle ball hashing with dense grids, to support up to 3 ball hash collisons per cell before losing a ball.

This is from @d4rkpl4y3r.


```hlsl
BlendOp Add, Add
Blend One SrcAlpha, One One

float4 PackIndex(uint index)
{
	uint3 packed = uint3(index, (index >> 7), (index >> 14)) & 0x7F;
	return float4(packed, 256);
}

uint UnpackScalar(uint3 data)
{
	data = data & 0x7F;
	return data.x | (data.y << 7) | (data.z << 14);
}

uint3 UnpackData(uint4 data)
{
	float4 raw = asfloat(data);
	raw.xyz *= exp2(-max(0, raw.w / 256 * 8 - 3 * 8));
	uint3 packed = (uint3)raw.xyz;
	uint3 indices = uint3(
		UnpackScalar(packed),
		UnpackScalar(packed >> 8),
		UnpackScalar(packed >> 16));
	return indices;
}
```

Please note that if you use MRT, this scales to up to 24 IDs. 

This is an improvement over my up-to-two IDs per cell.

```hlsl
// .r = original.r * Zero + new.r * DstAlpha;
// .a = original.a * Zero + new.a * One;

// On the first pixel,				VALUE = ( 0, 0, 0, ID0 );
// On the first overlapping pixel,	VALUE = ( ID0, ID0, ID0, ID1 );
// On the second overlapping pixel,	VALUE = ( ID1, ID1, ID1, ID2 );

// DstAlpha = original.a

Blend DstAlpha Zero, One Zero

...
return float4( 1, 1, 1, ID );
```















# Super Cursed Stuff

### Use internal APIs to read raw shader compiled data, and create a new shader from that data.
```cs
BuildTarget bt = 
	BuildTarget.StandaloneLinux64;
	//BuildTarget.StandaloneWindows;
	//BuildTarget.Android;
BuildUsageTagSet buts = new BuildUsageTagSet();
Scene currentScene = SceneManager.GetActiveScene();

BuildSettings bs = new BuildSettings();
//bs.buildFlags = 0;
//bs.group = 0;
bs.target = bt;
//bs.typeDB
SceneDependencyInfo sdi = ContentBuildInterface.CalculatePlayerDependenciesForScene(currentScene.path, bs, buts);

FieldInfo GetBuildTargetSelectionField = typeof(BuildSettings).GetField("m_Target", 
	BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static);
		
object bts = GetBuildTargetSelectionField.GetValue( bs );

MethodInfo dynMethodGCD = typeof(ShaderUtil).GetMethod("GetCompiledData", 
	BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static);
byte[] data = (byte[])dynMethodGCD.Invoke(null, new object[] { 
	shdExport,
	buts, //new BuildUsageTagSet(),
	ContentBuildInterface.GetGlobalUsageFromActiveScene(bt), //new BuildUsageTagGlobal(),
	bts,
	true });

using (FileStream fs = File.Open("test.dat", FileMode.Create, FileAccess.Write, FileShare.None))
{
	fs.Write(data,0,data.Length);
	fs.Close();
}

Debug.Log( "Data: " + data.Length + " bytes" );
MethodInfo dynMethod = typeof(Shader).GetMethod("CreateFromCompiledData", 
	BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static);
Shader[] dependencies = new Shader[0];
matReimport.shader = (Shader)dynMethod.Invoke(null, new object[] { data, dependencies });
```
