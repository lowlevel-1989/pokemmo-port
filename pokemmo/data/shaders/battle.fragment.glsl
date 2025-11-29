#ifdef GL_ES
precision mediump float;
#endif

#if defined(colorFlag)
varying vec4 v_color;
#endif

#ifdef diffuseTextureFlag
varying vec2 v_diffuseUV;
uniform sampler2D u_diffuseTexture;
#endif

#ifdef diffuseColorFlag
uniform vec4 u_diffuseColor;
#endif

#ifdef blendedFlag
varying float v_opacity;
#ifdef alphaTestFlag
varying float v_alphaTest;
#endif //alphaTestFlag
#endif //blendedFlag

void main() {
    vec4 diffuse = vec4(1.0);

    #if defined(diffuseTextureFlag) && defined(diffuseColorFlag) && defined(colorFlag)
        diffuse = texture2D(u_diffuseTexture, v_diffuseUV) * u_diffuseColor * v_color;
    #elif defined(diffuseTextureFlag) && defined(diffuseColorFlag)
        diffuse = texture2D(u_diffuseTexture, v_diffuseUV) * u_diffuseColor;
    #elif defined(diffuseTextureFlag) && defined(colorFlag)
        diffuse = texture2D(u_diffuseTexture, v_diffuseUV) * v_color;
    #elif defined(diffuseTextureFlag)
        diffuse = texture2D(u_diffuseTexture, v_diffuseUV);
    #elif defined(diffuseColorFlag) && defined(colorFlag)
        diffuse = u_diffuseColor * v_color;
    #elif defined(diffuseColorFlag)
        diffuse = u_diffuseColor;
    #elif defined(colorFlag)
        diffuse = v_color;
    #endif

    gl_FragColor = diffuse;

	#ifdef blendedFlag
		gl_FragColor.a = diffuse.a * v_opacity;
		#ifdef alphaTestFlag
			if (gl_FragColor.a <= v_alphaTest)
				discard;
		#endif
	#else
		gl_FragColor.a = 1.0;
	#endif

  #if defined(diffuseTextureFlag) && defined(diffuseColorFlag)
    if (gl_FragColor.a <= 0.7)
      gl_FragColor = vec4(0.0, 0.0, 0.0, gl_FragColor.a);
  #endif
}
