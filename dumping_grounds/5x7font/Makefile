all : shader5x7.glsl

shader5x7 : 5x7conv.c
	gcc -o $@ $^ -O0 -g

shader5x7.glsl : shader5x7 shader_tailer.glsl
	./$<

clean :
	rm -rf shader5x7.glsl

