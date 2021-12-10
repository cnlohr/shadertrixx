
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SaccFlight : UdonSharpBehaviour
{
	[UdonSynced] public bool enableFlight = false;
    private VRCPlayerApi localPlayer;
    public float ThrustStrength = .33f;
    [Tooltip("Strength of extra thrust applied when trying to thrust in direction going against movement")]
    public float BackThrustStrength = .5f;
    private float _thruststrength;
    private float _backthruststrength;
    private float controllertriggerR;
    private float controllertriggerL;
    private bool InVR = false;
//	public Texel.AccessControl ACL;

    private void Start()
    {
        localPlayer = Networking.LocalPlayer;
        if (localPlayer == null) { gameObject.SetActive(false); }//fixedupdate runs before this happens and causes a crash in the editor until vrc fix it
        else if (localPlayer.IsUserInVR())
        { InVR = true; }
        //to match 90fps with deltatime
        _thruststrength = ThrustStrength * 90;
        _backthruststrength = BackThrustStrength * 90;
		if( Networking.IsMaster )
		{
			enableFlight = false;
		}
		GetComponent<MeshRenderer> ().material.SetFloat( "_SelMode", enableFlight?1:0 );
    }
    private void FixedUpdate()
    {
        if (enableFlight && !localPlayer.IsPlayerGrounded())//only does anything if in the air.
        {
            float DeltaTime = Time.fixedDeltaTime;
            float ForwardThrust = Mathf.Max(Input.GetAxisRaw("Oculus_CrossPlatform_SecondaryIndexTrigger"), Input.GetKey(KeyCode.F) ? 1 : 0);
            float UpThrust = Mathf.Max(Input.GetAxisRaw("Oculus_CrossPlatform_PrimaryIndexTrigger"), Input.GetKey(KeyCode.Space) ? 1 : 0);

            Vector3 PlayerVel = localPlayer.GetVelocity();

            Quaternion newrot;
            Vector3 NewForwardVec;
            if (InVR)
            {
                newrot = localPlayer.GetTrackingData(VRCPlayerApi.TrackingDataType.RightHand).rotation * Quaternion.Euler(0, 60, 0);
                NewForwardVec = newrot * Vector3.forward;
            }
            else//Desktop
            {
                newrot = localPlayer.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).rotation;
                NewForwardVec = newrot * (Vector3.forward);
            }
            //get backwards amount
            float BackThrustAmount = -((Vector3.Dot(PlayerVel, NewForwardVec)) * _backthruststrength * DeltaTime);
            NewForwardVec = NewForwardVec * _thruststrength * ForwardThrust * DeltaTime * Mathf.Max(1, (BackThrustAmount * ForwardThrust));

            Vector3 NewUpVec = ((Vector3.up * _thruststrength) * UpThrust * DeltaTime);

            localPlayer.SetVelocity(PlayerVel + NewForwardVec + NewUpVec);
        }
    }
    public override void OnPlayerRespawn(VRCPlayerApi player)
    {
        if (player.isLocal)
        { player.SetVelocity(Vector3.zero); }
    }
	
	// Update is called once per frame
	public override void Interact()
	{
		bool master = Networking.IsMaster;
		
//		if( Utilities.IsValid( ACL ) )
//		{
//			if( ACL._LocalHasAccess() )
//				master = true;
//		}
		
		if( master )
		{
			Networking.SetOwner( Networking.LocalPlayer, gameObject );
			enableFlight = !enableFlight;
			RequestSerialization();
			GetComponent<MeshRenderer> ().material.SetFloat( "_SelMode", enableFlight?1:0 );
		}
	}
	
}
