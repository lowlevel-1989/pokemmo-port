#ifdef GL_ES
precision highp float;
#define LOWP lowp
#define MED mediump
#define HIGH highp
#else
#define MED
#define LOWP
#define HIGH
#endif

attribute vec4 a_position;
attribute vec4 a_color;
attribute vec2 a_texCoord0;
attribute float a_flags;

uniform mat4 u_projTrans;

varying vec4 v_color;
varying HIGH vec2 v_texCoords;
varying float v_flags;

void main()
{
    v_color = a_color;
    v_flags = a_flags;
    v_texCoords = a_texCoord0;
    gl_Position = u_projTrans * a_position;
}