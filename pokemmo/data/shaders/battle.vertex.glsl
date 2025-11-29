attribute vec3 a_position;
uniform mat4 u_projViewTrans;
uniform mat4 u_worldTrans;

varying   vec4 v_color;
attribute vec4 a_color;

attribute vec2 a_texCoord0;
uniform   vec4 u_diffuseUVTransform;
varying   vec2 v_diffuseUV;

#ifdef blendedFlag
uniform float u_opacity;
varying float v_opacity;

#ifdef alphaTestFlag
uniform float u_alphaTest;
varying float v_alphaTest;
#endif //alphaTestFlag
#endif // blendedFlag

void main() {

	vec4 pos = u_worldTrans * vec4(a_position, 1.0);

  // MOD: render de la textura del pokemon y la sombra
  #if defined(diffuseTextureFlag) && defined(diffuseColorFlag)
    float scale = 1.5;
    vec3 translation = vec3(-10.0, 25.0, 0.0);
	  pos = u_worldTrans * vec4(a_position * scale + translation, 1.0);
	#endif

  gl_Position = u_projViewTrans * pos;
  v_diffuseUV = u_diffuseUVTransform.xy + a_texCoord0 * u_diffuseUVTransform.zw;
  v_color     = a_color;

	#ifdef blendedFlag
		v_opacity = u_opacity;
		#ifdef alphaTestFlag
			v_alphaTest = u_alphaTest;
		#endif //alphaTestFlag
	#endif // blendedFlag

}
