# shadertrixx

CNLohr's repo for his Unity assets and other shader notes surrounding VRChat.  This largely contains stuff made by other people but I have kind of collected.

## The most important trick

```hlsl
#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y)))) 
```

This makes a well behaved `mod` function that rounds down even when negative.

Thanks, @d4rkpl4y3r - this originally actually comes from an epic bgolus forum post: https://forum.unity.com/threads/translating-a-glsl-shader-noise-algorithm-to-hlsl-cg.485750/

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

## Additional tricks

From @Lyuma
 * [flatten] (UNITY_FLATTEN macro) to force both cases of an if statement or
 * force a branch with [branch] (UNITY_BRANCH macro);
 * force loop to unroll with [unroll] (UNITY_UNROLL) or
 * force a loop with [loop] (UNITY_LOOP)
 * there's also [call] for if or switch statements I think, not sure exactly how it works.

From @Orels
 * Here's a pretty quick reference for HLSL: https://developer.download.nvidia.com/cg/index_stdlib.html

From @lox9973
 * This flowchart of how mono behaviors are executed and in what order: https://docs.unity3d.com/uploads/Main/monobehaviour_flowchart.svg

## tanoise

Very efficient noise based on Toocanzs noise. https://github.com/cnlohr/shadertrixx/blob/main/Assets/tanoise/README.md

## scrn_aurora

tanoise-modified aurora, originally written by nimitz, modified further by scrn.  https://github.com/cnlohr/shadertrixx/tree/main/Assets/scrn_aurora

## Defining Avatar Scale

The "magic ratio" is `view_y = head_to_wrist / 0.4537` (in t-pose) all unitless.

"It's mentioned many places that armspan is the defining scale, but that comment is more specific (armspan is 2 * head_to_wrist, and the ratio to height)" - Ben

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

```
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100

        GrabPass
        {
            "_GrabTexture"
        }

```

You should use the `_GrabTexture` name so that it only has to get executed once instead of once for every material.

You can then index into it as a sampler2D.


```glsl
            sampler2D _GrabTexture;
```

```glsl
float2 grabuv = i.uv;
#if !UNITY_UV_STARTS_AT_TOP
grabuv.y = 1 - grabuv.y;
#endif
fixed4 col = tex2D(_GrabTexture, grabuv);
```

Or, if you want to grab into it from its place on the screen, like to do a screen-space effect, you can do this:

```glsl
float2 grabuv = (i.vertex/_ScreenParams.xy);
#if !UNITY_UV_STARTS_AT_TOP
grabuv.y = 1 - grabuv.y;
#endif
fixed4 col = tex2D(_GrabTexture, grabuv);
```

## Depth Textures

If you define a sampler2D the following way, you can read the per-pixel depth.
```glsl
sampler2D _CameraDepthTexture;
```

```glsl
// Compute projective scaling factor...
float perspectiveDivide = 1.0f / i.screenPosition.w;

// Scale our view ray to unit depth.
float3 direction = i.worldDirection * perspectiveDivide;

// Calculate our UV within the screen (for reading depth buffer)
float2 screenUV = (i.screenPosition.xy * perspectiveDivide) * 0.5f + 0.5f;

// No idea
screenUV.y = 1 - screenUV.y; 

// VR stereo support
screenUV = UnityStereoTransformScreenSpaceTex(screenUV);

// Read depth, linearizing into worldspace units.    
float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV)));

float3 worldspace = direction * depth + _WorldSpaceCameraPos;
```

## VRC Layers

http://vrchat.wikidot.com/worlds:layers

Want to do a camera compute loop?  Shove everything on the "Compute" layer and put it somewhere a long way away.

## Need to iterate on Udon Sharp faster?

Edit -> Preferences -> General -> Auto Refresh, uncheck.

Whenever you do need Unity to reload, ctrl+r

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

NOTE: OPTION 2: TEST IT WITHOUT EXPLICIT ORDERING (manually executing .Render) FIRST AS THIS WILL SLOW THINGS DOWN  You will need to explicitly execute the order you want for all the cameras.   You can only do this in `Update` or `LateUpdate`, i.e.

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

 Convert detp function:
 ```c
     //Convert to Corrected LinearEyeDepth by DJ Lukis
     float depth = CorrectedLinearEyeDepth(sceneZ, direction.w);

     //Convert from Corrected Linear Eye Depth to Raw Depth 
     //Credit: https://www.cyanilux.com/tutorials/depth/#eye-depth

     depth = (1.0 - (depth * _ZBufferParams.w)) / (depth * _ZBufferParams.z);
     //Convert to Linear01Depth
     depth = Linear01Depth(depth);
```


This SLERP function, found by ACiiL,
```c
        ////============================================================
        //// blend between two directions by %
        //// https://www.shadertoy.com/view/4sV3zt
        //// https://keithmaggio.wordpress.com/2011/02/15/math-magician-lerp-slerp-and-nlerp/
        float3 slerp(float3 start, float3 end, float percent)
        {
            float d     = dot(start, end);
            d           = clamp(d, -1.0, 1.0);
            float theta = acos(d)*percent;
            float3 RelativeVec  = normalize(end - start*d);
            return      ((start*cos(theta)) + (RelativeVec*sin(theta)));
        }
```

Thanks, error.mdl for telling me how to disable batching.  This fixes issues where shaders need to get access to their local coordinates.
```
            Tags {  "DisableBatching"="true"}
```

## HALP The Unity compiler is emitting really bizarre assembly code.

Eh, just try using a different shader model, add a 
```glsl
#pragma  target 5.0
```
in your code or something.  Heck 5.0's been supported since the GeForce 400 in 2010.

## Udon events.

Re: `FixedUpdate`, `Update`, `LateUpdate`

From Merlin: https://docs.unity3d.com/ScriptReference/MonoBehaviour.html most of the events under Messages, with some exceptions like awake and things that don't make sense like the Unity networking related ones
you can look at what events UdonBehaviour.cs registers to see if they are actually there on Udon's side

## Getting big buffers

From @lox9973

BIG WARNING: After a lot of testing, we've found that this is slower than reading from a texture if doing intensive reads.  If you need to read from like 100 of these in a shader, probably best to move it into a texture first.

```c
cbuffer SampleBuffer {
    float _Samples[1023*4] : packoffset(c0);  
    float _Samples0[1023] : packoffset(c0);
    float _Samples1[1023] : packoffset(c1023);
    float _Samples2[1023] : packoffset(c2046);
    float _Samples3[1023] : packoffset(c3069);
};
float frag(float2 texcoord : TEXCOORD0) : SV_Target {
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
```c
void Update() {
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
```
Properties {
...

    _Spread00 ("Spine",     Vector) = (40, 40, 40, 1)
    _Spread01 ("Head",        Vector) = (40, 40, 80, 1)
    ...
    _Spread50 ("IndexProximal",    Vector) = (45, 20,  9, 1)
    _Spread51 ("IndexDistal",    Vector) = (45,  9,  9, 1)

    _Finger00 ("LeftThumb",        Vector) = (0, 0, 0, 0)
    _Finger01 ("RightThumb",    Vector) = (0, 0, 0, 0)
    ...
    _Finger40 ("LeftLittle",    Vector) = (0, 0, 0, 0)
    _Finger41 ("RightLittle",    Vector) = (0, 0, 0, 0)
}

CGPROGRAM
...
cbuffer SpreadBuffer {
    float4 _Spread[6][2] : packoffset(c0);  
    float4 _Spread00 : packoffset(c0);
    float4 _Spread01 : packoffset(c1);
    ...
    float4 _Spread50 : packoffset(c10);
    float4 _Spread51 : packoffset(c11);
};
cbuffer FingerBuffer {
    float4 _Finger[10] : packoffset(c0);  
    float4 _Finger00 : packoffset(c0);
    ...
    float4 _Finger40 : packoffset(c8);
    float4 _Finger41 : packoffset(c9);
}
ENDCG
```

## Keywords.

(1) DO NOT INCLUDE `[Toggle]`!!
INSTEAD, use `[ToggleUI]`

(2) If you do want to use keywords, you can from this list: https://pastebin.com/83fQvZ3n

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



## Making audio play

Thanks, @lox9973 for informing me of this: https://gitlab.com/-/snippets/2115172


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
