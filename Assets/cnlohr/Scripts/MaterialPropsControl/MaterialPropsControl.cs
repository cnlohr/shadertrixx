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
		public GameObject TemplateToggle;

		private int NUM_ELEMS = 10;

		private Slider[] Sliders;
		private Toggle[] Toggles;
		private int NumSlidersOrToggles;
		private Text[] Texts;
		private int NumTexts;
		private float StartTime;
		private bool bStarted = false;

		Toggle SpawnToggle(string name, Vector2 location)
		{
			GameObject _ToggleGO = VRCInstantiate( TemplateToggle );
			_ToggleGO.SetActive(true);
			_ToggleGO.transform.SetParent(transform, false);
			_ToggleGO.transform.transform.GetChild(0).localPosition = location;

			Transform so = _ToggleGO.GetComponent<Transform>().Find("Toggle");
			Toggle t = so.GetComponent<Toggle>();

			MaterialPropsSlider sl = so.GetComponent<MaterialPropsSlider>();
			if( Utilities.IsValid( sl ) )
				sl.ToCall = gameObject;

			t.name = name;
			Toggles[NumSlidersOrToggles++] = t;

			return t;
		}


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
			Sliders[NumSlidersOrToggles++] = s;
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

/*
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
*/

		/*USEFUL:
		 *	t.transform.transform.localPosition
		 */
		#endregion

		void SpawnProp( string name, int line, float value, float min, float max, bool bSlider )
		{
			if( bSlider )
			{
				Slider s = SpawnSlider( name, new Vector2(140, line));
				Text t = SpawnText( name+"Text", new Vector2(-120, line-8));
				s.minValue = min;
				s.maxValue = max;
				s.value = value;
			}
			else
			{
				Toggle t = SpawnToggle( name, new Vector2(180, line-10 ));
				Text x = SpawnText( name+"Text", new Vector2(-120, line-8));
				t.isOn = value>0.5;
			}
		}

		void Start()
		{
			StartTime = Time.time;
			NUM_ELEMS = ParameterNames.Length;
			Sliders = new Slider[NUM_ELEMS];
			Toggles = new Toggle[NUM_ELEMS];
			Texts = new Text[NUM_ELEMS];

			int i;
			for( i = 0; i < NUM_ELEMS; i++ )
			{
				SpawnProp( ParameterNames[i], -i*30, ValueMinMax[i].x, ValueMinMax[i].y, ValueMinMax[i].z, (ValueMinMax[i].w<=1.5) );
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

			_InternalSlideUpdate( false );
			bStarted = true;
		}
		
		public override void OnDeserialization()
		{
			if( Global && Networking.GetOwner( gameObject ) != Networking.LocalPlayer )
			{
				int i;
				for (i = 0; i < NUM_ELEMS; i++)
				{
					if( i == 0 ) { if( ValueMinMax[i].w > 1.5 ) Toggles[i].isOn = v0>0.5; else Sliders[i].value = v0; }
					if( i == 1 ) { if( ValueMinMax[i].w > 1.5 ) Toggles[i].isOn = v1>0.5; else Sliders[i].value = v1; }
					if( i == 2 ) { if( ValueMinMax[i].w > 1.5 ) Toggles[i].isOn = v2>0.5; else Sliders[i].value = v2; }
					if( i == 3 ) { if( ValueMinMax[i].w > 1.5 ) Toggles[i].isOn = v3>0.5; else Sliders[i].value = v3; }
					if( i == 4 ) { if( ValueMinMax[i].w > 1.5 ) Toggles[i].isOn = v4>0.5; else Sliders[i].value = v4; }
					if( i == 5 ) { if( ValueMinMax[i].w > 1.5 ) Toggles[i].isOn = v5>0.5; else Sliders[i].value = v5; }
					if( i == 6 ) { if( ValueMinMax[i].w > 1.5 ) Toggles[i].isOn = v6>0.5; else Sliders[i].value = v6; }
					if( i == 7 ) { if( ValueMinMax[i].w > 1.5 ) Toggles[i].isOn = v7>0.5; else Sliders[i].value = v7; }
					if( i == 8 ) { if( ValueMinMax[i].w > 1.5 ) Toggles[i].isOn = v8>0.5; else Sliders[i].value = v8; }
					if( i == 9 ) { if( ValueMinMax[i].w > 1.5 ) Toggles[i].isOn = v9>0.5; else Sliders[i].value = v9; }
				}
				_InternalSlideUpdate( false );
			}
		}

		public void _InternalSlideUpdate( bool doSync )
		{
			int i;
			int m;
			int NUM_MATS = SetMaterials.Length;
			for (m = 0; m < NUM_MATS; m++ )
			for (i = 0; i < NUM_ELEMS; i++)
			{
				float value = 0;

				if( ValueMinMax[i].w > 1.5 )
				{
					if( !Toggles[i] ) break;

					value = Toggles[i].isOn?1:0;

					// .w == 2 -> enable/disable
					if( value > 0.5 )
					{
						SetMaterials[m].EnableKeyword(Toggles[i].name);
						SetMaterials[m].SetInt(Toggles[i].name, 1);
						Texts[i].text = Toggles[i].name + " Enabled";
					}
					else
					{
						SetMaterials[m].DisableKeyword(Toggles[i].name);
						SetMaterials[m].SetInt(Toggles[i].name, 0);
						Texts[i].text = Toggles[i].name + " Disabled";
					}
				}
				else if( ValueMinMax[i].w > 0.5 )
				{
					if (!Sliders[i]) break;
					// .w == 1 -> Integer
					value = Sliders[i].value;
					SetMaterials[m].SetInt( Sliders[i].name, (int)(value));
					Texts[i].text = string.Format( Sliders[i].name + ":{0:n0}", (int)value );
				}
				else
				{
					if (!Sliders[i]) break;
					value = Sliders[i].value;
					Texts[i].text = string.Format( Sliders[i].name + ":{0:n3}", value );
					SetMaterials[m].SetFloat( Sliders[i].name, value );
				}
				
				if( Global && doSync )
				{
					if( i == 0 ) { v0 = value; }
					if( i == 1 ) { v1 = value; }
					if( i == 2 ) { v2 = value; }
					if( i == 3 ) { v3 = value; }
					if( i == 4 ) { v4 = value; }
					if( i == 5 ) { v5 = value; }
					if( i == 6 ) { v6 = value; }
					if( i == 7 ) { v7 = value; }
					if( i == 8 ) { v8 = value; }
					if( i == 9 ) { v9 = value; }
				}
			}
		}

		public void _ValueUpdate()
		{
			_InternalSlideUpdate( StartTime + 5 < Time.time  );
			Debug.Log( StartTime + 5 < Time.time  );
			Debug.Log( "VALUE UPDATE\n" );
			// Don't allow settings to be changed for first 5 seconds of load, so we can get a sync from others.
			if( bStarted && Global )
			{
				Networking.SetOwner( Networking.LocalPlayer, gameObject );
				RequestSerialization();
			}
		}
	}
}
