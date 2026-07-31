#version 300 es
/*
 * Grayscale Shader
 *
 * Override any of the values below from a grayscale.inc file.
 */

#ifndef GRAYSCALE_LUMINOSITY_PAL
#define GRAYSCALE_LUMINOSITY_PAL 0
#endif

#ifndef GRAYSCALE_LUMINOSITY_HDT
#define GRAYSCALE_LUMINOSITY_HDT 1
#endif

#ifndef GRAYSCALE_LUMINOSITY_HDR
#define GRAYSCALE_LUMINOSITY_HDR 2
#endif

#ifndef GRAYSCALE_LIGHTNESS
#define GRAYSCALE_LIGHTNESS 1
#endif

#ifndef GRAYSCALE_AVERAGE
#define GRAYSCALE_AVERAGE 2
#endif

#ifndef GRAYSCALE_LUMINOSITY
#define GRAYSCALE_LUMINOSITY 0
#endif

precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;

/*
 * Grayscale algorithm.
 *
 * 0 = Luminosity
 * 1 = Lightness
 * 2 = Average
 */
const int TYPE = GRAYSCALE_LUMINOSITY;

/*
 * Luminosity coefficients.
 *
 * 0 = PAL
 * 1 = HDTV
 * 2 = HDR
 */
const int LUMA_TYPE = GRAYSCALE_LUMINOSITY_HDT;

float grayscale(vec3 color)
{
    if (TYPE == GRAYSCALE_LUMINOSITY)
    {
        vec3 weights;

        if (LUMA_TYPE == GRAYSCALE_LUMINOSITY_PAL)
        {
            weights = vec3(0.2990, 0.5870, 0.1140);
        }
        else if (LUMA_TYPE == GRAYSCALE_LUMINOSITY_HDT)
        {
            weights = vec3(0.2126, 0.7152, 0.0722);
        }
        else
        {
            weights = vec3(0.2627, 0.6780, 0.0593);
        }

        return dot(color, weights);
    }

    if (TYPE == GRAYSCALE_LIGHTNESS)
    {
        float maxValue = max(max(color.r, color.g), color.b);
        float minValue = min(min(color.r, color.g), color.b);

        return (maxValue + minValue) * 0.5;
    }

    if (TYPE == GRAYSCALE_AVERAGE)
    {
        return (color.r + color.g + color.b) / 3.0;
    }

    // Safety fallback.
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void main()
{
    vec4 pixel = texture(tex, v_texcoord);

    float gray = grayscale(pixel.rgb);

    fragColor = vec4(vec3(gray), pixel.a);
}