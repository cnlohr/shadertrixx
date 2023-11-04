// Execute with:
//   tcc -run SparkleCeilingGen.c

//#include "unitytexturewriter.h" // https://gist.github.com/cnlohr/c88980e560ecb403cae6c6525b05ab2f
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"
#include <math.h>

#define SPARKLE_W 512
#define SPARKLE_H 512

typedef struct _pxo
{
	uint8_t is_set;
	uint8_t colora, colorb;
} pxo __attribute__((packed));

pxo sparklec[SPARKLE_H][SPARKLE_W];

float precidence[SPARKLE_H][SPARKLE_W];

pxo * SPRR( int w, int h, float ** pres )
{
	int nw = ( ( w % SPARKLE_W ) + SPARKLE_W ) % SPARKLE_W;
	int nh = ( ( h % SPARKLE_H ) + SPARKLE_H ) % SPARKLE_H;
	if( pres ) *pres = &precidence[nh][nw];
	return &sparklec[nh][nw];
}

int crossfn( int x, int y, int cofs, pxo * pxoo, float * pres, int is_first )
{
	int is_set = 255;
	int is_setA = 255;
	float k = 22-sqrt( x*x+y*y )*10;
	if( is_first )
		k += 18;
	if( k < 0 ) is_set = 0;
	//if( y == 0 ) k += 10;

	int v;
	switch( cofs & 3 )
	{
	case 0:
		v = 600-(sqrt( x*x+y*y )*10 + sqrt(x*x)*20)*5 + cofs;
		break;
	case 1:
		v = 600-(sqrt( x*x+y*y )*10 + sqrt(y*y)*20)*5 + cofs;
		break;
	case 2:
		v = 600-(sqrt( abs(x*x-y*y ))*10)*5 + cofs;
		break;
	case 3:
		v = 600-(sqrt( x*x+y*y )*20)*5 + cofs;
		break;
	}
	if( v > 0xffff )
	{
		// Right now - do not allow wraparound.
		printf( "EXCEED\n" );
		return -99;
	}
	if( v < 0 )
	{
		// Right now - do not allow wraparound.
		printf( "UNDER\n" );
		return -99;
	}
	v = ((unsigned)v)&0xffff;
//	k += (sqrt(y*y) - sqrt(x*x)) * 2;
	if( pres )
	{
		if( *pres > k && !is_set ) return 0;
		*pres = k;
	}
	if( pxoo )
	{
		pxoo->is_set = is_set;
		pxoo->colora = v>>8;
		pxoo->colorb = v&0xff;
		
	}
	return is_set;
}

int main()
{
	int run = 0;
	int sparklect = 1536;
	int s = 0;
	int i;
	int x, y;
	for( y = 0; y < SPARKLE_H; y++ )
		for( x = 0; x < SPARKLE_W; x++ )
		{
			precidence[y][x] = -1000000;
		}
	
	for( i = 0; i < sparklect; i++ )
	{
		int found;
		int rnd_x;
		int rnd_y;
		int seed;
		int cofs;
		do
		{
			found = 1;
			// Make sure our sparkle area is clear.
			int x, y;
			
		try_again:
			rnd_x = rand() + 100;
			rnd_y = rand() + 100;
			seed = run + rand();
			run = (run+19337)%(65532*256);
			cofs = rand()+rand(); // can't wrap around.
			srand( seed );
			
			for( y = -4; y < 5; y++ )
				for( x = -4; x < 5; x++ )
				{
					pxo * k = SPRR( rnd_x + x, rnd_y + y, 0 );
					int v = crossfn( x, y, cofs, 0, 0, 1 );
					if( v < 0 ) continue;
					if( k->is_set ) { goto try_again; }
				}
		} while( 0 && !found );

		srand( seed );
		int x, y;
		for( y = -4; y < 5; y++ )
			for( x = -4; x < 5; x++ )
			{
				float * pres = 0;
				pxo * pxoo = SPRR( rnd_x + x, rnd_y + y, &pres );
				int v = crossfn( x, y, cofs, pxoo, pres, 0 );
			}
	}
    int r = stbi_write_png( "SparkleCeilingData.png", SPARKLE_W, SPARKLE_H, 3, sparklec, SPARKLE_W*3 );
	printf( "R: %d %d\n", r, sizeof( pxo ) );
}

