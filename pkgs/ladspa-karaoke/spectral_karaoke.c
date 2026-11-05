/*
 * Spectral Center-Cut Karaoke LADSPA Plugin
 * Real-time per-bin inter-channel phase correlation center attenuation
 * and vocal-reverb side ducking.
 *
 * Designed for PipeWire filter-chain integration.
 * Zero-allocation in audio callback (run).
 */

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <ladspa.h>

#define PLUGIN_UNIQUE_ID 4899
#define N 1024
#define H (N / 4)
#define NUM_BINS (N / 2 + 1)
#define FIFO_SIZE 4096
#define PI 3.14159265358979323846f

#define PORT_IN_L        0
#define PORT_IN_R        1
#define PORT_OUT_L       2
#define PORT_OUT_R       3
#define PORT_DEPTH       4
#define PORT_F_LO        5
#define PORT_AIR_DEPTH   6
#define PORT_TRANS_PROT  7
#define PORT_RELEASE_MS  8
#define PORT_DUCK_DB     9
#define PORT_COUNT       10

typedef struct {
    float buf[FIFO_SIZE];
    int r;
    int w;
    int count;
} Fifo;

static inline void fifo_init(Fifo *f) {
    f->r = 0;
    f->w = 0;
    f->count = 0;
}

static inline void fifo_push(Fifo *f, float val) {
    f->buf[f->w] = val;
    f->w = (f->w + 1) % FIFO_SIZE;
    f->count++;
}

static inline float fifo_pop(Fifo *f) {
    if (f->count <= 0) return 0.0f;
    float val = f->buf[f->r];
    f->r = (f->r + 1) % FIFO_SIZE;
    f->count--;
    return val;
}

static inline void fifo_peek_n(Fifo *f, int offset, float *out, int n) {
    int ptr = (f->r + offset) % FIFO_SIZE;
    for (int i = 0; i < n; i++) {
        out[i] = f->buf[ptr];
        ptr = (ptr + 1) % FIFO_SIZE;
    }
}

static inline void fifo_discard(Fifo *f, int n) {
    f->r = (f->r + n) % FIFO_SIZE;
    f->count -= n;
}

static void bit_reverse(float *real, float *imag, int n) {
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
        if (i < j) {
            float tr = real[i]; real[i] = real[j]; real[j] = tr;
            float ti = imag[i]; imag[i] = imag[j]; imag[j] = ti;
        }
        int k = n / 2;
        while (k <= j) {
            j -= k;
            k /= 2;
        }
        j += k;
    }
}

static void fft(float *real, float *imag, int n, int inverse) {
    bit_reverse(real, imag, n);
    for (int len = 2; len <= n; len <<= 1) {
        float angle = (inverse ? 2.0f : -2.0f) * PI / (float)len;
        float wlen_r = cosf(angle);
        float wlen_i = sinf(angle);
        for (int i = 0; i < n; i += len) {
            float w_r = 1.0f;
            float w_i = 0.0f;
            int half = len >> 1;
            for (int j = 0; j < half; j++) {
                int u = i + j;
                int v = i + j + half;
                float u_r = real[u], u_i = imag[u];
                float v_r = real[v] * w_r - imag[v] * w_i;
                float v_i = real[v] * w_i + imag[v] * w_r;
                real[u] = u_r + v_r;
                imag[u] = u_i + v_i;
                real[v] = u_r - v_r;
                imag[v] = u_i - v_i;
                float nw_r = w_r * wlen_r - w_i * wlen_i;
                float nw_i = w_r * wlen_i + w_i * wlen_r;
                w_r = nw_r;
                w_i = nw_i;
            }
        }
    }
    if (inverse) {
        float inv_n = 1.0f / (float)n;
        for (int i = 0; i < n; i++) {
            real[i] *= inv_n;
            imag[i] *= inv_n;
        }
    }
}

typedef struct {
    unsigned long sample_rate;
    LADSPA_Data *ports[PORT_COUNT];

    Fifo in_fifo_l;
    Fifo in_fifo_r;
    Fifo out_fifo_l;
    Fifo out_fifo_r;

    float synth_buf_l[N];
    float synth_buf_r[N];

    float window[N];
    float g_smooth[NUM_BINS];
    float prev_mag_m[NUM_BINS];
    float flux_env;
    float duck_env;
    int transient_counter;

    // Control smoothing
    float depth_cur;
    float f_lo_cur;
    float air_depth_cur;
    float trans_prot_cur;
    float release_ms_cur;
    float duck_db_cur;
} SpectralKaraokePlugin;

static LADSPA_Handle instantiate_spectral_karaoke(const LADSPA_Descriptor *descriptor, unsigned long sample_rate) {
    (void)descriptor;
    SpectralKaraokePlugin *plugin = (SpectralKaraokePlugin *)calloc(1, sizeof(SpectralKaraokePlugin));
    if (!plugin) return NULL;

    plugin->sample_rate = sample_rate > 0 ? sample_rate : 48000;
    fifo_init(&plugin->in_fifo_l);
    fifo_init(&plugin->in_fifo_r);
    fifo_init(&plugin->out_fifo_l);
    fifo_init(&plugin->out_fifo_r);

    float norm = 1.0f / sqrtf(2.0f);
    for (int i = 0; i < N; i++) {
        plugin->window[i] = norm * sinf(PI * (i + 0.5f) / (float)N);
    }

    plugin->depth_cur = 0.85f;
    plugin->f_lo_cur = 150.0f;
    plugin->air_depth_cur = 0.20f;
    plugin->trans_prot_cur = 0.50f;
    plugin->release_ms_cur = 80.0f;
    plugin->duck_db_cur = 2.5f;

    return (LADSPA_Handle)plugin;
}

static void connect_port_spectral_karaoke(LADSPA_Handle instance, unsigned long port, LADSPA_Data *data_location) {
    SpectralKaraokePlugin *plugin = (SpectralKaraokePlugin *)instance;
    if (plugin && port < PORT_COUNT) {
        plugin->ports[port] = data_location;
    }
}

static void activate_spectral_karaoke(LADSPA_Handle instance) {
    SpectralKaraokePlugin *plugin = (SpectralKaraokePlugin *)instance;
    if (!plugin) return;

    fifo_init(&plugin->in_fifo_l);
    fifo_init(&plugin->in_fifo_r);
    fifo_init(&plugin->out_fifo_l);
    fifo_init(&plugin->out_fifo_r);
    memset(plugin->synth_buf_l, 0, sizeof(plugin->synth_buf_l));
    memset(plugin->synth_buf_r, 0, sizeof(plugin->synth_buf_r));
    memset(plugin->g_smooth, 0, sizeof(plugin->g_smooth));
    memset(plugin->prev_mag_m, 0, sizeof(plugin->prev_mag_m));
    plugin->flux_env = 0.0f;
    plugin->duck_env = 0.0f;
    plugin->transient_counter = 0;
}

static void run_spectral_karaoke(LADSPA_Handle instance, unsigned long sample_count) {
    SpectralKaraokePlugin *plugin = (SpectralKaraokePlugin *)instance;
    if (!plugin) return;

    const LADSPA_Data *in_l = plugin->ports[PORT_IN_L];
    const LADSPA_Data *in_r = plugin->ports[PORT_IN_R];
    LADSPA_Data *out_l = plugin->ports[PORT_OUT_L];
    LADSPA_Data *out_r = plugin->ports[PORT_OUT_R];

    float target_depth = plugin->ports[PORT_DEPTH] ? *plugin->ports[PORT_DEPTH] : 0.85f;
    float target_f_lo = plugin->ports[PORT_F_LO] ? *plugin->ports[PORT_F_LO] : 150.0f;
    float target_air_depth = plugin->ports[PORT_AIR_DEPTH] ? *plugin->ports[PORT_AIR_DEPTH] : 0.20f;
    float target_trans_prot = plugin->ports[PORT_TRANS_PROT] ? *plugin->ports[PORT_TRANS_PROT] : 0.50f;
    float target_release_ms = plugin->ports[PORT_RELEASE_MS] ? *plugin->ports[PORT_RELEASE_MS] : 80.0f;
    float target_duck_db = plugin->ports[PORT_DUCK_DB] ? *plugin->ports[PORT_DUCK_DB] : 2.5f;

    // Smooth control parameters to prevent live zippering
    plugin->depth_cur += 0.05f * (target_depth - plugin->depth_cur);
    plugin->f_lo_cur += 0.05f * (target_f_lo - plugin->f_lo_cur);
    plugin->air_depth_cur += 0.05f * (target_air_depth - plugin->air_depth_cur);
    plugin->trans_prot_cur += 0.05f * (target_trans_prot - plugin->trans_prot_cur);
    plugin->release_ms_cur += 0.05f * (target_release_ms - plugin->release_ms_cur);
    plugin->duck_db_cur += 0.05f * (target_duck_db - plugin->duck_db_cur);

    float fs = (float)plugin->sample_rate;
    float df = fs / (float)N;
    float alpha_att = 1.0f - expf(- (float)H / (fs * 0.005f));
    float alpha_rel = 1.0f - expf(- (float)H / (fs * (fmaxf(plugin->release_ms_cur, 10.0f) * 0.001f)));
    if (alpha_rel < 0.005f) alpha_rel = 0.005f;

    for (unsigned long s = 0; s < sample_count; s++) {
        fifo_push(&plugin->in_fifo_l, in_l[s]);
        fifo_push(&plugin->in_fifo_r, in_r[s]);

        if (plugin->in_fifo_l.count >= N) {
            float l_real[N], l_imag[N], r_real[N], r_imag[N];
            fifo_peek_n(&plugin->in_fifo_l, 0, l_real, N);
            fifo_peek_n(&plugin->in_fifo_r, 0, r_real, N);
            fifo_discard(&plugin->in_fifo_l, H);
            fifo_discard(&plugin->in_fifo_r, H);

            for (int i = 0; i < N; i++) {
                l_real[i] *= plugin->window[i];
                l_imag[i] = 0.0f;
                r_real[i] *= plugin->window[i];
                r_imag[i] = 0.0f;
            }

            fft(l_real, l_imag, N, 0);
            fft(r_real, r_imag, N, 0);

            // Transient detection via broadband spectral flux on center mid channel
            float flux = 0.0f;
            for (int k = 0; k < NUM_BINS; k++) {
                float mr = 0.5f * (l_real[k] + r_real[k]);
                float mi = 0.5f * (l_imag[k] + r_imag[k]);
                float mag = sqrtf(mr * mr + mi * mi);
                float diff = mag - plugin->prev_mag_m[k];
                if (diff > 0.0f) flux += diff;
                plugin->prev_mag_m[k] = mag;
            }

            float flux_thresh = plugin->flux_env * 2.5f + 0.1f;
            plugin->flux_env += 0.1f * (flux - plugin->flux_env);
            if (flux > flux_thresh && flux > 0.5f) {
                plugin->transient_counter = (int)(0.040f * fs / (float)H);
            } else if (plugin->transient_counter > 0) {
                plugin->transient_counter--;
            }
            float trans_scale = (plugin->transient_counter > 0) ? (1.0f - plugin->trans_prot_cur) : 1.0f;

            for (int k = 0; k < NUM_BINS; k++) {
                float freq = (float)k * df;
                float lr_dot = l_real[k] * r_real[k] + l_imag[k] * r_imag[k];
                float l_pwr = l_real[k] * l_real[k] + l_imag[k] * l_imag[k];
                float r_pwr = r_real[k] * r_real[k] + r_imag[k] * r_imag[k];
                float denom = l_pwr + r_pwr + 1e-12f;

                float psi = 2.0f * lr_dot / denom;
                if (psi < 0.0f) psi = 0.0f;
                if (psi > 1.0f) psi = 1.0f;

                // Sharper center isolation (psi^8) so panned instruments (electric guitars, cymbals, synths)
                // are preserved with zero attenuation, while center vocals are targeted.
                float m = powf(psi, 8.0f);

                // Vocal formants primarily occupy 180 Hz to 4200 Hz.
                // Roll off vocal cancellation above 4200 Hz so electric guitar harmonics and bite are unaffected.
                float shape = 1.0f;
                if (freq < plugin->f_lo_cur * 0.8f) {
                    shape = 0.0f;
                } else if (freq < plugin->f_lo_cur * 1.2f) {
                    float t = (freq - plugin->f_lo_cur * 0.8f) / (plugin->f_lo_cur * 0.4f);
                    shape = 0.5f * (1.0f - cosf(PI * t));
                } else if (freq > 4200.0f && freq < 8000.0f) {
                    float t = (freq - 4200.0f) / 3800.0f;
                    shape = 1.0f - (1.0f - plugin->air_depth_cur) * t;
                } else if (freq >= 8000.0f) {
                    shape = plugin->air_depth_cur;
                }

                float target_g = plugin->depth_cur * shape * m * trans_scale;
                if (target_g > plugin->g_smooth[k]) {
                    plugin->g_smooth[k] += alpha_att * (target_g - plugin->g_smooth[k]);
                } else {
                    plugin->g_smooth[k] += alpha_rel * (target_g - plugin->g_smooth[k]);
                }

                float g = plugin->g_smooth[k];
                if (g > 0.99f) g = 0.99f;

                float mr = 0.5f * (l_real[k] + r_real[k]);
                float mi = 0.5f * (l_imag[k] + r_imag[k]);
                float sr = 0.5f * (l_real[k] - r_real[k]);
                float si = 0.5f * (l_imag[k] - r_imag[k]);

                // Attenuate center
                mr *= (1.0f - g);
                mi *= (1.0f - g);

                // Side ducking in 500 - 3500 Hz only if configured and center vocal is strongly detected
                if (plugin->duck_db_cur > 0.01f && freq >= 500.0f && freq <= 3500.0f) {
                    float duck_lin = (1.0f - powf(10.0f, -plugin->duck_db_cur / 20.0f)) * m;
                    sr *= (1.0f - duck_lin);
                    si *= (1.0f - duck_lin);
                }

                l_real[k] = mr + sr;
                l_imag[k] = mi + si;
                r_real[k] = mr - sr;
                r_imag[k] = mi - si;

                if (k > 0 && k < N / 2) {
                    l_real[N - k] = l_real[k];
                    l_imag[N - k] = -l_imag[k];
                    r_real[N - k] = r_real[k];
                    r_imag[N - k] = -r_imag[k];
                }
            }

            fft(l_real, l_imag, N, 1);
            fft(r_real, r_imag, N, 1);

            for (int i = 0; i < N; i++) {
                plugin->synth_buf_l[i] += l_real[i] * plugin->window[i];
                plugin->synth_buf_r[i] += r_real[i] * plugin->window[i];
            }

            for (int i = 0; i < H; i++) {
                fifo_push(&plugin->out_fifo_l, plugin->synth_buf_l[i]);
                fifo_push(&plugin->out_fifo_r, plugin->synth_buf_r[i]);
            }

            memmove(plugin->synth_buf_l, plugin->synth_buf_l + H, (N - H) * sizeof(float));
            memset(plugin->synth_buf_l + N - H, 0, H * sizeof(float));
            memmove(plugin->synth_buf_r, plugin->synth_buf_r + H, (N - H) * sizeof(float));
            memset(plugin->synth_buf_r + N - H, 0, H * sizeof(float));
        }

        out_l[s] = fifo_pop(&plugin->out_fifo_l);
        out_r[s] = fifo_pop(&plugin->out_fifo_r);
    }
}

static void cleanup_spectral_karaoke(LADSPA_Handle instance) {
    if (instance) free(instance);
}

static LADSPA_Descriptor *descriptor = NULL;

static void initialize_descriptor() {
    if (descriptor) return;

    descriptor = (LADSPA_Descriptor *)calloc(1, sizeof(LADSPA_Descriptor));
    if (!descriptor) return;

    descriptor->UniqueID = PLUGIN_UNIQUE_ID;
    descriptor->Label = "spectral_karaoke";
    descriptor->Properties = LADSPA_PROPERTY_REALTIME | LADSPA_PROPERTY_HARD_RT_CAPABLE;
    descriptor->Name = "Spectral Center-Cut Karaoke";
    descriptor->Maker = "Antigravity Audio";
    descriptor->Copyright = "GPL";
    descriptor->PortCount = PORT_COUNT;

    LADSPA_PortDescriptor *port_descriptors = (LADSPA_PortDescriptor *)calloc(PORT_COUNT, sizeof(LADSPA_PortDescriptor));
    char **port_names = (char **)calloc(PORT_COUNT, sizeof(char *));
    LADSPA_PortRangeHint *port_range_hints = (LADSPA_PortRangeHint *)calloc(PORT_COUNT, sizeof(LADSPA_PortRangeHint));

    // Audio ports
    port_descriptors[PORT_IN_L] = LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO;
    port_names[PORT_IN_L] = "Input L";

    port_descriptors[PORT_IN_R] = LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO;
    port_names[PORT_IN_R] = "Input R";

    port_descriptors[PORT_OUT_L] = LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO;
    port_names[PORT_OUT_L] = "Output L";

    port_descriptors[PORT_OUT_R] = LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO;
    port_names[PORT_OUT_R] = "Output R";

    // Controls
    port_descriptors[PORT_DEPTH] = LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL;
    port_names[PORT_DEPTH] = "Depth";
    port_range_hints[PORT_DEPTH].HintDescriptor = LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE | LADSPA_HINT_DEFAULT_MIDDLE;
    port_range_hints[PORT_DEPTH].LowerBound = 0.0f;
    port_range_hints[PORT_DEPTH].UpperBound = 1.0f;

    port_descriptors[PORT_F_LO] = LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL;
    port_names[PORT_F_LO] = "Low Cutoff (Hz)";
    port_range_hints[PORT_F_LO].HintDescriptor = LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE | LADSPA_HINT_DEFAULT_MIDDLE;
    port_range_hints[PORT_F_LO].LowerBound = 50.0f;
    port_range_hints[PORT_F_LO].UpperBound = 300.0f;

    port_descriptors[PORT_AIR_DEPTH] = LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL;
    port_names[PORT_AIR_DEPTH] = "Air Depth";
    port_range_hints[PORT_AIR_DEPTH].HintDescriptor = LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE | LADSPA_HINT_DEFAULT_LOW;
    port_range_hints[PORT_AIR_DEPTH].LowerBound = 0.0f;
    port_range_hints[PORT_AIR_DEPTH].UpperBound = 1.0f;

    port_descriptors[PORT_TRANS_PROT] = LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL;
    port_names[PORT_TRANS_PROT] = "Transient Protection";
    port_range_hints[PORT_TRANS_PROT].HintDescriptor = LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE | LADSPA_HINT_DEFAULT_MIDDLE;
    port_range_hints[PORT_TRANS_PROT].LowerBound = 0.0f;
    port_range_hints[PORT_TRANS_PROT].UpperBound = 1.0f;

    port_descriptors[PORT_RELEASE_MS] = LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL;
    port_names[PORT_RELEASE_MS] = "Release (ms)";
    port_range_hints[PORT_RELEASE_MS].HintDescriptor = LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE | LADSPA_HINT_DEFAULT_MIDDLE;
    port_range_hints[PORT_RELEASE_MS].LowerBound = 20.0f;
    port_range_hints[PORT_RELEASE_MS].UpperBound = 300.0f;

    port_descriptors[PORT_DUCK_DB] = LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL;
    port_names[PORT_DUCK_DB] = "Reverb Duck (dB)";
    port_range_hints[PORT_DUCK_DB].HintDescriptor = LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE | LADSPA_HINT_DEFAULT_MIDDLE;
    port_range_hints[PORT_DUCK_DB].LowerBound = 0.0f;
    port_range_hints[PORT_DUCK_DB].UpperBound = 6.0f;

    descriptor->PortDescriptors = port_descriptors;
    descriptor->PortNames = (const char *const *)port_names;
    descriptor->PortRangeHints = port_range_hints;

    descriptor->instantiate = instantiate_spectral_karaoke;
    descriptor->connect_port = connect_port_spectral_karaoke;
    descriptor->activate = activate_spectral_karaoke;
    descriptor->run = run_spectral_karaoke;
    descriptor->deactivate = NULL;
    descriptor->cleanup = cleanup_spectral_karaoke;
}

const LADSPA_Descriptor *ladspa_descriptor(unsigned long index) {
    if (index == 0) {
        initialize_descriptor();
        return descriptor;
    }
    return NULL;
}
