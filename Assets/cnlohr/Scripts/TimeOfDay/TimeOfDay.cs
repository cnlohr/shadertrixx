
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using BrokeredUpdates;

namespace cnlohr
{
	[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
	public class TimeOfDay : UdonSharpBehaviour
	{
		public Light lightToControl;
		private bool bHeld;
		
		void Start()
		{
			
		}
		
		override public void OnPickup ()
		{
			bHeld = true;
		}
		
		override public void OnDrop()
		{
			bHeld = false;
		}

		void Update()
		{
			if( !bHeld )
			{
				transform.localRotation *= Quaternion.Euler((float)((Time.deltaTime)*.5f),0,0);
			}
			//gameObject.GetComponent<BrokeredSync>()._SendMasterMove();
			lightToControl.transform.localRotation = transform.localRotation;
		}
	}
}
