
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using System;

public class TestUpdateRenderTexture : UdonSharpBehaviour
{
    public Material mat;
    public AudioSource aus;

    void Start()
    {
        //mat.SetFloat("_TestFloat", 0.0f);
        aus.Play();
    }

    void Update()
    {
        if (!aus.isPlaying) aus.Play();
        float[] trunc = new float[1023];
        aus.GetOutputData(trunc, 0);
        mat.SetFloatArray("_AudioFrames", trunc);
    }
}
