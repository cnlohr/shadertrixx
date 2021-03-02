
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class fallingcherryblossoms : UdonSharpBehaviour
{
	public RenderTexture OutRenderTexture;
	public Camera DropCamera;
	public GameObject PetalGrid;
	public float diameter = 3;
	public float depth = 10;
	public bool constantlyUpdate;

	private int updateCount;

	void Start()
	{
		updateCount = 0;
		DropCamera.enabled = true;
		DropCamera.targetTexture = OutRenderTexture;
	}
	
	void Update()
	{
		if( constantlyUpdate || updateCount == 100 )
		{
			if( updateCount == 100 )
			{
				//Disable camera after 100 frames.
				DropCamera.enabled = false;
			}
			
			PetalGrid.transform.localScale = new Vector3( diameter*100, depth*100, diameter*100 );
			DropCamera.orthographicSize = diameter/2;
			
			if( constantlyUpdate )
			{
				updateCount = 0;
				DropCamera.enabled = true;
			}
		}
		else
		{
			updateCount++;
		}
	}
}
