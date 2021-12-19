
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class Snowland : UdonSharpBehaviour
{
	public Camera camTop;
	public Camera camBot;
	
	public RenderTexture rtDepthThrowawayColor1;
	public RenderTexture rtDepthThrowawayColor2;
	
	public RenderTexture rtTop;
	public RenderTexture rtBot;
	
	private bool bInitted;
    void Start()
    {
        //rtTop = camTop.targetTexture;
        //rtBot = camBot.targetTexture;
		
		camTop.SetTargetBuffers( rtDepthThrowawayColor1.colorBuffer, rtTop.depthBuffer );
		camBot.SetTargetBuffers( rtDepthThrowawayColor2.colorBuffer, rtBot.depthBuffer );

		bInitted = false;
		//camTop.enabled = false;
		//camBot.enabled = false;
		
    }
	
	//public void Render()
	//{
	//	if( bInitted == false )
	//	{
	//		camTop.Render();
	//		bInitted = true;
	//	}
	//	else
	//	{
	//		camBot.Render();
	//	}
	//}
}
