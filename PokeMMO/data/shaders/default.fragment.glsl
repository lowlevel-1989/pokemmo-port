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
}
