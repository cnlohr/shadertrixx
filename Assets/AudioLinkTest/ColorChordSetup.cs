
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

		float[] allsamples;
		float[] samples0;
		float[] samples1;
		float[] samples2;
		float[] samples3;

		allsamples = new float[4092];
		samples0 = new float[1023];
		samples1 = new float[1023];
		samples2 = new float[1023];
		samples3 = new float[1023];

		aus.GetOutputData(allsamples, 0);

		System.Array.Copy(allsamples, 4092-1023*4, samples0, 0, 1023);
		System.Array.Copy(allsamples, 4092-1023*3, samples1, 0, 1023);
		System.Array.Copy(allsamples, 4092-1023*2, samples2, 0, 1023);
		System.Array.Copy(allsamples, 4092-1023*1, samples3, 0, 1023);

		//mat.SetFloatArray("_AudioFrames", samples0);
		
		mat.SetFloatArray("_Samples0", samples0);
		mat.SetFloatArray("_Samples1", samples1);
		mat.SetFloatArray("_Samples2", samples2);
		mat.SetFloatArray("_Samples3", samples3);
	}
}
