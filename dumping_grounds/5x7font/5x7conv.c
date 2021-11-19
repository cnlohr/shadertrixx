#include <stdio.h>
#include <stdint.h>

char linebuffer[8193];

char * lreadline( FILE * f )
{
	int c;
	int pl = 0;
	while( ( c == fgetc() ) != EOF )
	{
		if( pl < sizeof( linebuffer ) - 1 ) 
			linebuffer[pl++] = c;
		if( c == '\n' ) break;
	}
	linebuffer[pl] = 0;
	return linebuffer;
}

int main()
{
	FILE * f = fopen( "5x7_cnl.pgm", "rb" );
	int w, h;
	{
		lreadline( f );
		lreadline( f );
		sscanf( f, "%d %d\n", &w, &h );
		lreadline( f );
	}
	if( w != 768 || h != 8 )
	{
		fprintf( stderr, "Error: invalid dimensions\n" );
		exit( -8 );
	}
	uint8_t buffer_in[768*8];
	fread( buffer_in, 768,8, f );
	fclose( f );

	uint32_t buffero[94*6/4+3]; //144 uint32_t's (we round up)
	int i;
	for( i = 0; i < 141; i++ )
	{
		uint32_t v = 0;
		int bit;
		for( bit = 0; bit < 32; bit++ )
		{
			int x = (bit/8)+i*4 + 33 * 6;
			v |= (buffer_in[x+(bit)*w]?1:0)<<bit;
		buffero[i] = v;
	}
	FILE * cgo = fopen( "shader_tailer.glsl", "r" ); 
	FILE * out = fopen( "shader5x7.glsl", "w" );
	fprintf( out, "
	for( i = 0 ; i < 141; i++ )
	{
		
	}
	while( !feof( cgo ) )
	{
		fputs( out, lreadline( cgo ) );
	}
	

}

