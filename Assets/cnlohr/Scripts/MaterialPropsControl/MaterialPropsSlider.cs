
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

namespace MaterialPropsContainer
{
	public class MaterialPropsSlider : UdonSharpBehaviour
	{
		public GameObject ToCall;
		public void _ValueUpdate()
		{
			MaterialPropsControl mpc = (MaterialPropsControl)ToCall.GetComponent<MaterialPropsControl>();
			mpc._ValueUpdate();
		}
		void Start()
		{
			
		}
	}
}
