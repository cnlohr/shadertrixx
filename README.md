# shadertrixx

CNLohr's repo for his Unity assets and other shader notes surrounding VRChat.  This largely contains stuff made by other people but I have kind of collected.

## The most important trick

```hlsl
#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y)))) 
```

Thanks, @d4rkpl4y3r - this originally actually comes from an epic bgolus forum post: https://forum.unity.com/threads/translating-a-glsl-shader-noise-algorithm-to-hlsl-cg.485750/


## Additional tricks

From @Lyuma
 * [flatten] (UNITY_FLATTEN macro) to force both cases of an if statement or
 * force a branch with [branch] (UNITY_BRANCH macro);
 * force loop to unroll with [unroll] (UNITY_UNROLL) or
 * force a loop with [loop] (UNITY_LOOP)
 * there's also [call] for if or switch statements I think, not sure exactly how it works.


## tanoise

Very efficient noise based on Toocanzs noise. https://github.com/cnlohr/shadertrixx/blob/main/Assets/tanoise/README.md

## scrn_aurora

tanoise-modified aurora, originally written by nimitz, modified further by scrn.  https://github.com/cnlohr/shadertrixx/tree/main/Assets/scrn_aurora

## ColorChordVRC

(In progress)

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
