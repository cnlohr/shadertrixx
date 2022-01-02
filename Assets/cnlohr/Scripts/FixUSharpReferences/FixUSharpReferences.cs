#if !COMPILER_UDONSHARP
#if UNITY_EDITOR

using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.IO;
using System.Linq;
using System.Reflection;
using UdonSharp.Compiler;
using UdonSharpEditor;
using UnityEditor;
using UnityEngine;
using VRC.Udon;
using UdonSharp;
using VRC.Udon.Common.Interfaces;
using VRC.Udon.Editor.ProgramSources;
using VRC.Udon.Editor.ProgramSources.Attributes;
using VRC.Udon.EditorBindings;
using VRC.Udon.ProgramSources;
using VRC.Udon.Serialization.OdinSerializer;
using UnityEngine.SceneManagement;

// This is a truncated version of https://github.com/MerlinVR/UdonSharp/pull/113
// This needs testing.


namespace UdonSharpEditor
{
	public class FixUSharpReferences : EditorWindow
	{
		[MenuItem("Window/Udon Sharp/Refresh All UdonSharp Assets")]
		static public void UdonSharpCheckAbsent()
		{
			Debug.Log( "Checking Absent" );

			int cycles = -1;
			int lastNumAssets;
			int currentNumAssets;
			string[] udonSharpDataAssets;

			// Loop until we stop picking up assets.
			do
			{
				udonSharpDataAssets = AssetDatabase.FindAssets($"t:{nameof(UdonSharpProgramAsset)}");
				lastNumAssets = udonSharpDataAssets.Length;
				string[] udonSharpNames = new string[udonSharpDataAssets.Length];

				Debug.Log( $"Found {udonSharpDataAssets.Length} assets." );

				for (int i = 0; i < udonSharpDataAssets.Length; ++i)
				{
					udonSharpDataAssets[i] = AssetDatabase.GUIDToAssetPath(udonSharpDataAssets[i]);
				}

				foreach(string s in AssetDatabase.GetAllAssetPaths() )
				{
					if(!udonSharpDataAssets.Contains(s))
					{
						Type t = AssetDatabase.GetMainAssetTypeAtPath(s);
						if (t != null && t.FullName == "UdonSharp.UdonSharpProgramAsset")
						{
							Debug.Log( $"Trying to recover {s}" );
							Selection.activeObject = AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(s);
						}
					}
				}

				//UdonSharpProgramAssetPostprocessor.OnPostprocessAllAssets( new string[0], new string[0], new string[0], new string[0] );
				Debug.Log( typeof(UdonSharpProgramAsset).GetMethod("ClearProgramAssetCache", BindingFlags.NonPublic | BindingFlags.Static) );
				typeof(UdonSharpProgramAsset).GetMethod("ClearProgramAssetCache", BindingFlags.NonPublic | BindingFlags.Static).Invoke(null, Array.Empty<object>());
				//UdonSharpProgramAsset.ClearProgramAssetCache();
				UdonSharpProgramAsset.GetAllUdonSharpPrograms();
//#endif
				currentNumAssets = AssetDatabase.FindAssets($"t:{nameof(UdonSharpProgramAsset)}").Length;
				Debug.Log( $"Checking to see if we need to re-run. Last: {lastNumAssets}, This: {currentNumAssets}" );
				cycles++;
			} while( lastNumAssets != currentNumAssets );

			Debug.Log( $"Completed {cycles} refresh cycles, found {lastNumAssets} assets." );
			Debug.LogWarning( "Please note this is untested. Please tell CNLohr if this does/doesn't work for you." );
			
			// From EsynaTools
			var brokenUdons = SceneManager.GetActiveScene().GetRootGameObjects().SelectMany(o => o.GetComponentsInChildren<UdonBehaviour>(true)).Where(u => u.programSource == null);
			foreach (var brokenUdon in brokenUdons)
			{
				var broke = brokenUdon as UdonBehaviour;
				var go = broke.gameObject;
				var parentObject = PrefabUtility.GetCorrespondingObjectFromSource(go);
				if( parentObject )
				{
					string path = AssetDatabase.GetAssetPath(parentObject);
					Debug.Log($"Refreshing prefab on object {go} still missing in prefab {path}", parentObject );
					AssetDatabase.ImportAsset( path );
				}
			}


			// From EsynaTools
			brokenUdons = SceneManager.GetActiveScene().GetRootGameObjects().SelectMany(o => o.GetComponentsInChildren<UdonBehaviour>(true)).Where(u => u.programSource == null);
			foreach (var brokenUdon in brokenUdons)
			{
				var broke = brokenUdon as UdonBehaviour;
				var go = broke.gameObject;
				var parentObject = PrefabUtility.GetCorrespondingObjectFromSource(go);
				if( parentObject )
				{
					string path = AssetDatabase.GetAssetPath(parentObject);
					Debug.LogError($"Reference on object {go} still missing in prefab {path} try re-importing the package?", go );
				}
				else
				{
					Debug.LogError($"Reference on object {go} still missing (not part of prefab)", go );
				}
			}
		}
	}
}
#endif
#endif