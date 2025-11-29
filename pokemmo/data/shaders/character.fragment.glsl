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

varying vec4 v_color;
varying HIGH vec2 v_texCoords;
varying float v_flags;

uniform sampler2D u_texture;
uniform int u_useEnvLightning;
uniform vec3 u_ambientColor;
uniform vec3 u_dirLightColor;

uniform int u_useHatMask;
uniform sampler2D u_maskTex;

uniform HIGH vec2 u_hairScale;
uniform HIGH vec2 u_hairOffset;

uniform HIGH vec2 u_maskScale;
uniform HIGH vec2 u_maskOffset;

void main()
{
    vec4 col = texture2D(u_texture, v_texCoords) * v_color;

    if (u_useHatMask == 1)
    {
        HIGH vec2 hairUV = (v_texCoords - u_hairOffset) / u_hairScale;
        HIGH vec2 maskUV = hairUV * u_maskScale + u_maskOffset;
        float alpha = texture2D(u_maskTex, maskUV).a;
        col.a *= alpha;
    }

    float on = v_flags;

    if (u_useEnvLightning == 1)
    {
        col.rgb *= mix(vec3(1.0), u_ambientColor + u_dirLightColor, on);
    }

    gl_FragColor = col;
}