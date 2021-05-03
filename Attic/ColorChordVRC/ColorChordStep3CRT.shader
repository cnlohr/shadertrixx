Shader "Custom/ColorChord/Step3CRT"
{
    Properties
    {
		_NotesData ("Note Data (Phase 2 Output)", 2D) = "white" {}
		_LastFrameData ("Last Frame Data", 2D) = "white" {}
		_RootNote ("RootNote", int ) = 0
		_PeelOff ("Peel Off Ratio", float) = 0.8

		
		_Brightness( "Brightness", float ) = 0.2
		_BrightnessGamma( "Brightness Gamma", float ) = 1.0
		_UnifyCommonness( "Commonness", float ) = 2.0
		_PickNewSpeed( "Pick New Speed", float ) = 1.0
		_UnifyMinimum ("Unify Minimum", float) = 0.05
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
		
		Cull Off
        Lighting Off		
		ZWrite Off
		ZTest Always

        Pass
        {
            Name "Step3CRT"
            CGPROGRAM
			
            #include "UnityCustomRenderTexture.cginc"
			#include "ColorChordVRC.cginc"

            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag


			#define CCclamp( x, y, z ) (x)

            #include "UnityCG.cginc"
			
			Texture2D<float4> _LastFrameData;
			Texture2D<float4> _NotesData;
			float2 _LastFrameData_TexelSize;
			int _RootNote;
			float _PeelOff;
			float _Brightness;
			float _BrightnessGamma;
			float _UnifyCommonness;
			float _PickNewSpeed;
			float _UnifyMinimum;
			
			//Number of peaks to search through.
			#define MAXSEARCHPEAKS 5
			
			float tinyrand(float3 uvw)
			{
				return frac(cos(dot(uvw, float3(137.945, 942.32, 593.46))) * 442.5662);
			}


			float unify( float a )
			{
				return pow( a, _UnifyCommonness ) - _UnifyMinimum;
			}

			float unifycolor( float a )
			{
				return pow( a*_Brightness, _BrightnessGamma );
			}
			
			float SetNewCellValue( float a )
			{
				return a* 0.5;
			}
			
            fixed4 frag (v2f_customrendertexture IN) : SV_Target
            {
				float2 uv = IN.localTexcoord.xy;

				float4 MetaInfo = _NotesData.Load( int3( MAXPEAKS-1, 0, 0 ) );
				//Metainfo:
				//   R: Overall peak intensity.
				//   G: Average Phase 1 Amplitude
				//   B: Heavily filtered amplitude of loudest peak note.
				//   A: Sum of Uniformitivity-weighted outputs.

				int2 thissize = 1/_LastFrameData_TexelSize;
				int2 thisxy = uv/_LastFrameData_TexelSize;
				thisxy.x = thisxy.x % (thissize/2);
				float4 ComputeCell = _LastFrameData.Load( int3( thisxy, 0 ) );

				//ComputeCell
				//	.x = Mated Cell # (Or -1 for black)
				//	.y = Minimum Brightness Before Jump
				//	.z = ???
				
				float4 CurrentCell = _NotesData.Load( int3( ComputeCell.x, 0, 0 ) );
				//  Each element:
				//   R: Peak Location (Note #)
				//   G: Peak Intensity
				//   B: Peak Q value (How pointy?)
				//   A: Uniformitvity-weighted output.

				if( CurrentCell.a < ComputeCell.y || ComputeCell.y <= 0 )
				{
					//Need to select new cell.
					float min_to_acquire = tinyrand( float3( uv, _Time.x ) );
					
					int n;
					float4 SelectedCell = 0.;
					int SelectedCellNo = -1;
					
					float cumulative = 0.0;
					for( n = 0; n < MAXSEARCHPEAKS; n++ )
					{
						float4 Cell = _NotesData.Load( int3( n, 0, 0 ) );
						float unic = unify(Cell.a);
						if( unic > 0 )
							cumulative += unic;
					}

					float sofar = 0.0;
					for( n = 0; n < MAXSEARCHPEAKS; n++ )
					{
						float4 Cell = _NotesData.Load( int3( n, 0, 0 ) );
						float unic = unify(Cell.a);
						if( unic > 0 ) 
						{
							sofar += unic;
							if( sofar/cumulative > min_to_acquire )
							{
								SelectedCell = Cell;
								SelectedCellNo = n;
								break;
							}
						}
					}
					
				
									//return SelectedCellNo/4.;

					if( SelectedCell.a > 0.0 )
					{
						ComputeCell.x = SelectedCellNo;
						ComputeCell.y = SetNewCellValue(SelectedCell.a);//(tinyrand( float3( uv, _Time.x + 0.5 ) )*.1+0.01);//HighestCell.a * (tinyrand( float3( uv, _Time.x + 0.5 ) )*0.5);
					}
					else
					{
						ComputeCell.x = 0;
						ComputeCell.y = 0;
					}
				}
				else
				{
					ComputeCell.y -= _PickNewSpeed*0.01;
				}
				
				CurrentCell = _NotesData.Load( int3( ComputeCell.x, 0, 0 ) );

				//if( SetNewCellValue(CurrentCell.a) > ComputeCell.y )
				//{
				//	ComputeCell.y = SetNewCellValue( CurrentCell.a );
				//}
				

				if( uv.x >= 0.5 )
				{
					// the light color output
					if( ComputeCell.y <= 0 )
					{
						return 0.;
					}
					return fixed4( CCtoRGB( glsl_mod( CurrentCell.x,48.0 ), unifycolor(CurrentCell.a), _RootNote ), 1.0 );
				}
				else
				{
					// the compute output
					return ComputeCell;
				}
            }
            ENDCG
        }
    }
}
