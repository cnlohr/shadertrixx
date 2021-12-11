#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

public class GenerateSnowlandMesh : MonoBehaviour
{
	[MenuItem("Tools/GenerateSnowlandMesh")]
	static void CreateMesh_()
	{
		Mesh mesh = new Mesh();
		int w = 36;
		int h = 40;
		Vector3[] vertices = new Vector3[w*h];
		int x, y;
		for( y = 0; y < h; y++ )
		{
			for( x = 0; x < w; x++ )
			{
				int idx = x+y*w;
				vertices[idx].x = (x + 0.5f * (y % 2) - ((float)w-1)/2.0f)/(float)(w-1);
				vertices[idx].z = (y - ((float)h-1)/2.0f)/(float)(w-1)*.866f;
				Debug.Log( vertices[idx] );
			}
		}
		
		int wm1 = w-1;
		int hm1 = h-1;
		int indexqty = hm1*wm1*6;
		ushort [] indices = new ushort[indexqty];
		for( y = 0; y < hm1; y++ )
		{
			for( x = 0; x < wm1; x++ )
			{
				if( ( y % 2 ) == 1 )
				{
					indices[(x+y*wm1)*6+0] = (ushort)((x+1)+(y+1)*w);
					indices[(x+y*wm1)*6+1] = (ushort)((x+1)+y*w);
					indices[(x+y*wm1)*6+2] = (ushort)(x+y*w);
					indices[(x+y*wm1)*6+3] = (ushort)(x+y*w);
					indices[(x+y*wm1)*6+4] = (ushort)(x+(y+1)*w);
					indices[(x+y*wm1)*6+5] = (ushort)((x+1)+(y+1)*w);
				}
				else
				{
					indices[(x+y*wm1)*6+0] = (ushort)((x+1)+y*w);
					indices[(x+y*wm1)*6+1] = (ushort)(x+(y+1)*w);
					indices[(x+y*wm1)*6+2] = (ushort)((x+1)+(y+1)*w);
					indices[(x+y*wm1)*6+3] = (ushort)(x+y*w);
					indices[(x+y*wm1)*6+4] = (ushort)(x+(y+1)*w);
					indices[(x+y*wm1)*6+5] = (ushort)((x+1)+y*w);
				}
			}
		}
		mesh.vertices = vertices;
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(400, 400, 400));
		mesh.SetIndices(indices, MeshTopology.Triangles, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/cnlohr/Scripts/Snowland/SnowlandMesh.asset");
	}
}
#endif