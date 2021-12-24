/**
 *                                                                      
 * MIT License
 * 
 * Copyright(c) 2019 Merlin
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#if UNITY_EDITOR

using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

public class MSDFAtlasGenerator : EditorWindow
{
    public Font FontToConvert = null;

    public Texture2D AtlasToSave = null;
    public bool UseTextureCompression = false;

    private const string MSDFGenPath = "Assets/Merlin/MSDF/bin/msdfgen.exe";
    private const string MSDFTempPath = "Assets/Merlin/MSDF/gen/glyph{0}.png";

    [MenuItem("Window/Merlin/MSDF Font Generator")]
    public static void ShowWindow()
    {
        EditorWindow window = EditorWindow.GetWindow(typeof(MSDFAtlasGenerator));
        window.maxSize = new Vector2(400, 200);
    }

    void OnGUI()
    {
        EditorGUILayout.LabelField("MSDF Atlas Generator", EditorStyles.boldLabel);

        FontToConvert = (Font)EditorGUILayout.ObjectField("Font Asset:", FontToConvert, typeof(Font), false);

        UseTextureCompression = EditorGUILayout.Toggle("Compress Font Atlas", UseTextureCompression);

        if (UseTextureCompression)
        {
            EditorGUILayout.HelpBox("Enabling compression can cause visible artifacts on text depending on the font. On most fonts the artifacts may make the text look wobbly along edges. Check to make sure artifacts do not appear when you enable this.", MessageType.Warning);
        }

        EditorGUI.BeginDisabledGroup(FontToConvert == null);
        if (GUILayout.Button("Generate Atlas"))
        {
            GenerateAtlas();
        }
        EditorGUI.EndDisabledGroup();

       // AtlasToSave = (Texture2D)EditorGUILayout.ObjectField("Texture to save:", AtlasToSave, typeof(Texture2D), false);
       // if (GUILayout.Button("Save Atlas to PNG"))
       // {
       //     SaveToPNG();
       // }
    }

    private void SaveToPNG()
    {
        string assetPath = AssetDatabase.GetAssetPath(AtlasToSave).Replace(".asset", ".png");

        File.WriteAllBytes(assetPath, ImageConversion.EncodeToPNG(AtlasToSave));
    }

    private void GenerateAtlas()
    {
        TrueTypeFontImporter fontImporter = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(FontToConvert)) as TrueTypeFontImporter;

        if (fontImporter == null)
            Debug.LogError("Could not import mesh asset! Builtin Unity fonts like Arial don't work unless you put them in the project directory!");

        fontImporter.characterSpacing = 4;
        fontImporter.characterPadding = 2;

        fontImporter.SaveAndReimport();

        // Hacky method to get the generated font texture so that we can figure out where to put pixels
        Texture2D fontTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(AssetDatabase.GetAssetPath(FontToConvert));

        Dictionary<CharacterInfo, Texture2D> characterGlyphMap = new Dictionary<CharacterInfo, Texture2D>();

        CharacterInfo[] characterInfos = FontToConvert.characterInfo;

        Texture2D newAtlas = new Texture2D(fontTexture.width, fontTexture.height, TextureFormat.ARGB32, false, true);
        for (int x = 0; x < newAtlas.width; ++x)
        {
            for (int y = 0; y < newAtlas.height; ++y)
            {
                newAtlas.SetPixel(x, y, Color.black);
            }
        }

        int charCount = 0;

        foreach (CharacterInfo info in characterInfos)
        {
            charCount++;

            EditorUtility.DisplayProgressBar("Generating MSDF Atlas...", string.Format("Glyph {0}/{1}", charCount, characterInfos.Length), charCount / (float)characterInfos.Length);

            Texture2D currentGlyphTex = GenerateGlyphTexture(info.index, info.glyphWidth, info.glyphHeight);

            if (currentGlyphTex == null)
                continue;

            for (int x = 0; x < currentGlyphTex.width; ++x)
            {
                for (int y = 0; y < currentGlyphTex.height; ++y)
                {
                    float progressX = (x) / (float)(currentGlyphTex.width);
                    float progressY = (y) / (float)(currentGlyphTex.height);

                    float uvProgressX = Mathf.Lerp(info.uvTopLeft.x, info.uvTopRight.x, progressX) * fontTexture.width;
                    float uvProgressY = Mathf.Lerp(info.uvBottomLeft.y, info.uvTopLeft.y, progressY) * fontTexture.height;

                    // flipped iS dEpRiCaTeD uSiNg ThE Uv WiLl bE CoNSiStEnT. It's not consistent in my limited experience.
                    // Maybe I'm doing something wrong, but I don't want to try fighting with Unity trying to fix an issue that may be on their end.. I've wasted enough time on trusting Unity to do things correctly.
#pragma warning disable 0618
                    if (info.flipped)
#pragma warning restore 0618
                    {
                        uvProgressY = Mathf.Lerp(info.uvTopLeft.y, info.uvTopRight.y, progressX) * fontTexture.height;
                        uvProgressX = Mathf.Lerp(info.uvBottomLeft.x, info.uvTopLeft.x, progressY) * fontTexture.width;
                    }


                    int targetX = Mathf.RoundToInt(uvProgressX);
                    int targetY = Mathf.RoundToInt(uvProgressY) - 1;

                    Color glyphCol = currentGlyphTex.GetPixel(x, y);

                    newAtlas.SetPixel(targetX, targetY, glyphCol/2.0f+new Color(.25f,.25f,.25f,.25f));
                }
            }

        }

        newAtlas.Apply(false);

        if (UseTextureCompression)
        {
            EditorUtility.DisplayProgressBar("Generating MSDF Atlas...", "Compressing Atlas...", 1f);
            EditorUtility.CompressTexture(newAtlas, TextureFormat.BC7, UnityEditor.TextureCompressionQuality.Best);
        }

        EditorUtility.ClearProgressBar();

        string fontPath = AssetDatabase.GetAssetPath(FontToConvert);
        string savePath = Path.Combine(Path.GetDirectoryName(fontPath), Path.GetFileNameWithoutExtension(fontPath) + "_msdfAtlas.asset");

        AssetDatabase.CreateAsset(newAtlas, savePath);

        EditorGUIUtility.PingObject(newAtlas);

        string savePathPng = Path.Combine(Path.GetDirectoryName(fontPath), Path.GetFileNameWithoutExtension(fontPath) + "_msdfAtlas.png");
		byte[] _bytes = newAtlas.EncodeToPNG();
        System.IO.File.WriteAllBytes(savePathPng, _bytes);
    }

    private Texture2D GenerateGlyphTexture(int UTFChar, int glyphWidth, int glyphHeight)
    {
        System.Diagnostics.Process msdfProcess = new System.Diagnostics.Process();

        msdfProcess.StartInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
        msdfProcess.StartInfo.CreateNoWindow = true;
        msdfProcess.StartInfo.UseShellExecute = false;
        msdfProcess.StartInfo.FileName = Path.GetFullPath(MSDFGenPath);
        msdfProcess.EnableRaisingEvents = true;

        string fontPath = Path.GetFullPath(AssetDatabase.GetAssetPath(FontToConvert));
        //string glyphLocalPath = string.Format(MSDFTempPath, UTFChar);
        string glyphLocalPath = string.Format(MSDFTempPath, 0);
        string glyphPath = Path.GetFullPath(glyphLocalPath);

        Directory.CreateDirectory(Path.GetDirectoryName(string.Format(MSDFTempPath, 0)));
        string argStr = string.Format("msdf -o \"{0}\" -font \"{1}\" {4} -size {2} {3} -pxrange 4 -autoframe", glyphPath, fontPath, glyphWidth, glyphHeight, UTFChar);

        msdfProcess.StartInfo.Arguments = argStr;

        msdfProcess.Start();
        msdfProcess.WaitForExit();

        if (!File.Exists(glyphLocalPath))
        {
            Debug.LogWarning("Could not load glyph " + UTFChar);
            return null;
        }

        Texture2D loadedGlyph = new Texture2D(glyphWidth, glyphHeight);
        ImageConversion.LoadImage(loadedGlyph, File.ReadAllBytes(glyphLocalPath), false);

        return loadedGlyph;

#if false // Old import code that bounces through the Asset Database so it's much slower.
        AssetDatabase.ImportAsset(glyphLocalPath);

        TextureImporter glyphImporter = AssetImporter.GetAtPath(glyphLocalPath) as TextureImporter;

        if (glyphImporter != null)
        {
            glyphImporter.npotScale = TextureImporterNPOTScale.None;
            glyphImporter.sRGBTexture = false;
            glyphImporter.mipmapEnabled = false;
            glyphImporter.textureCompression = TextureImporterCompression.Uncompressed;
            glyphImporter.isReadable = true;

            glyphImporter.SaveAndReimport();
        }
        else
        {
            Debug.LogWarning("Failed to import glyph " + glyphPath);
        }

        return AssetDatabase.LoadAssetAtPath<Texture2D>(glyphLocalPath);
#endif
    }
}

#endif

