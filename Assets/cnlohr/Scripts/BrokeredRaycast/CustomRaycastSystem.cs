
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;



namespace BrokeredUpdates
{
	public class CustomRaycastSystem : UdonSharpBehaviour
	{
		public LayerMask rmask;
		public RaycastHit lastHit;
		public int currentHandID;
		public Transform [] lasthits;
		
		private bool inVR;

		void Start()
		{
			inVR = false;
			VRCPlayerApi localPlayer = Networking.LocalPlayer;
			if( localPlayer != null && localPlayer.IsUserInVR() )
			{
				inVR = true;
			}
			lasthits = new Transform[2];
		}
		
		void Update()
		{
			VRCPlayerApi localPlayer = Networking.LocalPlayer;
			if( localPlayer == null ) return;

			for( currentHandID = 0; currentHandID < (inVR?2:1); currentHandID++ )
			{
				VRCPlayerApi.TrackingDataType hand;
				float rotationangle = 41.0f;
				if( !inVR )
				{
					hand = VRCPlayerApi.TrackingDataType.Head;
					rotationangle = 0;
				}
				else if( currentHandID == 0 )
				{
					hand = VRCPlayerApi.TrackingDataType.LeftHand;
				}
				else
				{
					hand = VRCPlayerApi.TrackingDataType.RightHand;
				}
				VRCPlayerApi.TrackingData xformHand = localPlayer.GetTrackingData( hand );
				Vector3 Pos = xformHand.position;
				Vector3 Dir = (xformHand.rotation * Quaternion.Euler(0.0f, rotationangle, 0.0f) ) * Vector3.forward;
				
				Transform transform;
				
				if (!Physics.Raycast( Pos, Dir, out lastHit, 3.0f, rmask.value ) || ( lastHit.transform == null ) )
				{
					transform = null;
				}
				else
				{
					transform = lastHit.transform;
				}
				
				if( transform != lasthits[currentHandID] && lasthits[currentHandID] != null )
				{
					Component [] behaviors = lasthits[currentHandID].GetComponents( typeof(UdonBehaviour) );
					foreach( Component u in behaviors )
						((UdonBehaviour)u).SendCustomEvent("RaycastIntersectionLeave");
					lasthits[currentHandID] = null;
				}
				if( transform != null )
				{
					Component [] behaviors = transform.GetComponents( typeof(UdonBehaviour) );
					foreach( Component u in behaviors )
						((UdonBehaviour)u).SendCustomEvent("RaycastIntersectedMotion");
					lasthits[currentHandID] = transform;
				}
			}
		}
	}
}
