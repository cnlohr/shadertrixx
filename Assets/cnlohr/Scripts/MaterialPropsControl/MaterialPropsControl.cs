using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using UnityEngine.UI;

/* Checklist
	 * Attach this script to a canvas.
     * Text in an empty
	 * Slider in an empty, Add OnValueChange to <this> Canvas, SendCustomEvent "SlideUpdate"
	 * Add Ui shape to canvas
	 * Put Canvas on Default
	 * Add reference camera to UI Camera.
	 * Attach reference slider and text to this script.
*/

namespace MaterialPropsContainer
{
	[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
	public class MaterialPropsControl : UdonSharpBehaviour
	{
		
		
		public string [] ParameterNames;
		public Vector4 [] ValueMinMax;
		public Material [] SetMaterials;

		public bool Global;
		
		[UdonSynced] float v0;
		[UdonSynced] float v1;
		[UdonSynced] float v2;
		[UdonSynced] float v3;
		[UdonSynced] float v4;
		[UdonSynced] float v5;
		[UdonSynced] float v6;
		[UdonSynced] float v7;
		[UdonSynced] float v8;
		[UdonSynced] float v9;

		#region SlidersAndText
		public GameObject TemplateSlider;
		public GameObject TemplateText;

		private int NUM_ELEMS = 10;

		private Slider[] Sliders;
		private int NumSliders;
		private Text[] Texts;
		private int NumTexts;
		private float StartTime;
		private bool bStarted = false;

		Slider SpawnSlider(string name, Vector2 location)
		{
			GameObject _SliderGO = VRCInstantiate(TemplateSlider);
			_SliderGO.SetActive(true);
			_SliderGO.transform.SetParent(transform, false);
			_SliderGO.transform.transform.GetChild(0).localPosition = location;
			
			Transform so = _SliderGO.GetComponent<Transform>().Find("Slider");
			Slider s = so.GetComponent<Slider>();

			MaterialPropsSlider sl = so.GetComponent<MaterialPropsSlider>();
			if( Utilities.IsValid( sl ) )
				sl.ToCall = gameObject;

			s.name = name;
			Sliders[NumSliders++] = s;
			return s;
		}

		Text SpawnText(string name, Vector2 location)
		{
			GameObject GO = VRCInstantiate(TemplateText);
			GO.SetActive(true);
			GO.transform.SetParent(transform, false);
			GO.transform.transform.GetChild(0).localPosition = location;
			Text t = GO.GetComponent<Transform>().Find("Text").GetComponent<Text>();
			t.name = name;
			Texts[NumTexts++] = t;
			return t;
		}

		Text GetTextByName(string name)
		{
			int i;
			for (i = 0; i < NUM_ELEMS; i++)
			{
				if (!Texts[i]) break;
				if ( Texts[i].name == name) return Texts[i];
			}
			return null;
		}

		Slider GetSliderByName(string name)
		{
			int i;
			for (i = 0; i < NUM_ELEMS; i++)
			{
				if (!Sliders[i]) break;
				if ( Sliders[i].name == name) return Sliders[i];
			}
			return null;
		}

		/*USEFUL:
		 *	t.transform.transform.localPosition
		 */
		#endregion

		void SpawnProp( string name, int line, float value, float min, float max )
		{
			Slider s = SpawnSlider( name, new Vector2(140, line));
			Text t = SpawnText( name+"Text", new Vector2(-120, line-8));
			s.minValue = min;
			s.maxValue = max;
			s.value = value;
		}

		void Start()
		{
			StartTime = Time.time;
			NUM_ELEMS = ParameterNames.Length;
			Sliders = new Slider[NUM_ELEMS];
			Texts = new Text[NUM_ELEMS];
			int i;
			for( i = 0; i < NUM_ELEMS; i++ )
			{
				SpawnProp(ParameterNames[i], -i*30, ValueMinMax[i].x, ValueMinMax[i].y, ValueMinMax[i].z);			
			}
			if( Networking.IsMaster )
			{
				for (i = 0; i < NUM_ELEMS; i++)
				{
					if( i == 0 ) { v0 = ValueMinMax[0].x; }
					if( i == 1 ) { v1 = ValueMinMax[1].x; }
					if( i == 2 ) { v2 = ValueMinMax[2].x; }
					if( i == 3 ) { v3 = ValueMinMax[3].x; }
					if( i == 4 ) { v4 = ValueMinMax[4].x; }
					if( i == 5 ) { v5 = ValueMinMax[5].x; }
					if( i == 6 ) { v6 = ValueMinMax[6].x; }
					if( i == 7 ) { v7 = ValueMinMax[7].x; }
					if( i == 8 ) { v8 = ValueMinMax[8].x; }
					if( i == 9 ) { v9 = ValueMinMax[9].x; }
				}
				Networking.SetOwner( Networking.LocalPlayer, gameObject );
				RequestSerialization();
			}
			_InternalSlideUpdate();
			bStarted = true;
		}
		
		public override void OnDeserialization()
		{
			if( Global && Networking.GetOwner( gameObject ) != Networking.LocalPlayer )
			{
				int i;
				for (i = 0; i < NUM_ELEMS; i++)
				{
					if( i == 0 ) { Sliders[i].value = v0; }
					if( i == 1 ) { Sliders[i].value = v1; }
					if( i == 2 ) { Sliders[i].value = v2; }
					if( i == 3 ) { Sliders[i].value = v3; }
					if( i == 4 ) { Sliders[i].value = v4; }
					if( i == 5 ) { Sliders[i].value = v5; }
					if( i == 6 ) { Sliders[i].value = v6; }
					if( i == 7 ) { Sliders[i].value = v7; }
					if( i == 8 ) { Sliders[i].value = v8; }
					if( i == 9 ) { Sliders[i].value = v9; }
				}
				_InternalSlideUpdate();
			}
		}

		public void _InternalSlideUpdate()
		{
			int i;
			for (i = 0; i < NUM_ELEMS; i++)
			{
				if (!Sliders[i]) break;
				if( ValueMinMax[i].w > 1.5 )
				{
					if( Sliders[i].value > 0.5 )
					{
						SetMaterials[i].EnableKeyword(Sliders[i].name);
						SetMaterials[i].SetInt(Sliders[i].name, 1);
						Texts[i].text = Sliders[i].name + " Enable";
					}
					else
					{
						SetMaterials[i].DisableKeyword(Sliders[i].name);
						SetMaterials[i].SetInt(Sliders[i].name, 0);
						Texts[i].text = Sliders[i].name + " Disable";
					}
				}
				else if( ValueMinMax[i].w > 0.5 )
				{
					SetMaterials[i].SetInt(Sliders[i].name, (int)(Sliders[i].value));
					Texts[i].text = string.Format(Sliders[i].name + ":{0:n0}", Sliders[i].value);
				}
				else
				{
					Texts[i].text = string.Format(Sliders[i].name + ":{0:n3}", Sliders[i].value);
					SetMaterials[i].SetFloat(Sliders[i].name, Sliders[i].value);
				}
				if( Global )
				{
					if( i == 0 ) { v0 = Sliders[i].value; }
					if( i == 1 ) { v1 = Sliders[i].value; }
					if( i == 2 ) { v2 = Sliders[i].value; }
					if( i == 3 ) { v3 = Sliders[i].value; }
					if( i == 4 ) { v4 = Sliders[i].value; }
					if( i == 5 ) { v5 = Sliders[i].value; }
					if( i == 6 ) { v6 = Sliders[i].value; }
					if( i == 7 ) { v7 = Sliders[i].value; }
					if( i == 8 ) { v8 = Sliders[i].value; }
					if( i == 9 ) { v9 = Sliders[i].value; }
				}
			}
		}

		public void _SlideUpdate()
		{
			_InternalSlideUpdate();
			// Don't allow settings to be changed for first 5 seconds of load, so we can get a sync from others.
			if( bStarted && Global && StartTime + 5 < Time.time )
			{
				Networking.SetOwner( Networking.LocalPlayer, gameObject );
				RequestSerialization();
			}
		}
	}
}
