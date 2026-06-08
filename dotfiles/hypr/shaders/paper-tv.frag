#version 300 es
#define HYPRLAND_HOOK debug:damage_tracking 1
precision highp float;

// =============================
// Paper config (unchanged)
// =============================
#ifndef PAPER_GRAYSCALE
#define PAPER_GRAYSCALE 0.
#endif
#ifndef PAPER_CONTRAST
#define PAPER_CONTRAST 0.8
#endif
#ifndef PAPER_BRIGHTNESS
#define PAPER_BRIGHTNESS 0.
#endif
#ifndef PAPER_SEPIA
#define PAPER_SEPIA 0.3
#endif
#ifndef PAPER_GRAIN
#define PAPER_GRAIN 0.0
#endif

// =============================
// Blue light config (unchanged)
// =============================
#ifndef BLUE_LIGHT_FILTER_TEMPERATURE
#define BLUE_LIGHT_FILTER_TEMPERATURE 5500.
#endif
#ifndef BLUE_LIGHT_FILTER_INTENSITY
#define BLUE_LIGHT_FILTER_INTENSITY 1.
#endif

const float TEMPERATURE = BLUE_LIGHT_FILTER_TEMPERATURE;
const float INTENSITY   = BLUE_LIGHT_FILTER_INTENSITY;

// =============================
// CRT config (unchanged style)
// =============================
const float CURVATURE        = 4.8;
const float SCANLINE_STRENGTH = 0.0;
const float SCANLINE_COUNT    = 540.0;
const float ABERRATION        = 0.00;
const float VIGNETTE_RADIUS   = 2.0;
const float VIGNETTE_SOFTNESS = 0.65;
const float GLOW              = 0.0;

// =============================

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// Paper grain
float paper_grain(vec2 uv){
mediump float g = fract(sin(dot(uv * 800.0, vec2(12.9898,78.233))) * 43758.5453);
return g * 0.12 - 0.06;
}

vec3 to_sepia(vec3 c){
float r = dot(c, vec3(.393,.769,.189));
float g = dot(c, vec3(.349,.686,.168));
float b = dot(c, vec3(.272,.534,.131));
return vec3(r,g,b);
}

vec3 colorTemperatureToRGB(float t){


mat3 m = (t <= 6500.0) ?
    mat3(
        vec3(0.0, -2902.195537, -8257.799728),
        vec3(0.0, 1669.580356, 2575.282753),
        vec3(1.0, 1.33026737, 1.89937539)
    )
    :
    mat3(
        vec3(1745.042530, 1216.616836, -8257.799728),
        vec3(-2666.347422, -2173.101234, 2575.282753),
        vec3(0.55995389, 0.70381203, 1.89937539)
    );

vec3 tt = vec3(clamp(t, 1000.0, 40000.0));
return mix(
    clamp(vec3(m[0] / (tt + m[1]) + m[2]), vec3(0.0), vec3(1.0)),
    vec3(1.0),
    smoothstep(1000.0, 0.0, t)
);


}

// CRT curvature
vec2 crtCurve(vec2 uv){
vec2 p = uv * 2.0 - 1.0;
vec2 off = abs(p.yx) / vec2(CURVATURE);
p += p * off * off;
return p * 0.5 + 0.5;
}

void main(){
vec2 uv0 = v_texcoord;


// Apply CRT curvature (keeps the real geometry curve you wanted)
vec2 uv = crtCurve(uv0);

// === ZOOM FIX (compensates CRT empty corners) ===


float ZOOM = 1.015; // try 1.08 → 1.20
uv = (uv - 0.5) / ZOOM + 0.5;


// chromatic aberration (FIXED: The G channel is now safely clamped so it doesn't break at the screen edges!)
vec2 cd = uv - 0.5;
float r = texture(tex, clamp(uv + cd * ABERRATION, 0.0, 1.0)).r;
float g = texture(tex, clamp(uv, 0.0, 1.0)).g;
float b = texture(tex, clamp(uv - cd * ABERRATION, 0.0, 1.0)).b;
vec3 col = vec3(r,g,b);

// scanlines (unchanged)
float phase = uv.y * SCANLINE_COUNT * 2.0;
float sl = smoothstep(0.0,1.0,abs(fract(phase)-0.5)*2.0);
col = col * (1.0 - (SCANLINE_STRENGTH * (1.0 - sl))) + GLOW * (1.0 - sl);

// vignette
float dist = length((uv - 0.5) * 2.0);
col *= 1.0 - smoothstep(VIGNETTE_RADIUS, VIGNETTE_RADIUS+VIGNETTE_SOFTNESS, dist);

// highlight compression
col *= 1.1;

// === PAPER PASS (unchanged) ===
float gray = dot(col, vec3(.299,.587,.114));
if(PAPER_GRAYSCALE < 0.0){
    float vibr = -PAPER_GRAYSCALE;
    float avg = (col.r+col.g+col.b)/3.0;
    col += (col - vec3(avg)) * vibr;
    col = clamp(col, 0.0, 1.0);
} else {
    col = mix(col, vec3(gray), PAPER_GRAYSCALE);
}

col = col * PAPER_CONTRAST + PAPER_BRIGHTNESS;
col = clamp(col, 0.0, 1.0);

col = mix(col, to_sepia(col), PAPER_SEPIA);

float grain = paper_grain(uv0);
col = clamp(col + grain * PAPER_GRAIN, 0.0, 1.0);

col = min(col, vec3(0.88));

col = mix(col, col * colorTemperatureToRGB(TEMPERATURE), INTENSITY);

fragColor = vec4(col, 1.0);


}
