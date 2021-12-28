
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

#if !EDITOR

public class Snowland : UdonSharpBehaviour
{
	public Camera camTop;
	public Camera camBot;
	
	public RenderTexture rtDepthThrowawayColorTop;
	public RenderTexture rtDepthThrowawayColorBot;

	public RenderTexture rtTop;
	public RenderTexture rtBot;
	
	private bool bInitted;
	private bool bDisabled;
	void Start()
	{
		//rtTop = camTop.targetTexture;
		//rtBot = camBot.targetTexture;
		Debug.Log( "SNOWLAND START");
		camTop.SetTargetBuffers( rtDepthThrowawayColorTop.colorBuffer, rtTop.depthBuffer );
		camBot.SetTargetBuffers( rtDepthThrowawayColorBot.colorBuffer, rtBot.depthBuffer );

		bInitted = false;
		//camTop.enabled = false;
		//camBot.enabled = false;
		
		Debug.Log( "Snowland Start Done");
	}
	
	public void LateUpdate()
	{
		if( !bDisabled )
		{
			if( bInitted == false )
			{
				//camTop.Render();
				bInitted = true;
			}
			else
			{
				camTop.gameObject.SetActive( false );
				Debug.Log( "Disabled top camera.");
				bDisabled = true;
				//camBot.Render();
			}
		}
	}
}

#endif