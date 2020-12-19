//Aurora originally by nimitz (see below) later modified by SCRN.
//CNLohr modded for a few perf tweaks.
Shader "SCRN_Aurora"
{
	Properties
	{
		_TexOut ("TexOut", 2D) = "black" {}
		_Position ("Position", Vector) = (0.0,0.05,0.0)
		_TANoiseTex ("TANoise", 2D) = "white" {}
	}
	Subshader
	{
		Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
		Cull Front
		Lighting Off
		SeparateSpecular Off
		Fog { Mode Off }
		Pass
		{
			CGPROGRAM
			#pragma vertex vertex_shader
			#pragma fragment pixel_shader
			#pragma target 5.0
			#pragma fragmentoption ARB_precision_hint_fastest

			fixed3 _Position;
			sampler2D _TexOut;
			fixed2 varInput;

            sampler2D _TANoiseTex;
			uniform half2 _TANoiseTex_TexelSize; 
            float4 _NoiseTex_ST;
			#include "../tanoise/tanoise.cginc"

			#define TexInRes fixed2(2,2)
			fixed4 loadValue(fixed2 re)
			{
				re.y = 1 - re.y;
				return tex2Dlod( _TexOut, fixed4(re / TexInRes.xy, 0, 0));
			}

#define CNLOHR_AURORA_MOD

			//Auroras by nimitz 2017 (twitter: @stormoid)

			/*
				There are two main hurdles I encountered rendering this effect. 
				First, the nature of the texture that needs to be generated to get a believable effect
				needs to be very specific, with large scale band-like structures, small scale non-smooth variations
				to create the trail-like effect, a method for animating said texture smoothly and finally doing all
				of this cheaply enough to be able to evaluate it several times per fragment/pixel.

				The second obstacle is the need to render a large volume while keeping the computational cost low.
				Since the effect requires the trails to extend way up in the atmosphere to look good, this means
				that the evaluated volume cannot be as constrained as with cloud effects. My solution was to make
				the sample stride increase polynomially, which works very well as long as the trails are lower opcaity than
				the rest of the effect. Which is always the case for auroras.

				After that, there were some issues with getting the correct emission curves and removing banding at lowered
				sample densities, this was fixed by a combination of sample number influenced dithering and slight sample blending.

				N.B. the base setup is from an old shader and ideally the effect would take an arbitrary ray origin and
				direction. But this was not required for this demo and would be trivial to fix.
			*/

			fixed time;
			#define ResX  _ScreenParams.x

			#define BUMPFACTOR 0.1
			#define EPSILON 0.1
			#define BUMPDISTANCE 60.

			#if 0
			fixed2x2 mm2(in fixed a){fixed c = cos(a), s = sin(a);return fixed2x2(c,s,-s,c);}
			#else
			fixed2x2 mm2( fixed th ) // farbrice neyret magic number rotate 2x2
			{
				fixed2 a = sin(fixed2(1.5707963, 0) + th);
				return fixed2x2(a, -a.y, a.x);
			}
			#endif

			static const fixed2x2 m2 = fixed2x2(0.95534, 0.29552, -0.29552, 0.95534);

			static const fixed3x3 m3 = fixed3x3( 0.00,  0.80,  0.60, -0.80,  0.36, -0.48, -0.60, -0.48,  0.64 );

			static const fixed2 dx = fixed2( EPSILON, 0. );
			static const fixed2 dz = fixed2( 0., EPSILON );

			fixed tri(in fixed x){return clamp(abs(frac(x)-.5),0.01,0.49);}
			fixed2 tri2(in fixed2 p){return fixed2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));}

			fixed triNoise2d(in fixed2 p, fixed spd)
			{
				const fixed2x2 mulMat = mm2(time*spd);
				fixed z=1.8;
				fixed z2=2.5;
				fixed rz = 0.;
				p = mul(p,mm2(p.x*0.06));
				fixed2 bp = p;
				for (fixed i=0.; i<3.; i++ )
				{
					fixed2 dg = tri2(bp*1.85)*varInput.x;
					dg = mul(dg, mulMat);
					p -= dg/z2;

					bp *= 1.3;
					z2 *= .45;
					z *= .42;
					p *= 1.21 + (rz-1.0)*.02;
					
					rz += tri(p.x+tri(p.y))*z;
				}
				return clamp(1./(rz*32.),0.,.55);
			}

			fixed hash21(in fixed2 n){ return frac(sin(dot(n, fixed2(12.9898, 4.1414))) * 43758.5453); }

			fixed4 aurora(fixed3 ro, fixed3 rd)
			{
				fixed4 col = fixed4(0,0,0,0);
				fixed4 avgCol = fixed4(0,0,0,0);
				[unroll]
				for(fixed i=0.;i<22;i+=1.3)// I know, this is terrible but it's not as banding prone as lowering trinoise
				{
					fixed pt = ((.8+pow(i*1.4,1.4)*.002)-ro.y)/(rd.y*2.+0.4);
					fixed3 bpos = ro + pt * rd;
					fixed rzt = triNoise2d(bpos.zx, 0.06);
					avgCol = (avgCol + fixed4((sin(1.5-fixed3(2.5,-.25, 1.2)+i*0.086)*0.5+0.5)*rzt,rzt)) * .65; // accumulate a little more color since we use half the steps
					col += avgCol*exp2(-i*0.07 - 3.6);//*smoothstep(0.,5., i*2); // accumulate more
				}
				
				col *= saturate(rd.y*2.+.4); // horizon fade
				return col*3.;
			}

			#if 1
			fixed3 hash33(fixed3 p)
			{
				p = frac(p * fixed3(443.8975,397.2973, 491.1871));
				p += dot(p.zxy, p.yxz+19.27);
				return frac(fixed3(p.x * p.y, p.z*p.x, p.y*p.z));
			}
			#else
			fixed3 hash33(fixed3 p){
				fixed n = sin(dot(p, fixed3(7, 157, 113)));    
				return frac(fixed3(2097152, 262144, 32768)*n); 
			}
			#endif

			fixed3 stars(in fixed3 p)
			{
				p.xy = mul(mm2(_Time.x*.1),p.xy);
				fixed3 c = fixed3(0,0,0);
				fixed res = ResX;
#ifdef CNLOHR_AURORA_MOD

				fixed3 pRes = p*(.15*res);
				fixed3 q = frac(pRes)-0.5;
				fixed3 id = floor(pRes);
				fixed2 rn = tanoise3_1d_fast(id);//hash33(id).xy;
				fixed c2 = 1.-smoothstep(0.,.6,length(q));
				c2 *= step(rn.x,.01);
				c += c2*(lerp(fixed3(1.0,0.49,0.1),fixed3(0.75,0.9,1.),rn.y)*0.1+0.9);
				p *= 1.3;

				return c*c*0.5/*Star intensity*/;
#else
				[unroll]
				for (fixed i=0.;i<3.;i++)
				{
					fixed3 pRes = p*(.15*res);
					fixed3 q = frac(pRes)-0.5;
					fixed3 id = floor(pRes);
					fixed2 rn = hash33(id).xy;
					fixed c2 = 1.-smoothstep(0.,.6,length(q));
					c2 *= step(rn.x,.0005+i*i*0.001);
					c += c2*(lerp(fixed3(1.0,0.49,0.1),fixed3(0.75,0.9,1.),rn.y)*0.1+0.9);
					p *= 1.3;
				}
				return c*c*.25;
#endif
			}

			fixed fbm( in fixed3 p ) {
				fixed
				f  = 0.5000*tanoise3_1d_fast( p ); p = mul(p,m3)*2.02;
				f += 0.2500*tanoise3_1d_fast( p ); p = mul(p,m3)*2.03;
				f += 0.1250*tanoise3_1d_fast( p ); p = mul(p,m3)*2.01;
				f += 0.0625*tanoise3_1d_fast( p );
				return f;
			}

			fixed waterMap( fixed2 pos ) {
				fixed2 posm = mul(m2, pos);
				return (fbm( fixed3( 8.*posm, time )) - 0.5 )* 0.1;
			}

			fixed3 bg(in fixed3 rd)
			{
				fixed sd = dot(normalize(fixed3(-0.5, -0.6, 0.9)), rd)*0.5+0.5;
				sd *= sd*sd;
				fixed3 col = lerp(fixed3(0.05,0.1,0.2), fixed3(0.1,0.05,0.2), sd);
				return col*.63;
			}

			bool intersectPlane(const in fixed3 ro, const in fixed3 rd, const in fixed height, inout fixed dist) {	
				if (rd.y==0.0) {
					return false;
				}
					
				fixed d = -(ro.y - height)/rd.y;
				if( d > 0. && d < dist ) {
					dist = d;
					return true;
				} else {
					return false;
				}
			}

			fixed3 getSceneColor( in fixed3 ro, in fixed3 rd ) {

				fixed3 col = fixed3(0,0,0);

				fixed fresnel = 0.0, refldist = 5000.;
				bool reflected = false;
				fixed3 normal;
				fixed3 roo = ro, rdo = rd;

				if( intersectPlane( ro, rd, -.01, refldist ) && refldist < 5000. ) {
					ro += refldist*rd;	
					fixed2 coord = ro.xz;
					fixed bumpfactor = BUMPFACTOR * (1. - smoothstep( 0., BUMPDISTANCE, refldist) );
					
					normal = fixed3( 0., 1., 0. );
					normal.x = -bumpfactor * (waterMap(coord + dx) - waterMap(coord-dx) ) / (2. * EPSILON);
					normal.z = -bumpfactor * (waterMap(coord + dz) - waterMap(coord-dz) ) / (2. * EPSILON);
					normal = normalize( normal );		
					
					fixed ndotr = dot(normal,rd);
					fresnel = pow(1.0-abs(ndotr),5.);

					rd = reflect(rd, normal);
					reflected = true;
				}
				
				col = bg(rd)*.6;
				fixed3 apos = fixed3(7.-varInput.y,-.2,7.-varInput.y);
				fixed4 aur = smoothstep(0.,1.5,aurora(apos,rd));
				col += stars(rd) * (1.-aur.a) + aur.rgb;

				if( reflected ) {
					col *= fresnel;		
				}
				return col;
			}

			struct custom_type
			{
				fixed4 screen_vertex : SV_POSITION;
				//fixed2 uv : TEXCOORD0;
				fixed3 world_vertex : TEXCOORD1;
				fixed3 pixel_input : TEXCOORD3;
			};

			custom_type vertex_shader (fixed4 vertex : POSITION, fixed2 uv:TEXCOORD0)
			{
				custom_type vs;
				vs.screen_vertex = UnityObjectToClipPos (vertex);
				//vs.uv = uv - 0.5;
				vs.world_vertex = mul(unity_ObjectToWorld, vertex);

				fixed3 input = loadValue(fixed2(1,1)).xyz;
				input.xy = smoothstep(0.1, 1, input.xy);
				input.x = lerp(.75, .4, input.x);
				vs.pixel_input = input;
				return vs;
			}

			fixed4 pixel_shader (custom_type ps) : SV_TARGET
			{
				varInput = ps.pixel_input;
				time = _Time.g;
				fixed3 worldPosition = _WorldSpaceCameraPos / 10. + _Position;
				fixed3 viewDirection = normalize(ps.world_vertex - _WorldSpaceCameraPos);
				worldPosition.y = max(worldPosition.y, 0);
				return fixed4(getSceneColor( worldPosition + _Position, viewDirection ),1.0);
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
}