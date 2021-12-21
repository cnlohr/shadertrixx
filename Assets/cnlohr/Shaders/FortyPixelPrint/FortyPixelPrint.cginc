// The MIT License
// Copyright 2021 Charles Lohr
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions: The above copyright
// notice and this permission notice shall be included in all copies or
// substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS",
// WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#define HIGHQ
#define BORDERIZE

#ifndef FONTTHINNESS
//Neutral weight.
#define FONTTHINNESS .3
#endif
	
const static uint shader5x7[144] = {
	0x00000000, 0x00000000, 0x000000f6, 0x60006000, 0xfe280000, 0x0028fe28, 0x92ff9264, 0xc8c6004c, 
	0x00c62610, 0x046a926c, 0x0000000a, 0x00000060, 0x42241800, 0x42000000, 0x00001824, 0x083e0814, 
	0x10100014, 0x0010107c, 0x06010000, 0x10100000, 0x00101010, 0x00060600, 0x04020000, 0x00201008, 
	0xa2928a7c, 0x4200007c, 0x000002fe, 0x928a8642, 0x82840062, 0x008cd2a2, 0xfe482818, 0xa2e40008, 
	0x009ca2a2, 0x9292523c, 0x8e80000c, 0x00c0a090, 0x9292926c, 0x9260006c, 0x00789492, 0x006c6c00, 
	0x6d000000, 0x0000006e, 0x82442810, 0x28280000, 0x00282828, 0x10284482, 0x8a800000, 0x00006090, 
	0x525a423c, 0x907e0034, 0x007e9090, 0x929292fe, 0x827c006c, 0x00448282, 0x448282fe, 0x92fe0038, 
	0x00828292, 0x809090fe, 0x827c0080, 0x005c9292, 0x101010fe, 0x828200fe, 0x008282fe, 0xfe818102, 
	0x10fe0080, 0x00824428, 0x020202fe, 0x40fe0002, 0x00fe4020, 0x081020fe, 0x827c00fe, 0x007c8282, 
	0x909090fe, 0x827c0060, 0x007a848a, 0x949890fe, 0x92640062, 0x004c9292, 0x80fe8080, 0x02fc0080, 
	0x00fc0202, 0x040204f8, 0x02fc00f8, 0x00fc021c, 0x281028c6, 0x20c000c6, 0x00c0201e, 0xa2928a86, 
	0xfe0000c2, 0x00008282, 0x08102040, 0x82000004, 0x0000fe82, 0x40804020, 0x01010020, 0x00010101, 
	0x20400000, 0x2a040000, 0x001e2a2a, 0x222214fe, 0x221c001c, 0x00042222, 0x1422221c, 0x2a1c00fe, 
	0x00102a2a, 0x40483e08, 0x25180020, 0x003e2525, 0x202010fe, 0x2200001e, 0x000002be, 0x00be0102, 
	0x08fe0000, 0x00002214, 0x02fe8200, 0x203e0000, 0x001e2018, 0x2020103e, 0x221c001e, 0x001c2222, 
	0x2424183f, 0x24180018, 0x003f1824, 0x2020103e, 0x2a120010, 0x0000242a, 0x227e2020, 0x023c0022, 
	0x00023c02, 0x04020438, 0x023c0038, 0x003c0204, 0x14081422, 0x39000022, 0x003e0505, 0x322a2a26, 
	0x6c100000, 0x00008282, 0x00ee0000, 0x82820000, 0x0000106c, 0x08102010, 0x00000010, 0x00000000
 };
 
const static uint ipow10[12] = { 1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000, 2147483647, 2147483647 };
#define calc_ipow10(x) ipow10[x]
//#define calc_ipow10(x) int(round(pow(10.0,float(x))))

#define _SPACE 0
#define _BANG 1
#define _A 33
#define _B 34
#define _C 35
#define _D 36
#define _E 37
#define _F 38
#define _G 39
#define _H 40
#define _I 41
#define _J 42
#define _K 43
#define _L 44
#define _M 45
#define _N 46
#define _O 47
#define _P 48
#define _Q 49
#define _R 50
#define _S 51
#define _T 52
#define _U 53
#define _V 54
#define _W 55
#define _X 56
#define _Y 57
#define _Z 58
#define ZEROLEADBLANK -20

#ifdef HIGHQ

// Perform a fake "texel" lookup, and return all 4 cells.
float4 g5x7d( int ch, float2 uv )
{
	uint2 cell = uint2(uv);
	int x = ch * 6 + cell.x;
	uint2 xres = uint2( x, x-1 );
	// Fixup gross edges.
	if( cell.x >= 6 ) xres.x = 0; //Special shader5x7 #0 is all zeroes.
	uint2 cv = uint2( shader5x7[xres.x/4], shader5x7[xres.y/4] );
	uint2 movfs = (xres%4)*8;
	cv = (cv>>movfs)&0xff;
	uint4 value  = uint4(
		cv>>(cell.yy-1), 
		cv>>(cell.yy+0))&1;

	return float4(value.yxwz);
}


float2 fast_inverse_smoothstep( float2 x )
{
	// Uncomment for blobbier letters
	//return x;
	return 0.5 - sin(asin(1.0-2.0*x)/3.0); //Inigo Quilez trick.
}

float2 roundstep( float2 x )
{
	float2 coss = cos( x*3.14159 + 3.14159 );
	float2 sins = sign( coss );
	coss = abs( coss );
	coss = pow( coss, float2( 1.0, 1.0 ) );
	coss *= sins;
	return coss / 2.0 + 0.5;
}


float3 char5x7( int ch, float2 uv )
{
#ifdef BORDERIZE
	uv *= float2( 7./6., 9./8. );
	uv += float2( 0.0, 0.0);
#else
	uv += float2( 0., -.25);
#endif
	float4 d = g5x7d( ch, uv );

	float2 lp;
	lp = fast_inverse_smoothstep(frac( uv ));

	float top =  lerp( d.x, d.y, lp.x );
	float bottom = lerp( d.z, d.w, lp.x );
	float v = ( lerp( top, bottom, lp.y ) );

	// This makes it be a harder edge (But still kinda soft)
	v = (v-FONTTHINNESS)*( 4.+ 1./length( ddx(uv) + ddy(uv) ));
	
	v = clamp( v, 0., 1. );
	
	float3 col = lerp( float3( 0, 0, 0 )*.5, float3( uv.y+3., uv.y+3., 10.0 )/10.0, float(v) );
	return col;

}

#else


float3 char5x7( int ch, float2 uv )
{
#ifdef BORDERIZE
	uv *= float2( 7./6., 9./8. );
	if( uv.x < 0. || uv.y < 0. || uv.x > 6. || uv.y > 8. ) return float3(0);
#endif
	uint2 cell = uint2(uv);
	int x = ch * 6 + int(cell.x);
	int cv = shader5x7[x/4];
	int movfs = (x%4)*8;
	int value  = ((cv>>(movfs+cell.y))&1);
	int value2 = ((cv>>(movfs+int(uv.y+.5)))&1);
	if( uv.y >= 7.0 ) value2 = 0;
	float3 col = mix( float3( value2, 0, value2 )*.5, float3( cell.y+3, cell.y+3, 10.0 )/10.0, float(value) );
	return col;
}

#endif


float3 print5x7int( int num, float2 uv, int places, int leadzero )
{
	float2 cuv = uv*float2( places, 1. );
	float2 luv = cuv*float2( 6, 8. );
	uint2 iuv = uint2( luv );
	int posi = int(iuv.x/6);
	int marknegat = -1;
	if( num < 0 )
	{
		marknegat = places-int(log(-float(num))/log(10.0))-2;
	}
	num = abs(num);
	uint nn = (num/calc_ipow10(places-posi-1));
	if( posi == marknegat )
		nn = -3;
	else if( nn <= 0 && posi != places-1)
		nn = leadzero;
	else
		nn %= 10;
	int ch = nn+48-32;
	return char5x7( ch, frac(cuv)*float2(6.,8.) );
}

// Zero Leading Integer Print
float3 print5x7intzl( int num, float2 uv, int places )
{
	float2 cuv = uv*float2( places, 1. );
	float2 luv = cuv*float2( 6, 8. );
	uint2 iuv = uint2( luv );
	int posi = int(iuv.x/6);
	uint nn = (num/calc_ipow10(places-posi-1));
	nn %= 10;
	int ch = nn+48-32;
	return char5x7( ch, frac(cuv)*float2(6.,8.) );
}

float3 print5x7float( float num, float2 uv, int wholecount, int decimalcount )
{
	float2 cuv = uv*float2( wholecount+decimalcount+1, 1. );
	float2 luv = cuv*float2( 6, 8. );
	uint2 iuv = uint2( luv );
	int posi = int(iuv.x/6.0);
	int nn = -2;
	
	int marknegat = -1;
	if( num < 0.0 )
	{
		marknegat = wholecount-2-int(log(-num)/log(10.0));
	}
	
	num = abs(num);
	num +=  pow(.1f,float(decimalcount))*.499;
	int nv = int( num );
	
	if( posi < wholecount )
	{
		int wholediff = posi - wholecount+1;
		float v = (pow( 10.0 , float(wholediff)));
		uint ni = int( float(nv) * v);
		if( posi == marknegat ) nn = -3;
		else if( ni <= 0 && wholediff != 0 ) nn = -16; //Blank out.
		else		 nn = ni%10;
	}
	else if( posi > wholecount )
	{
		num -= float(nv);
		nn = uint( num * pow( 10.0 , float(posi-wholecount)))%10;
	}
	int ch = nn+48-32;

	return char5x7( ch, frac(cuv)*float2( 6, 8. ));
}
