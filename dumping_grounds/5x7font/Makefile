all : 5x7conv

shader5x7.glsl : 5x7conv.c shader_header.glsl
	tcc -run $<

clean :
	rm -rf shader5x7.glsl

