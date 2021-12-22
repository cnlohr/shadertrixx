#if UNITY_EDITOR

#region

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.Rendering;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;
using VRC.SDKBase.Editor.BuildPipeline;
using Object = UnityEngine.Object;

#endregion

// thank you Scruffy, z3y and TCL
// ah I'm not happy with this script it's gotten way to overengineered I think
// Welp this should take care of most false positive strips hopefully

// ReSharper disable once CheckNamespace
namespace _3.ShaderPreProcessor
{
	#if VRC_SDK_VRCSDK2 || VRC_SDK_VRCSDK3
	public class OnBuildRequest : IVRCSDKBuildRequestedCallback
	{
		public static VRCSDKRequestedBuildType RequestedBuildTypeCallback;
		public int callbackOrder => 6;


		public bool OnBuildRequested(VRCSDKRequestedBuildType requestedBuildType)
		{
			if (requestedBuildType == VRCSDKRequestedBuildType.Avatar)
			{
				RequestedBuildTypeCallback = requestedBuildType;
			}

			else if (requestedBuildType == VRCSDKRequestedBuildType.Scene)
			{
				RequestedBuildTypeCallback = requestedBuildType;

				Scene scene = SceneManager.GetActiveScene();

				string[] shaderpaths = AssetDatabase.GetDependencies(scene.path).Where(x => x.EndsWith(".shader"))
					.ToArray();

				PreprocessShaders.ExcludedShaders.Clear();

				foreach (string shaderpath in shaderpaths)
				{
					if (shaderpath.Contains("Reflect-BumpVertexLit.shader"))
					{
						string[] excludedShaderPass = new string[3];

						excludedShaderPass[0] = "Reflective/Bumped Unlit";
						excludedShaderPass[1] = "BASE";
						excludedShaderPass[2] = "Legacy Shaders/Reflective/Bumped VertexLit";
					}

					if (shaderpath.Contains("unity_builtin_extra"))
					{
						continue;
					}

					string[] shader = File.ReadAllLines(shaderpath);

					foreach (string line in new CommentFreeIterator(shader))
					{
						if (line.Contains("UsePass"))
						{
							string shadernameRegex = "(?<=\\\")(.*)(?=\\/)";
							string passnameRegex = "(?<=\\/)([^\\/]*?)(?=\")";

							string[] excludedShaderPass = new string[3];

							excludedShaderPass[0] = Regex.Match(line, shadernameRegex).Value;
							excludedShaderPass[1] = Regex.Match(line, passnameRegex).Value;
							excludedShaderPass[2] = AssetDatabase.LoadAssetAtPath<Shader>(shaderpath).name;

							PreprocessShaders.ExcludedShaders.Add(excludedShaderPass);
						}
					}
				}
			}

			return true;
		}
	}

	public class OnAvatarBuild : IVRCSDKPreprocessAvatarCallback
	{
		public int callbackOrder => 3;

		public bool OnPreprocessAvatar(GameObject avatarGameObject)
		{
			Renderer[] renderers = avatarGameObject.GetComponentsInChildren<Renderer>(true);

			PreprocessShaders.ExcludedShaders.Clear();

			foreach (Renderer renderer in renderers)
			{
				foreach (Material material in renderer.sharedMaterials)
				{
					if (material.shader.name == "Legacy Shaders/Reflective/Bumped VertexLit")
					{
						string[] excludedShaderPass = new string[3];

						excludedShaderPass[0] = "Reflective/Bumped Unlit";
						excludedShaderPass[1] = "BASE";
						excludedShaderPass[2] = "Legacy Shaders/Reflective/Bumped VertexLit";
					}

					if (AssetDatabase.GetAssetPath(material.shader).Contains("unity_builtin_extra"))
					{
						continue;
					}

					string[] shader = File.ReadAllLines(AssetDatabase.GetAssetPath(material.shader));

					foreach (string line in new CommentFreeIterator(shader))
					{
						if (line.Contains("UsePass"))
						{
							string shadernameRegex = "(?<=\")(.*)(?=\\/)";
							string passnameRegex = "(?<=\\/)([^\\/]*?)(?=\")";

							string[] excludedShaderPass = new string[3];

							excludedShaderPass[0] = Regex.Match(line, shadernameRegex).Value;
							excludedShaderPass[1] = Regex.Match(line, passnameRegex).Value;
							excludedShaderPass[2] = material.shader.name;

							PreprocessShaders.ExcludedShaders.Add(excludedShaderPass);
						}
					}
				}
			}

			return true;
		}
	}

	#else
	class OnBuild : IPreprocessBuildWithReport
	{
		public int callbackOrder => 3;

		public void OnPreprocessBuild(BuildReport report)
		{
			Scene scene = SceneManager.GetActiveScene();

			string[] shaderpaths = AssetDatabase.GetDependencies(scene.path).Where(x => x.EndsWith(".shader"))
				.ToArray();

			PreprocessShaders.ExcludedShaders.Clear();

			foreach (string shaderpath in shaderpaths)
			{
				if (shaderpath.Contains("Reflect-BumpVertexLit.shader"))
				{
					string[] excludedShaderPass = new string[3];

					excludedShaderPass[0] = "Reflective/Bumped Unlit";
					excludedShaderPass[1] = "BASE";
					excludedShaderPass[2] = "Legacy Shaders/Reflective/Bumped VertexLit";
				}

				if (shaderpath.Contains("unity_builtin_extra"))
				{
					continue;
				}

				string[] shader = File.ReadAllLines(shaderpath);

				foreach (string line in new CommentFreeIterator(shader))
				{
					if (line.Contains("UsePass"))
					{
						string shadernameRegex = "(?<=\\\")(.*)(?=\\/)";
						string passnameRegex = "(?<=\\/)([^\\/]*?)(?=\")";

						string[] excludedShaderPass = new string[3];

						excludedShaderPass[0] = Regex.Match(line, shadernameRegex).Value;
						excludedShaderPass[1] = Regex.Match(line, passnameRegex).Value;
						excludedShaderPass[2] = AssetDatabase.LoadAssetAtPath<Shader>(shaderpath).name;

						PreprocessShaders.ExcludedShaders.Add(excludedShaderPass);
					}
				}
			}
		}
	}

	#endif

	public class PreprocessShaders : IPreprocessShaders
	{
		public static List<string[]> ExcludedShaders = new List<string[]>();

		private readonly List<PassType> _passesToStrip = new List<PassType>();

		public int callbackOrder => 9;


		public void OnProcessShader(Shader shader, ShaderSnippetData snippet, IList<ShaderCompilerData> data)
		{
			#if VRC_SDK_VRCSDK2 || VRC_SDK_VRCSDK3


			//Strip Post Processing
			string shaderName = shader.name;
			shaderName = string.IsNullOrEmpty(shaderName) ? "Empty" : shaderName;
			if (shaderName.Contains("Hidden/PostProcessing"))
			{
				data.Clear();
				return;
			}

			//this is a precaution since this audiolink shader might soon use a Vertex Pass
			//so I want to make sure to never strip this shader
			//but this shouldn't happen since the AudioLink camera should be then also be set to Vertex
			if (shaderName.Contains("AudioLink/Internal/AudioTextureExport"))
			{
				return;
			}


			//VRC is BIRP, Forward shading so strip SRP passes
			//Deferred is kept if the scene has any cameras using deferred rendering
			Camera[] cameras = Object.FindObjectsOfType<Camera>();

			if (cameras.All(camera => camera.actualRenderingPath != RenderingPath.DeferredLighting))
			{
				_passesToStrip.Add(PassType.LightPrePassBase);
				_passesToStrip.Add(PassType.LightPrePassFinal);
			}
			else
			{
				_passesToStrip.Remove(PassType.LightPrePassBase);
				_passesToStrip.Remove(PassType.LightPrePassFinal);
			}

			if (cameras.All(camera => camera.actualRenderingPath != RenderingPath.DeferredShading))
			{
				_passesToStrip.Add(PassType.Deferred);
			}
			else
			{
				_passesToStrip.Remove(PassType.Deferred);
			}

			if (cameras.All(camera => camera.actualRenderingPath != RenderingPath.VertexLit))
			{
				_passesToStrip.Add(PassType.Vertex);
				_passesToStrip.Add(PassType.VertexLM);
			}
			else
			{
				_passesToStrip.Remove(PassType.Vertex);
				_passesToStrip.Remove(PassType.VertexLM);
			}

			_passesToStrip.Add(PassType.ScriptableRenderPipeline);
			_passesToStrip.Add(PassType.ScriptableRenderPipelineDefaultUnlit);

			//META Pass is only used in Editor, for lightmapping, and for realtimeGI from my understanding so strip if it's a Scene with rtGI enabled 
			if (OnBuildRequest.RequestedBuildTypeCallback == VRCSDKRequestedBuildType.Avatar ||
			    !Lightmapping.realtimeGI)
			{
				_passesToStrip.Add(PassType.Meta);
			}

			#else
			//from my understanding they can be used even if the RenderingPath is not Vertex
			BuildTargetGroup buildTargetGroup =
				BuildPipeline.GetBuildTargetGroup(EditorUserBuildSettings.activeBuildTarget);


			TierSettings tierSettings = EditorGraphicsSettings.GetTierSettings(buildTargetGroup, GraphicsTier.Tier3);

			RenderingPath renderingPath = tierSettings.renderingPath;

			//Strip passes incompatible with the current rendering path
			if (renderingPath == RenderingPath.Forward)
			{
				_passesToStrip.Add(PassType.Deferred);

				_passesToStrip.Add(PassType.LightPrePassFinal);
				_passesToStrip.Add(PassType.LightPrePassBase);
			}
			else if (renderingPath == RenderingPath.DeferredLighting)
			{
				_passesToStrip.Add(PassType.Deferred);

				_passesToStrip.Add(PassType.ForwardBase);
				_passesToStrip.Add(PassType.ForwardAdd);
			}
			else if (renderingPath == RenderingPath.DeferredShading)
			{
				_passesToStrip.Add(PassType.LightPrePassFinal);
				_passesToStrip.Add(PassType.LightPrePassBase);

				_passesToStrip.Add(PassType.ForwardBase);
				_passesToStrip.Add(PassType.ForwardAdd);
			}

			//Strip passes incompatible with the current renderPipeLine
			if (GraphicsSettings.renderPipelineAsset != null)
			{
				string renderPipelineName = GraphicsSettings.renderPipelineAsset.ToString();
				if (renderPipelineName.Contains("Custom"))
				{
					//
				}
				else if (string.IsNullOrEmpty(renderPipelineName) || renderPipelineName.Contains("HDRenderPipeline") ||
				         renderPipelineName.Contains("LightWeight") || renderPipelineName.Contains("Universal"))
				{
					_passesToStrip.Add(PassType.ScriptableRenderPipeline);
					_passesToStrip.Add(PassType.ScriptableRenderPipelineDefaultUnlit);
				}
			}
			else
			{
				_passesToStrip.Add(PassType.ScriptableRenderPipeline);
				_passesToStrip.Add(PassType.ScriptableRenderPipelineDefaultUnlit);
			}

			//Strip meta pass if rtGI isn't used
			if (!Lightmapping.realtimeGI)
			{
				_passesToStrip.Add(PassType.Meta);
			}

			if (cameras.All(camera => camera.actualRenderingPath != RenderingPath.DeferredLighting))
			{
				_passesToStrip.Add(PassType.LightPrePassBase);
				_passesToStrip.Add(PassType.LightPrePassFinal);
			}
			else
			{
				_passesToStrip.Remove(PassType.LightPrePassBase);
				_passesToStrip.Remove(PassType.LightPrePassFinal);
			}

			if (cameras.All(camera => camera.actualRenderingPath != RenderingPath.DeferredShading))
			{
				_passesToStrip.Add(PassType.Deferred);
			}
			else
			{
				_passesToStrip.Remove(PassType.Deferred);
			}

			if (cameras.All(camera => camera.actualRenderingPath != RenderingPath.VertexLit))
			{
				_passesToStrip.Add(PassType.Vertex);
				_passesToStrip.Add(PassType.VertexLM);
			}
			else
			{
				_passesToStrip.Remove(PassType.Vertex);
				_passesToStrip.Remove(PassType.VertexLM);
			}


			#endif

			//If Unity does not find a matching Pass for the UsePass ShaderLab command, it shows the error material. https://docs.unity3d.com/Manual/SL-UsePass.html
			foreach (string[] excludedShader in ExcludedShaders)
			{
				if (excludedShader[0] == shader.name && excludedShader[1] == snippet.passName)
				{
					Debug.Log(
						$"Pass: {snippet.passName} in Shader: {shader.name} was included because {excludedShader[2]} uses it in a UsePass");
					return;
				}
			}

			if (_passesToStrip.Contains(snippet.passType))
			{
				data.Clear();
			}
		}
	}

	public class CommentFreeIterator : IEnumerable<string>
	{
		private readonly IEnumerable<string> _sourceLines;

		public CommentFreeIterator(IEnumerable<string> sourceLines)
		{
			_sourceLines = sourceLines;
		}

		public IEnumerator<string> GetEnumerator()
		{
			int comment = 0;
			foreach (string xline in _sourceLines)
			{
				string line = ParserRemoveComments(xline, ref comment);
				yield return line;
			}
		}

		IEnumerator IEnumerable.GetEnumerator()
		{
			return GetEnumerator();
		}

		public static string ParserRemoveComments(string line, ref int comment)
		{
			int lineSkip = 0;
			bool cisOpenQuote = false;


			while (true)
			{
				//Debug.Log ("Looking for comment " + lineNum);
				int openQuote = line.IndexOf("\"", lineSkip, StringComparison.CurrentCulture);
				if (cisOpenQuote)
				{
					if (openQuote == -1)
					{
						//Debug.Log("C-Open quote ignore " + lineSkip);
						break;
					}

					lineSkip = openQuote + 1;
					bool esc = false;
					int i = lineSkip - 1;
					while (i > 0 && line[i] == '\\')
					{
						esc = !esc;
						i--;
					}

					if (!esc)
					{
						cisOpenQuote = false;
					}

					//Debug.Log("C-Open quote end " + lineSkip);
					continue;
				}

				//Debug.Log ("Looking for comment " + lineSkip);
				int commentIdx;
				if (comment == 1)
				{
					commentIdx = line.IndexOf("*/", lineSkip, StringComparison.CurrentCulture);
					if (commentIdx != -1)
					{
						line = new string(' ', commentIdx + 2) + line.Substring(commentIdx + 2);
						lineSkip = commentIdx + 2;
						comment = 0;
					}
					else
					{
						line = "";
						break;
					}
				}

				commentIdx = line.IndexOf("//", lineSkip, StringComparison.CurrentCulture);
				int commentIdx2 = line.IndexOf("/*", lineSkip, StringComparison.CurrentCulture);
				if (commentIdx2 != -1 && (commentIdx == -1 || commentIdx > commentIdx2))
				{
					commentIdx = -1;
				}

				if (openQuote != -1 && (openQuote < commentIdx || commentIdx == -1) &&
				    (openQuote < commentIdx2 || commentIdx2 == -1))
				{
					cisOpenQuote = true;
					lineSkip = openQuote + 1;
					//Debug.Log("C-Open quote start " + lineSkip);
					continue;
				}

				if (commentIdx != -1)
				{
					line = line.Substring(0, commentIdx);
					break;
				}

				commentIdx = commentIdx2;
				if (commentIdx != -1)
				{
					int endCommentIdx = line.IndexOf("*/", lineSkip, StringComparison.CurrentCulture);
					if (endCommentIdx != -1)
					{
						line = line.Substring(0, commentIdx) + new string(' ', endCommentIdx + 2 - commentIdx) +
						       line.Substring(endCommentIdx + 2);
						lineSkip = endCommentIdx + 2;
					}
					else
					{
						line = line.Substring(0, commentIdx);
						comment = 1;
						break;
					}
				}
				else
				{
					break;
				}
			}

			return line;
		}
	}
}
#endif