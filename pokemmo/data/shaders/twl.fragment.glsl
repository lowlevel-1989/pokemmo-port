#ifdef GL_ES
#define LOWP lowp
    precision mediump float;
#else
    #define LOWP
#endif

varying LOWP vec4 v_color;
varying vec2 v_texCoords;
uniform sampler2D u_texture;

#ifdef glowHQ
const float glowPass = 9.0;
#else
const float glowPass = 3.0;
#endif

uniform float glowIntensity;
uniform float glowThreshold;
uniform float glowSize;
uniform vec3 glowColor;
uniform vec2 glowInvTexSize;
uniform vec2 glowTexSize;

float fTexelFetch(sampler2D tex, ivec2 coord)
{
    return texture2D(tex, vec2(float(coord.x) * glowInvTexSize.x, float(coord.y) * glowInvTexSize.y)).a;
}

void main()
{
	vec4 diffuse = texture2D(u_texture, v_texCoords);

	if(glowSize > 0.0)
    {
        vec4 pixel = diffuse;
        if(pixel.a <= glowThreshold)
        {
            vec2 size = glowTexSize;
            float uv_x = v_texCoords.x * size.x;
            float uv_y = v_texCoords.y * size.y;

            float sum = 0.0;
            int num_pass = int(glowPass);
            for (int n = 0; n < num_pass; ++n)
            {
                uv_y = (v_texCoords.y * size.y) + (glowSize * float(float(n) - (glowPass * 0.5)));
                float h_sum = 0.0;
                h_sum += fTexelFetch(u_texture, ivec2(uv_x - (4.0 * glowSize), uv_y));
                h_sum += fTexelFetch(u_texture, ivec2(uv_x - (3.0 * glowSize), uv_y));
                h_sum += fTexelFetch(u_texture, ivec2(uv_x - (2.0 * glowSize), uv_y));
                h_sum += fTexelFetch(u_texture, ivec2(uv_x - glowSize, uv_y));
                h_sum += fTexelFetch(u_texture, ivec2(uv_x, uv_y));
                h_sum += fTexelFetch(u_texture, ivec2(uv_x + glowSize, uv_y));
                h_sum += fTexelFetch(u_texture, ivec2(uv_x + (2.0 * glowSize), uv_y));
                h_sum += fTexelFetch(u_texture, ivec2(uv_x + (3.0 * glowSize), uv_y));
                h_sum += fTexelFetch(u_texture, ivec2(uv_x + (4.0 * glowSize), uv_y));
                sum += h_sum / glowPass;
            }

            float v = (sum / 9.0) * glowIntensity;
            pixel = vec4(glowColor, v);
        }

        diffuse = mix(diffuse, pixel, 1.0);
    }

	gl_FragColor = v_color * diffuse;
}
