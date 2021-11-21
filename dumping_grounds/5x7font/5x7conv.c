#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

char linebuffer[8193];

char * lreadline( FILE * f )
{
	int c;
	int pl = 0;
	while( ( c = fgetc( f ) ) != EOF )
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
		fscanf( f, "%d %d\n", &w, &h );
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

	int chars = 128-32;
	int ints = chars*6/4;
	uint32_t buffero[ints]; // 144
	int i;
	for( i = 0; i < ints; i++ )
	{
		uint32_t v = 0;
		int bit;
		for( bit = 0; bit < 32; bit++ )
		{
			int x = (bit/8)+i*4 + 32 * 6;
			//printf( "Reading %d / %d / %d -> %d = %d\n", x,i,bit,x+(bit%8)*w,buffer_in[x+(bit%8)*w] );
			v |= (buffer_in[x+(7-(bit%8))*w]?1:0)<<bit;
		}
		buffero[i] = v;
	}

	FILE * cgo = fopen( "shader_tailer.glsl", "r" ); 
	FILE * out = fopen( "shader5x7.glsl", "w" );
	fprintf( out, "const int shader5x7[%d] = int[%d](", ints, ints );
	for( i = 0 ; i < ints; i++ )
	{
		if( i % 8 == 0 )
		{
			fprintf( out, "\n\t" );
		}
		fprintf( out, "0x%08x%c ", buffero[i], (i==(ints-1))?'\n':',' );
	}
	fprintf( out, ");\n" );
	while( !feof( cgo ) )
	{
		fputs( lreadline( cgo ), out );
	}
	fclose( cgo );
	fclose( out );
	return 0;
}


