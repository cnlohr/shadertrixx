
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using UnityEngine.UI;

public class depthcontrol : UdonSharpBehaviour
{
    public Slider _slideZDeflection;
    public Text _textZDeflection;
    public Slider _slideSteps;
    public Text _textSteps;
    public Slider _slideSearch;
    public Text _textSearch;
    public Slider _slideStrength;
    public Text _textStrength;
    public Slider _slideOffset;
    public Text _textOffset;
    public Slider _slideDepthMux;
    public Text _textDepthMux;
    public Slider _slideDepthShift;
    public Text _textDepthShift;


    public Material mat1;

    void Start()
    {
    }

    public void Update()
    {
		float fSlide;
        fSlide = _slideZDeflection.value;		mat1.SetFloat("_ZDeflection", fSlide);					_textZDeflection.text = string.Format("ZDeflection: {0:n2}", fSlide);
        fSlide = _slideSteps.value;				mat1.SetFloat("_ParallaxRaymarchingSteps", fSlide);		_textSteps.text = string.Format("Steps: {0:n2}", fSlide);
        fSlide = _slideSearch.value;			mat1.SetFloat("_ParallaxRaymarchingSearch", fSlide);	_textSearch.text = string.Format("Search: {0:n2}", fSlide);
        fSlide = _slideStrength.value;			mat1.SetFloat("_ParallaxStrength", fSlide);				_textStrength.text = string.Format("Strength: {0:n2}", fSlide);
        fSlide = _slideOffset.value;			mat1.SetFloat("_ParallaxOffset", fSlide);				_textOffset.text = string.Format("Offset: {0:n2}", fSlide);

        fSlide = _slideDepthMux.value;			mat1.SetFloat("_DepthMux", fSlide);						_textDepthMux.text = string.Format("Depth Mux: {0:n2}", fSlide);
        fSlide = _slideDepthShift.value;		mat1.SetFloat("_DepthShift", fSlide);					_textDepthShift.text = string.Format("Depth Shift: {0:n2}", fSlide);
    }
}
