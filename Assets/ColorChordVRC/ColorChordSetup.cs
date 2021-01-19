
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class TestUpdateRenderTexture : UdonSharpBehaviour
{
    public Material mat;
   // public int toggle;
   // public Texture2D test;
    public AudioSource aus;
   // public AudioClip auclip;
    //XXX Consider: Shader.SetGlobalFloatArray

    void Start()
    {
       // Debug.Log("Start!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
        mat.SetFloat("_TestFloat", 0.0f);
      //  aus.clip = auclip;
        aus.Play();
    }

    void Update()
    {
        if (!aus.isPlaying) aus.Play();
        //float[] spectrum = new float[8192];
        float[] trunc = new float[1023];
        //aus.GetSpectrumData(spectrum, 0, FFTWindow.Blackman);
        //int place = aus.timeSamples;
        aus.GetOutputData(trunc, 0);
        mat.SetFloatArray("_AudioFrames", trunc);


  //      float[] sound = new float[16384];
  //      aus.GetOutputData(sound, 0);
  //      test.LoadRawTextureData(BitConverter.ToByte(sound));

//   mat.SetFloat("_SamplesPerSecond", aus.);
        //mat.SetFloat("_TestInt", place );
        //mat.SetFloat("_TestFloat", (toggle!=0)?10.0f:0.0f );
        //toggle = (toggle!=0)?0:1;
    }
}
