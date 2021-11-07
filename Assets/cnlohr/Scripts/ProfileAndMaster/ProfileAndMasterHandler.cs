// MIT License
// Copyright (c) 2021 Merlin
// Modifications (c) 2021 cnlohr

using UdonSharp;
using UnityEngine;
using VRC.SDK3.Components;
using VRC.SDKBase;
using VRC.Udon;

namespace cnlohr
{
	[DefaultExecutionOrder(1000000000)]
	public class ProfileAndMasterHandler : UdonSharpBehaviour
	{
		UnityEngine.UI.Text timeText;
		ProfileAndMasterKickoff kickoff;

		private void Start()
		{
			kickoff = GetComponent<ProfileAndMasterKickoff>();
			timeText = GetComponentInChildren<UnityEngine.UI.Text>();
		}

		int currentFrame = -1;
		float elapsedTime = 0f;
		int frame400count  = 0;
		float elapsed400total = 0f;
		float lastframe400 = 0f;

		private void FixedUpdate()
		{
			if (currentFrame != Time.frameCount)
			{
				elapsedTime = 0f;
				currentFrame = Time.frameCount;
			}

			if (kickoff)
				elapsedTime += (float)kickoff.stopwatch.Elapsed.TotalSeconds * 1000f;
		}

		private void Update()
		{
			if (currentFrame != Time.frameCount) // FixedUpdate didn't run this frame, so reset the time
				elapsedTime = 0f;

			elapsedTime += (float)kickoff.stopwatch.Elapsed.TotalSeconds * 1000f;
		}

		private void LateUpdate()
		{
			elapsedTime += (float)kickoff.stopwatch.Elapsed.TotalSeconds * 1000f;
			elapsed400total += Time.deltaTime;
			frame400count ++;
			if( frame400count >= 400 )
			{
				lastframe400 = elapsed400total / .4f;
				frame400count = 0;
				elapsed400total = 0;
			}
			
			VRCPlayerApi owner = Networking.GetOwner(gameObject);
			string OwnerName = "{unknown}";
			if( Utilities.IsValid(owner) && owner.IsValid() )
				OwnerName = owner.displayName;
			timeText.text = $"Frame: {elapsedTime:F3}ms\nTotal:{lastframe400:F3}ms\n{OwnerName}";
		}
	}
}