
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class Snowland : UdonSharpBehaviour
{
	public Camera camTop;
	public Camera camBot;
	
	public RenderTexture rtDepthThrowawayColor;
	
	public RenderTexture rtTop;
	public RenderTexture rtBot;
	
	private bool bInitted;
    void Start()
    {
        //rtTop = camTop.targetTexture;
        //rtBot = camBot.targetTexture;
		
		camTop.SetTargetBuffers( rtDepthThrowawayColor.colorBuffer, rtTop.depthBuffer );
		camBot.SetTargetBuffers( rtDepthThrowawayColor.colorBuffer, rtBot.depthBuffer );

		bInitted = false;
		
    }
	
	void Render()
	{
		if( bInitted == false )
		{
			camTop.Render();
			bInitted = true;
			camTop.enabled = false;
			//camBot.enabled = false;
		}
		else
		{
			//camBot.Render();
		}
	}
}
