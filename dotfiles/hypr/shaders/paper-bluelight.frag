// /home/peeru/.config/hypr/shaders/paper+bluelight.frag

#version 320 es
precision highp float;

// ----------------------------------------------------
// Paper config (values unchanged)
// ----------------------------------------------------
#ifndef PAPER_GRAYSCALE
#define PAPER_GRAYSCALE 0.
#endif
#ifndef PAPER_CONTRAST
#define PAPER_CONTRAST 0.8
#endif
#ifndef PAPER_BRIGHTNESS
#define PAPER_BRIGHTNESS 0.0
#endif
#ifndef PAPER_SEPIA
#define PAPER_SEPIA 0.3
#endif
#ifndef PAPER_GRAIN
#define PAPER_GRAIN 0.0
#endif

// ----------------------------------------------------
// Blue light config (values unchanged)
// ----------------------------------------------------
#ifndef BLUE_LIGHT_FILTER_TEMPERATURE
#define BLUE_LIGHT_FILTER_TEMPERATURE 5500.
#endif
#ifndef BLUE_LIGHT_FILTER_INTENSITY
#define BLUE_LIGHT_FILTER_INTENSITY 1.
#endif

const float TEMPERATURE = BLUE_LIGHT_FILTER_TEMPERATURE;
const float INTENSITY   = BLUE_LIGHT_FILTER_INTENSITY;

// ----------------------------------------------------

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// Paper grain (Intel-friendly random function)
float paper_grain(vec2 uv){
// use mediump internally for perf
mediump float g = fract(sin(dot(uv * 800.0, vec2(12.9898, 78.233))) * 43758.5453);
return g * 0.12 - 0.06;
}

// Convert to sepia (unchanged math)
vec3 to_sepia(vec3 c){
float r = dot(c, vec3(.393, .769, .189));
float g = dot(c, vec3(.349, .686, .168));
float b = dot(c, vec3(.272, .534, .131));
return vec3(r,g,b);
}

// Color temp → RGB, Intel safe
vec3 colorTemperatureToRGB(float t){


// force float literals for Mesa
mat3 m = (t <= 6500.0) ?
    mat3(
        vec3(0.0, float(-2902.195537), float(-8257.799728)),
        vec3(0.0, float(1669.580356), float(2575.282753)),
        vec3(1.0, float(1.33026737), float(1.89937539))
    )
    :
    mat3(
        vec3(float(1745.042530), float(1216.616836), float(-8257.799728)),
        vec3(float(-2666.347422), float(-2173.101234), float(2575.282753)),
        vec3(float(0.55995389), float(0.70381203), float(1.89937539))
    );

vec3 tt = vec3(clamp(t, 1000.0, 40000.0));

return mix(
    clamp(vec3(m[0] / (tt + m[1]) + m[2]), vec3(0.0), vec3(1.0)),
    vec3(1.0),
    smoothstep(1000.0, 0.0, t)
);


}

// ----------------------------------------------------

void main(){
vec4 pixColor = texture(tex, v_texcoord);


float gray = dot(pixColor.rgb, vec3(.299, .587, .114));
vec3 colorResult;

if(PAPER_GRAYSCALE < 0.0){
    float vibrance = -PAPER_GRAYSCALE;
    float avg = (pixColor.r + pixColor.g + pixColor.b) / 3.0;
    colorResult = pixColor.rgb + (pixColor.rgb - vec3(avg)) * vibrance;
    colorResult = clamp(colorResult, 0.0, 1.0);
} else {
    colorResult = mix(pixColor.rgb, vec3(gray), PAPER_GRAYSCALE);
}

// contrast + brightness
colorResult = colorResult * PAPER_CONTRAST + PAPER_BRIGHTNESS;
colorResult = clamp(colorResult, 0.0, 1.0);

// sepia blend
colorResult = mix(colorResult, to_sepia(colorResult), PAPER_SEPIA);

// grain
float g = paper_grain(v_texcoord);
colorResult = clamp(colorResult + g * PAPER_GRAIN, 0.0, 1.0);

// highlight compression
colorResult = min(colorResult, vec3(0.88));

// blue light
colorResult = mix(colorResult, colorResult * colorTemperatureToRGB(TEMPERATURE), INTENSITY);

fragColor = vec4(colorResult, pixColor.a);


}