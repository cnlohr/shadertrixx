#if UNITY_EDITOR
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

public class MakeFontBordered : EditorWindow
{
	public Font FontToConvert = null;
	
	
    [MenuItem("Tools/Make Font Bordered")]
    public static void ShowWindow()
    {
        EditorWindow window = EditorWindow.GetWindow(typeof(MakeFontBordered));
        window.maxSize = new Vector2(400, 200);
    }

    void OnGUI()
    {
        EditorGUILayout.LabelField("MakeFontBordered", EditorStyles.boldLabel);

        FontToConvert = (Font)EditorGUILayout.ObjectField("Font Asset:", FontToConvert, typeof(Font), false);

        //UseTextureCompression = EditorGUILayout.Toggle("Compress Font Atlas", UseTextureCompression);
        //if (UseTextureCompression)
        //{
         //   EditorGUILayout.HelpBox("Enabling compression can cause visible artifacts on text depending on the font. On most fonts the artifacts may make the text look wobbly along edges. Check to make sure artifacts do not appear when you enable this.", MessageType.Warning);
        //}

        EditorGUI.BeginDisabledGroup(FontToConvert == null);
        if (GUILayout.Button("Reimport Bordered Arial"))
        {
	        TrueTypeFontImporter fontImporter = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(FontToConvert)) as TrueTypeFontImporter;

			if (fontImporter == null)
				Debug.LogError("Could not import mesh asset! Builtin Unity fonts like Arial don't work unless you put them in the project directory!");

			fontImporter.characterSpacing = 4;
			fontImporter.characterPadding = 2;

			fontImporter.SaveAndReimport();

			Debug.Log( "Re-imported");
        }
        EditorGUI.EndDisabledGroup();
    }
}
#endif