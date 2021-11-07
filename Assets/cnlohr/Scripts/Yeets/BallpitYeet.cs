
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
namespace cnlohr
{
	public class BallpitYeet : UdonSharpBehaviour
	{
		float LastYeet;
		
		public GameObject Spawn;
		void Start()
		{
			LastYeet = 0;
		}

		public override void OnPlayerTriggerEnter(VRCPlayerApi player)
		{
			if( Time.timeSinceLevelLoad - LastYeet > 0.2 && Vector3.Distance( transform.position, Spawn.transform.position ) > 7 )
			{
				Vector3 yeetvector = transform.TransformDirection( Vector3.forward ) * -10;
				player.SetVelocity( yeetvector );
				LastYeet = Time.timeSinceLevelLoad;
			}
		}

	}
}