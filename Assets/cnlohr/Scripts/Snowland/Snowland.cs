
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class Snowland : UdonSharpBehaviour
{
	public Camera camTop;
	public Camera camBot;
	
	public RenderTexture rtDepthThrowawayColor;
	
	private RenderTexture rtTop;
	private RenderTexture rtBot;
	
	private bool bInitted;
    void Start()
    {
        rtTop = camTop.targetTexture;
        rtBot = camBot.targetTexture;
		
		camTop.SetTargetBuffers( rtDepthThrowawayColor.colorBuffer, rtTop.depthBuffer );
		camBot.SetTargetBuffers( rtDepthThrowawayColor.colorBuffer, rtBot.depthBuffer );
		
		camTop.enabled = false;
		camBot.enabled = false;
		bInitted = false;
    }
	
	public override void Interact()
	{
		bInitted = false;
	}
	
	void Update()
	{
		if( bInitted == false )
		{
			camTop.Render();
			bInitted = true;
		}
		else
		{
			camBot.Render();
		}
	}
}
