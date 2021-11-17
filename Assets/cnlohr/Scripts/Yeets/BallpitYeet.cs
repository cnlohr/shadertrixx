
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
namespace cnlohr
{
	public class BallpitYeet : UdonSharpBehaviour
	{
		public float YeetIntensity = 10;
		public GameObject Spawn;

		void Start()
		{
		}
		
		private Vector3 GetYeetVector()
		{
			return transform.TransformDirection( Vector3.forward ) * -YeetIntensity;
		}

		public override void OnPlayerTriggerStay(VRCPlayerApi player)
		{
			OnPlayerTriggerEnter( player );
		}
		
		public override void OnPlayerTriggerEnter(VRCPlayerApi player)
		{
			if( Vector3.Distance( transform.position, Spawn.transform.position ) > 7 )
			{
				player.SetVelocity( GetYeetVector() + ( transform.position - player.GetPosition() ) * .25f ); // Apply correction
			}
		}
		
		public void OnTriggerEnter(Collider collide)
		{
			if( Utilities.IsValid( collide ) )
			{
				GameObject go = collide.gameObject;
				if( Utilities.IsValid( go ) )
				{
					Rigidbody rb = collide.gameObject.GetComponent<Rigidbody>();
					if( Utilities.IsValid( rb ) )
					{
						rb.velocity = GetYeetVector() + ( transform.position - rb.position ) * .25f; // Apply correction
					}
				}
			}
		}

	}
}