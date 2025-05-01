attribute vec3 a_position;
uniform mat4 u_projViewTrans;
uniform mat4 u_worldTrans;

varying   vec4 v_color;
attribute vec4 a_color;

attribute vec2 a_texCoord0;
uniform   vec4 u_diffuseUVTransform;
varying   vec2 v_diffuseUV;

void main() {
  gl_Position = u_projViewTrans * u_worldTrans * vec4(a_position, 1.0);
  v_diffuseUV = u_diffuseUVTransform.xy + a_texCoord0 * u_diffuseUVTransform.zw;
  v_color     = a_color;
}
