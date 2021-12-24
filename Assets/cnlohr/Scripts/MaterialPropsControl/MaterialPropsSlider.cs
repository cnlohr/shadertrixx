
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

namespace MaterialPropsContainer
{
	public class MaterialPropsSlider : UdonSharpBehaviour
	{
		public GameObject ToCall;
		public void _SlideUpdate()
		{
			MaterialPropsControl mpc = (MaterialPropsControl)ToCall.GetComponent<MaterialPropsControl>();
			mpc._SlideUpdate();
		}
		void Start()
		{
			
		}
	}
}
