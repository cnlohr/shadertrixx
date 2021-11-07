
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using BrokeredUpdates;

#if !COMPILER_UDONSHARP && UNITY_EDITOR
using VRC.SDKBase.Editor.BuildPipeline;
using UnityEditor;
using UdonSharpEditor;
using System.Collections.Immutable;
using System.Collections.Generic;
#endif

namespace BrokeredUpdates
{
	[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
	public class BrokeredBlockIDer : UdonSharpBehaviour
	{
		public BrokeredUpdateManager brokeredUpdateManager;
		public CustomRaycastSystem customRaycastSystem;
		public int defaultBlockID;
		private bool masterMoving = false;
		[UdonSynced] private int blockID = 0;
		private int instanceID;
		private Rigidbody thisRigidBody;
		private const float fSnappers = 0.69f;
		private float fCursor0 = 0;
		private float fCursor1 = 0;
		private int [] useFlags;
		private bool [] wasTriggered;
		public bool allowSnap = true;
		private BrokeredSync bs;

		void Start()
		{
			thisRigidBody = GetComponent<Rigidbody>();
			useFlags = new int[2];
			wasTriggered = new bool[2];

			instanceID = brokeredUpdateManager._GetIncrementingID();
			if( Networking.IsMaster )
				blockID = defaultBlockID + (_GetMotionMode()<<8);
			else
				blockID = defaultBlockID + (_GetMotionMode()<<8); //XXX TEST ME.
			
			fCursor0 = 0;
			fCursor1 = 0;

#if UNITY_EDITOR
			blockID = defaultBlockID + (_GetMotionMode()<<8);
#endif
			bs = (BrokeredSync)gameObject.GetComponent<BrokeredSync>();
			_UpdateID();
		}
		
		public void _SetBlockID( int bid )
		{
			blockID = bid + (blockID & 0xffff00);
		}
		
		override public void OnPickup ()
		{
			brokeredUpdateManager._UnregisterSubscription( this ); // In case it was already subscribed.
			brokeredUpdateManager._RegisterSubscription( this );
			masterMoving = true;
			Networking.SetOwner( Networking.LocalPlayer, gameObject );
		}
		
		public int _GetMotionMode()
		{
			Rigidbody rb = GetComponent<Rigidbody>();
			if( allowSnap )
			{
				return 2;
			}
			else if( Utilities.IsValid( rb ) && rb.useGravity )
			{
				return 3;
			}
			else if( Utilities.IsValid( rb ) && rb.isKinematic )
			{
				return 4;
			}
			else
			{
				// Motion, no gravity.
				return 1;
			}
		}
		
		public void _UpdateID()
		{
			MaterialPropertyBlock block = new MaterialPropertyBlock();
			MeshRenderer mr = GetComponent<MeshRenderer>();
			block.SetVector( "_InstanceID", new Vector4( instanceID, blockID, fCursor0, fCursor1 ) );
			mr.SetPropertyBlock(block);
		}

		public void _SetModeInternal( int mode )
		{
			bool upd = false;
			if( mode == 0 ) return;
			if( mode == 4 )
			{
				//4 = No motion.
				if( bs.bKinematicOnRelease != true || bs.bUseGravityOnRelease != false || allowSnap != false ) upd = true;
				bs.bKinematicOnRelease = true;
				bs.bUseGravityOnRelease = false;
				allowSnap = false;
			}
			if( mode == 1 )
			{
				//1 = Free Floating
				if( bs.bKinematicOnRelease != false || bs.bUseGravityOnRelease != false || allowSnap != false ) upd = true;
				bs.bKinematicOnRelease = false;
				bs.bUseGravityOnRelease = false;
				allowSnap = false;
			}
			if( mode == 2 )
			{
				//2 = Snapped
				if( bs.bKinematicOnRelease != true || bs.bUseGravityOnRelease != false || allowSnap != true ) upd = true;
				allowSnap = true;
				bs.bKinematicOnRelease = true;
				bs.bUseGravityOnRelease = false;
			}
			if( mode == 3 )
			{
				//3 = Gravity
				if( bs.bKinematicOnRelease != false || bs.bUseGravityOnRelease != true || allowSnap != false ) upd = true;
				allowSnap = false;
				bs.bKinematicOnRelease = false;
				bs.bUseGravityOnRelease = true;
			}
			
			if( upd )
			{
				GetComponent<Rigidbody>().useGravity = bs.bUseGravityOnRelease ;
				GetComponent<Rigidbody>().isKinematic = bs.bKinematicOnRelease;
				GetComponent<Rigidbody>().WakeUp();
			}
			
			
			blockID = (blockID & 0xffff0ff) | (mode<<8);
		}

		public override void OnDeserialization()
		{
			_SetModeInternal( ( blockID & 0xf00 ) >> 8 );
			_UpdateID();
		}

		public void _BrokeredUpdate()
		{
			if( masterMoving )
			{
				/*
				
				Quaternion q = transform.localRotation;
				//Figure out which face is up.
				Vector3 nx = q * new Vector3(-1, 0, 0 );
				Vector3 px = q * new Vector3( 1, 0, 0 );
				Vector3 ny = q * new Vector3( 0,-1, 0 );
				Vector3 py = q * new Vector3( 0, 1, 0 );
				Vector3 nz = q * new Vector3( 0, 0,-1 );
				Vector3 pz = q * new Vector3( 0, 0, 1 );
				Vector3 bestup = new Vector3( 0, -1000, 0 );
				if( nx.y > bestup.y ) { bestup = nx; }
				if( px.y > bestup.y ) { bestup = px; }
				if( ny.y > bestup.y ) { bestup = ny; }
				if( py.y > bestup.y ) { bestup = py; }
				if( nz.y > bestup.y ) { bestup = nz; }
				if( pz.y > bestup.y ) { bestup = pz; }
				Debug.Log( bestup );
				int rx = (int)(bestup.x * 10 + 8);
				int rz = (int)(bestup.z * 10 + 8);
				if( rx < 0 ) rx = 0;
				if( rz < 0 ) rz = 0;
				if( rx > 15 ) rx = 15;
				if( rz > 15 ) rz = 15;
				blockID = rx + rz * 16;
				fCursor = blockID+1;
				*/
/*
				float fsx = (transform.localPosition.x - Mathf.Round( transform.localPosition.x / fSnappers ))*fSnappers;
				float fsy = (transform.localPosition.y - Mathf.Round( transform.localPosition.y / fSnappers ))*fSnappers;
				float fsz = (transform.localPosition.z - Mathf.Round( transform.localPosition.z / fSnappers ))*fSnappers;
				blockID = ((int)(fsx * 6)) + ((int)(fsy * 6))*6 + ((int)(fsz * 6))*36;
*/
			}
			_UpdateID();
		}
		
		public bool _SnapNow()
		{
			bool dosnap = allowSnap;
			if( Utilities.IsValid( GetComponent<Rigidbody>() ) )
				if( !GetComponent<Rigidbody>().isKinematic )
					dosnap = false;
			if( dosnap )
			{
				//Snap
				Vector3 ea = transform.localRotation.eulerAngles;
				transform.localPosition = new Vector3( 
					Mathf.Round( transform.localPosition.x / fSnappers ) * fSnappers,
					Mathf.Round( transform.localPosition.y / fSnappers ) * fSnappers,
					Mathf.Round( transform.localPosition.z / fSnappers ) * fSnappers
				);
				ea.x = Mathf.Round( ea.x / 90.0f ) * 90.0f;
				ea.y = Mathf.Round( ea.y / 90.0f ) * 90.0f;
				ea.z = Mathf.Round( ea.z / 90.0f ) * 90.0f;
				transform.localRotation =  Quaternion.Euler( ea );
				return true;
			}
			return false;
		}
		
		public void _Nudge()
		{
			transform.localPosition = new Vector3( transform.localPosition.x, transform.localPosition.y + fSnappers, transform.localPosition.z );
		}

		override public void OnDrop()
		{
			RequestSerialization();
			masterMoving = false;
			brokeredUpdateManager._UnregisterSubscription( this );

			//If the object has a rigid body, don't snap.
			_SnapNow();
			_UpdateID();
		}

		public void RaycastIntersectionLeave()
		{
			int hid = customRaycastSystem.currentHandID;
			if( hid == 0 )
			{
				fCursor0 = 0;
			}
			else if( hid == 1 )
			{
				fCursor1 = 0;
			}
			_UpdateID();
		}
		
		public void RaycastIntersectedMotion()
		{
			if( customRaycastSystem.lastHit.distance > 1.8 ) return;
			int hid = customRaycastSystem.currentHandID;
			float triggerQty = 
				Mathf.Max(Input.GetAxisRaw((hid==0)?"Oculus_CrossPlatform_PrimaryIndexTrigger":"Oculus_CrossPlatform_SecondaryIndexTrigger"),
				Input.GetMouseButton(1) ? 1 : 0);
				
			bool bTrig = (triggerQty > 0.5f);

			if( Networking.GetOwner( gameObject ) == Networking.LocalPlayer )
			{
				Vector3 local = customRaycastSystem.lastHit.transform.InverseTransformPoint( customRaycastSystem.lastHit.point );
				Vector2 hc = new Vector2( 0, 0 );
				float biggest = 0;
				int face = 0;
				if(  local.x > biggest ) { hc = new Vector2(-local.y, local.z ); biggest = local.x; face = 0; }
				if( -local.x > biggest ) { hc = new Vector2(-local.z, local.y ); biggest =-local.x; face = 1; }
				if(  local.y > biggest ) { hc = new Vector2( local.x, local.z ); biggest = local.y; face = 2; }
				if( -local.y > biggest ) { hc = new Vector2(-local.z,-local.x ); biggest =-local.y; face = 3; }
				if(  local.z > biggest ) { hc = new Vector2( local.x,-local.y ); biggest = local.z; face = 4; }
				if( -local.z > biggest ) { hc = new Vector2(-local.x,-local.y ); biggest =-local.z; face = 5; }
				hc += new Vector2( 0.5f, 0.5f );
				//Debug.Log( face );
				//Debug.Log( hc );
				float fc = ((int)(hc.x*16)) + ((int)(hc.y*16))*16 + 1; 
				if( hid == 0 )
					fCursor0 = fc;
				else
					fCursor1 = fc;
				
				if( bTrig && !wasTriggered[hid] )
				{
					Debug.Log( $"Command Press {fc}" );
					if( fc < 240 )
					{
						blockID = ((int)fc - 1) | ( blockID & 0x0fffff00);
					}
					else
					{
						if( fc == 252 )
						{
							_SetModeInternal( 4 );
						}
						if( fc == 253 )
						{
							_SetModeInternal( 1 );
						}
						if( fc == 254 )
						{
							_SetModeInternal( 2 );
						}
						if( fc == 255 )
						{
							_SetModeInternal( 3 );
						}
					}
					RequestSerialization();
					_SnapNow();
					bs.OnPickup();
					bs.OnDrop();
				}
				_UpdateID();
			}
			else
			{
				if( bTrig )
					Networking.SetOwner( Networking.LocalPlayer, gameObject );
			}
			wasTriggered[hid] = bTrig;
		}
	}
}



#if !COMPILER_UDONSHARP && UNITY_EDITOR
namespace UdonSharp
{
	public class UdonSharpBuildChecks_BrokeredBlockIDer : IVRCSDKBuildRequestedCallback
	{
		public int callbackOrder => -1;

		public bool OnBuildRequested(VRCSDKRequestedBuildType requestedBuildType)
		{
			if (requestedBuildType == VRCSDKRequestedBuildType.Avatar) return true;

			foreach( UnityEngine.GameObject go in GameObject.FindObjectsOfType(typeof(GameObject)) as UnityEngine.GameObject[] )
			{
				foreach( BrokeredBlockIDer b in go.GetUdonSharpComponentsInChildren< BrokeredBlockIDer >() )
				{
					b.UpdateProxy();
					if( b.brokeredUpdateManager == null )
					{
						Debug.LogError($"[<color=#FF00FF>BrokeredBlockIDer</color>] Missing brokeredUpdateManager reference on {b.gameObject.name}");
						typeof(UnityEditor.SceneView).GetMethod("ShowNotification", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static).Invoke(null, new object[] { $"BrokeredSync missing brokeredUpdateManager reference on {b.gameObject.name}" });
						return false;				
					}
					if( b.customRaycastSystem == null )
					{
						Debug.LogError($"[<color=#FF00FF>BrokeredBlockIDer</color>] Missing customRaycastSystem reference on {b.gameObject.name}");
						typeof(UnityEditor.SceneView).GetMethod("ShowNotification", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static).Invoke(null, new object[] { $"BrokeredSync missing brokeredUpdateManager reference on {b.gameObject.name}" });
						return false;				
					}
				}
			}
			return true;
		}
	}
}

namespace BrokeredUpdates
{
	[CustomEditor(typeof(BrokeredUpdates.BrokeredBlockIDer))]
	public class BrokeredUpdatesBrokeredBlockIDerEditor : Editor
	{
		public override void OnInspectorGUI()
		{
			if (UdonSharpGUI.DrawDefaultUdonSharpBehaviourHeader(target)) return;
			EditorGUILayout.Space();
			if (GUILayout.Button(new GUIContent("Attach brokeredUpdateManager to all Brokered Sync objects.", "Automatically finds all Brokered Sync objects and attaches the manager.")))
			{

				int ct = 0;
				BrokeredUpdateManager manager = null;
				foreach( UnityEngine.GameObject go in GameObject.FindObjectsOfType(typeof(GameObject)) as UnityEngine.GameObject[] )
				{
					foreach( BrokeredUpdateManager b in go.GetUdonSharpComponentsInChildren<BrokeredUpdateManager>() )
					{
						manager = b;
					}
				}
				if( manager == null )
				{
					Debug.LogError($"[<color=#FF00FF>UdonSharp</color>] Could not find a BrokeredUpdateManager. Did you add the prefab to your scene?");
					return;
				}

				foreach( UnityEngine.GameObject go in GameObject.FindObjectsOfType(typeof(GameObject)) as UnityEngine.GameObject[] )
				{
					foreach( BrokeredBlockIDer b in go.GetUdonSharpComponentsInChildren< BrokeredBlockIDer >() )
					{
						b.UpdateProxy();
						if( b.brokeredUpdateManager == null )
						{
							Debug.Log( $"Attaching to {b.gameObject.name}" );
							//https://github.com/MerlinVR/UdonSharp/wiki/Editor-Scripting#non-inspector-editor-scripts
							b.brokeredUpdateManager = manager;
							b.ApplyProxyModifications();
							ct++;
						}
					}
				}

				CustomRaycastSystem system = null;
				foreach( UnityEngine.GameObject go in GameObject.FindObjectsOfType(typeof(GameObject)) as UnityEngine.GameObject[] )
				{
					foreach( CustomRaycastSystem b in go.GetUdonSharpComponentsInChildren<CustomRaycastSystem>() )
					{
						system = b;
					}
				}
				if( system == null )
				{
					Debug.LogError($"[<color=#FF00FF>UdonSharp</color>] Could not find a CustomRaycastSystem. Did you add the prefab to your scene?");
					return;
				}

				foreach( UnityEngine.GameObject go in GameObject.FindObjectsOfType(typeof(GameObject)) as UnityEngine.GameObject[] )
				{
					foreach( BrokeredBlockIDer b in go.GetUdonSharpComponentsInChildren< BrokeredBlockIDer >() )
					{
						b.UpdateProxy();
						if( b.customRaycastSystem == null )
						{
							Debug.Log( $"Attaching to {b.gameObject.name}" );
							//https://github.com/MerlinVR/UdonSharp/wiki/Editor-Scripting#non-inspector-editor-scripts
							b.customRaycastSystem = system;
							b.ApplyProxyModifications();
							ct++;
						}
					}
				}


				if( ct > 0 )
					Debug.Log( $"Attached {ct} manager references." );
			}
			if (GUILayout.Button(new GUIContent("Gridify all.", "Snap all objects to grid now.")))
			{
				int ct = 0;
				int ctb = 0;
				List<BrokeredBlockIDer> bli = new List<BrokeredBlockIDer>();
				foreach( UnityEngine.GameObject go in GameObject.FindObjectsOfType(typeof(GameObject)) as UnityEngine.GameObject[] )
					foreach( BrokeredBlockIDer b in go.GetUdonSharpComponentsInChildren<BrokeredBlockIDer>() )
						bli.Add( b );
				foreach( BrokeredBlockIDer b in bli )
				{
					b.UpdateProxy();
					ct += b._SnapNow()?1:0;

					//Nudge colliding blocks.
					foreach( BrokeredBlockIDer be in bli )
					{
						if( be != b )
						{
							if( Vector3.Distance( be.transform.localPosition, b.transform.localPosition ) < 0.1 )
							{
								b._Nudge();
							}
						}
					}
					b.ApplyProxyModifications();
					ctb++;
				}
				Debug.Log( $"Gridded {ct}/{ctb}" );
			}
			if (GUILayout.Button(new GUIContent("Randomize IDs.", "Random IDs.")))
			{
				int ct = 0;
				foreach( UnityEngine.GameObject go in GameObject.FindObjectsOfType(typeof(GameObject)) as UnityEngine.GameObject[] )
				{
					foreach( BrokeredBlockIDer b in go.GetUdonSharpComponentsInChildren<BrokeredBlockIDer>() )
					{
						b.UpdateProxy();
						b.defaultBlockID = (int)Random.Range( 0, 182.99f );
						ct++;
						b._SetBlockID( b.defaultBlockID );
						b._UpdateID();
						b.ApplyProxyModifications();
					}
				}
				Debug.Log( $"Randomized {ct}" );
			}
			
			EditorGUILayout.Space();
			base.OnInspectorGUI();
		}
	}
}
#endif
