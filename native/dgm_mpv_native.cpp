/* 
 * dgm_mpv_native.cpp - cutscene backend for Switch-Funkin (switch target)
 *
 * mpv render glue (EGL/GLES FBO), and an ffmpeg to OpenAL audio
 * streaming thread. Kept OUT of Haxe so this heavy translation unit
 * only recompiles when this file changes. It is added to the hxcpp
 * build from SwitchVideo.hx via @:buildXml.
 *
 * Functions are extern (non-static) and are declared in the generated
 * SwitchVideo.cpp so Haxe can call them across TUs.
 */
#ifdef __SWITCH__
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>

#include <EGL/egl.h>
#include <GLES2/gl2.h>

#include "mpv/client.h"
#include "mpv/render.h"
#include "mpv/render_gl.h"

static void *dgm_mpv_gl_get_proc_address(void *ctx, const char *name)
{
	return (void *)eglGetProcAddress(name);
}

extern void *dgm_mpv_render_context_create(void *mpv, int *error)
{
	mpv_opengl_init_params gl_init = {dgm_mpv_gl_get_proc_address, 0};
	mpv_render_param params[] = {
		{MPV_RENDER_PARAM_API_TYPE, (void *)MPV_RENDER_API_TYPE_OPENGL},
		{MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init},
		{0, 0}
	};
	mpv_render_context *ctx = 0;
	int rc = mpv_render_context_create(&ctx, (mpv_handle *)mpv, params);
	if (error)
		*error = rc;
	return (void *)ctx;
}

extern int dgm_mpv_render_context_update(void *ctx)
{
	if (ctx)
		return mpv_render_context_update((mpv_render_context *)ctx);
	return 0;
}

extern void dgm_mpv_render_frame(void *ctx, int fbo, int w, int h)
{
	mpv_opengl_fbo fbo_info = {fbo, w, h, 0};
	int flip = 0;
	mpv_render_param params[] = {
		{MPV_RENDER_PARAM_OPENGL_FBO, &fbo_info},
		{MPV_RENDER_PARAM_FLIP_Y, &flip},
		{0, 0}
	};
	mpv_render_context_render((mpv_render_context *)ctx, params);
}

extern void dgm_mpv_render_context_free(void *ctx)
{
	if (ctx)
		mpv_render_context_free((mpv_render_context *)ctx);
}

extern int dgm_mpv_loadfile(void *ctx, const char *path)
{
	const char *args[] = {"loadfile", path, NULL};
	return mpv_command((mpv_handle *)ctx, args);
}

extern void dgm_mpv_set_double(void *ctx, const char *name, double v)
{
	mpv_set_property((mpv_handle *)ctx, name, MPV_FORMAT_DOUBLE, &v);
}

extern int dgm_mpv_get_int(void *ctx, const char *name)
{
	int64_t v = 0;
	if (mpv_get_property((mpv_handle *)ctx, name, MPV_FORMAT_INT64, &v) >= 0)
		return (int)v;
	return 0;
}

extern double dgm_mpv_get_double(void *ctx, const char *name)
{
	double v = 0;
	if (mpv_get_property((mpv_handle *)ctx, name, MPV_FORMAT_DOUBLE, &v) >= 0)
		return v;
	return 0.0;
}

extern int dgm_mpv_get_boolean(void *ctx, const char *name)
{
	int v = 0;
	if (mpv_get_property((mpv_handle *)ctx, name, MPV_FORMAT_FLAG, &v) >= 0)
		return v;
	return 0;
}

extern int dgm_mpv_end_file_reason(const void *event_data)
{
	if (!event_data)
		return -1;
	return ((const mpv_event_end_file *)event_data)->reason;
}

extern int dgm_mpv_event_id(const void *evt)
{
	if (!evt)
		return 0;
	return ((const mpv_event *)evt)->event_id;
}

extern const void *dgm_mpv_event_data(const void *evt)
{
	if (!evt)
		return 0;
	return ((const mpv_event *)evt)->data;
}

extern const char *dgm_mpv_log_message_prefix(const void *data)
{
	if (!data)
		return 0;
	return ((const mpv_event_log_message *)data)->prefix;
}

extern const char *dgm_mpv_log_message_text(const void *data)
{
	if (!data)
		return 0;
	return ((const mpv_event_log_message *)data)->text;
}

extern void dgm_mpv_gl_create_fbo(int *fbo, int *tex, int w, int h)
{
	GLuint t = 0, f = 0;
	glGenTextures(1, &t);
	glBindTexture(GL_TEXTURE_2D, t);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glGenFramebuffers(1, &f);
	glBindFramebuffer(GL_FRAMEBUFFER, f);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, t, 0);
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	*fbo = (int)f;
	*tex = (int)t;
}

extern void dgm_mpv_gl_read_pixels(int fbo, int w, int h, unsigned char *out)
{
	GLint prevFbo = 0;
	GLint prevViewport[4] = {0, 0, 0, 0};
	glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFbo);
	glGetIntegerv(GL_VIEWPORT, prevViewport);
	glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)fbo);
	glViewport(0, 0, w, h);
	glPixelStorei(GL_PACK_ALIGNMENT, 1);
	glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, out);
	glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)prevFbo);
	glViewport(prevViewport[0], prevViewport[1], prevViewport[2], prevViewport[3]);
}

extern void dgm_mpv_gl_delete_fbo(int fbo, int tex)
{
	GLuint f = (GLuint)fbo, t = (GLuint)tex;
	glDeleteFramebuffers(1, &f);
	glDeleteTextures(1, &t);
}

/*
	insurance: clear the default framebuffer so no stale pixels (e.g. a ghost video frame) survive into the next frame/state,
	flixel redraws over it anyway, so this never causes a visible flash.
*/
extern void dgm_mpv_gl_clear_default(void)
{
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
}

// BGRA to RGBA (swap R and B, keeping G and A in place)
extern void dgm_mpv_rgba_to_argb(const unsigned char *src, unsigned char *dst, int pixels)
{
    for (int i = 0; i < pixels; i++)
    {
        dst[i * 4 + 0] = src[i * 4 + 2]; // R <- B (or vice versa)
        dst[i * 4 + 1] = src[i * 4 + 1]; // G stays G
        dst[i * 4 + 2] = src[i * 4 + 0]; // B <- R
        dst[i * 4 + 3] = src[i * 4 + 3]; // A stays A
    }
}

#include <AL/al.h>
#include <AL/alc.h>

/*
	ffmpeg audio decode to openal buffer‑queue streaming
*/
#include <pthread.h>
#include <stdio.h>
#include <time.h>
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswresample/swresample.h>
#include <libavutil/channel_layout.h>
}

#define AO_BUFS 4
#define AO_SAMP 4096
#define AO_IOBUF 32768

static pthread_t aoThread;
static volatile int aoStop = 0;
static int aoAlive = 0;
static ALuint aoSrc = 0;
static ALuint aoBufsInt[AO_BUFS];
static ALuint aoPrimerSrc = 0;
static ALuint aoPrimerBuf = 0;
static ALCcontext *aoCtx = NULL;
static volatile int aoGate = 0;
static volatile int aoReady = 0;

extern void dgm_mpv_audio_stop_func(void);
extern void dgm_mpv_audio_start(const char *cpath);

static int dgm_mpv_ao_interrupt(void *unused)
{
	return aoStop;
}

/*
	custom AVIO: romfs:/ paths are not real URLs, bypass the URL layer
	and read through fopen() like mpv does.
*/
static int dgm_mpv_ao_read(void *opaque, uint8_t *buf, int buf_size)
{
	FILE *f = (FILE *)opaque;
	return (int)fread(buf, 1, buf_size, f);
}

static int64_t dgm_mpv_ao_seek(void *opaque, int64_t offset, int whence)
{
	FILE *f = (FILE *)opaque;
	if (whence == AVSEEK_SIZE)
	{
		long cur = ftell(f);
		if (fseek(f, 0, SEEK_END) != 0)
			return -1;
		long size = ftell(f);
		fseek(f, cur, SEEK_SET);
		return size;
	}
	if (fseek(f, (long)offset, whence) != 0)
		return -1;
	return ftell(f);
}

/*
	decode packets until we get one audio frame, convert to S16 stereo, fill buffer.
	returns 1 on success, 0 on EOF/error.
*/
static int dgm_mpv_ao_fill(AVFormatContext *fmt, AVCodecContext *dec, SwrContext *swr, AVFrame *frm, AVPacket *pkt, int idx, ALuint buf, int16_t *cvt)
{
	for (;;)
	{
		if (avcodec_receive_frame(dec, frm) == 0)
		{
			int n = swr_convert(swr, (uint8_t **)&cvt, AO_SAMP, (const uint8_t **)frm->extended_data, frm->nb_samples);
			if (n > 0)
			{
				ALsizei sz = n * 2 * (int)sizeof(int16_t);
				alBufferData(buf, AL_FORMAT_STEREO16, cvt, sz, 48000);
				{
					ALenum e = alGetError();
					if (e != AL_NO_ERROR)
						printf("[audio] alBufferData buf=%u n=%d bytes=%d err=0x%x\\n", unsigned)buf, n, (int)sz, e);
				}
				return 1;
			}
			continue;
		}
		if (av_read_frame(fmt, pkt) < 0)
		{
			avcodec_send_packet(dec, NULL);
			continue;
		}
		if (pkt->stream_index != idx)
		{
			av_packet_unref(pkt);
			continue;
		}
		avcodec_send_packet(dec, pkt);
		av_packet_unref(pkt);
	}
}

static double aoPosCache = 0;
static void dgm_mpv_ao_start_primer(void);
static void aoStop_primer(void);

static void *dgm_mpv_ao_func(void *arg)
{
	char *path = (char *)arg;

	AVFormatContext *fmt = NULL;
	AVCodecContext *dec = NULL;
	SwrContext *swr = NULL;
	AVFrame *frm = av_frame_alloc();
	AVPacket *pkt = av_packet_alloc();
	int16_t *cvt = NULL;
	int idx = -1;
	const AVCodec *codec = NULL;
	AVChannelLayout out_layout = AV_CHANNEL_LAYOUT_STEREO;
	ALenum err;
	ALint state = 0;
	FILE *file = NULL;
	AVIOContext *avio = NULL;

	printf("[audio] thread started, path=%s ctx=%p\\n", path, aoCtx);

	if (aoCtx)
	{
		if (!alcMakeContextCurrent(aoCtx))
			printf("[audio] alcMakeContextCurrent FAILED: 0x%x\\n", alcGetError(NULL));
		else
		{
			ALCdevice *dev = alcGetContextsDevice(aoCtx);
			const ALCchar *name = dev ? alcGetString(dev, ALC_DEVICE_SPECIFIER) : NULL;
			printf("[audio] context current, device=%s\\n", name ? name : "?");
			dgm_mpv_ao_start_primer();
		}
	}
	else
		printf("[audio] WARNING: no OpenAL context saved\\n");

	file = fopen(path, "rb");
	if (!file)
	{
		printf("[audio] fopen FAILED: %s\\n", path);
		goto end;
	}
	printf("[audio] fopen OK\\n");

	avio = avio_alloc_context((unsigned char *)av_malloc(AO_IOBUF),
		AO_IOBUF, 0, file, dgm_mpv_ao_read, NULL, dgm_mpv_ao_seek);
	if (!avio)
	{
		printf("[audio] avio_alloc_context FAILED\\n");
		goto end;
	}

	fmt = avformat_alloc_context();
	if (!fmt)
	{
		printf("[audio] avformat_alloc_context FAILED\\n");
		goto end;
	}
	fmt->pb = avio;
	fmt->interrupt_callback.callback = dgm_mpv_ao_interrupt;
	{
		int ret = avformat_open_input(&fmt, NULL, NULL, NULL);
		if (ret < 0)
		{
			printf("[audio] avformat_open_input FAILED ret=%d (0x%x)\\n", ret, (unsigned)ret);
			if (fmt)
			{
				avformat_free_context(fmt);
				fmt = NULL;
			}
			avio_context_free(&avio);
			fclose(file);
			file = NULL;
			goto end;
		}
	}
	avio = NULL; // fmt owns the AVIO now
	printf("[audio] avformat_open_input OK\\n");
	if (avformat_find_stream_info(fmt, NULL) < 0)
	{
		printf("[audio] avformat_find_stream_info FAILED\\n");
		goto end;
	}
	printf("[audio] nb_streams=%u\\n", fmt->nb_streams);

	for (unsigned i = 0; i < fmt->nb_streams; i++)
	{
		printf("[audio] stream[%u] type=%d\\n", i, fmt->streams[i]->codecpar->codec_type);
		if (fmt->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO)
		{
			idx = i;
			break;
		}
	}
	if (idx < 0)
	{
		printf("[audio] no audio stream found\\n");
		goto end;
	}

	/*
		discard everything except the audio stream so av_read_frame only
		ever returns audio packets; reading big VP9 video packets was
		slowing the decode loop below real-time.
	*/
	for (unsigned i = 0; i < fmt->nb_streams; i++)
		if ((int)i != idx)
			fmt->streams[i]->discard = AVDISCARD_ALL;

	codec = avcodec_find_decoder(fmt->streams[idx]->codecpar->codec_id);
	if (!codec) 
	{
		printf("[audio] avcodec_find_decoder FAILED\\n");
		goto end;
	}
	printf("[audio] decoder=%s\\n", codec->name);

	dec = avcodec_alloc_context3(codec);
	avcodec_parameters_to_context(dec, fmt->streams[idx]->codecpar);
	if (avcodec_open2(dec, codec, NULL) < 0)
	{
		printf("[audio] avcodec_open2 FAILED\\n");
		goto end;
	}
	printf("[audio] avcodec_open2 OK: %dHz %dch\\n", dec->sample_rate, dec->ch_layout.nb_channels);

	swr = NULL;
	if (swr_alloc_set_opts2(&swr, &out_layout, AV_SAMPLE_FMT_S16, 48000, &dec->ch_layout, dec->sample_fmt, dec->sample_rate, 0, NULL) < 0 || !swr || swr_init(swr) < 0)
	{
		printf("[audio] swr_init FAILED\\n");
		goto end;
	}
	printf("[audio] swr OK\\n");

	cvt = (int16_t *)av_malloc(AO_SAMP * 2 * (int)sizeof(int16_t));

	err = alGetError();
	alGenSources(1, &aoSrc);
	err = alGetError();
	printf("[audio] alGenSources src=%u err=0x%x\\n", aoSrc, err);

	alGenBuffers(AO_BUFS, aoBufsInt);
	err = alGetError();
	printf("[audio] alGenBuffers err=0x%x\\n", err);

	if (aoSrc == 0)
	{
		printf("[audio] FAILED to create AL source\\n");
		goto end;
	}

	// decode + queue in a sliding window, play immediately
	{
		ALuint *bufs = NULL;
		int nbufs = 0, cap = 0;
		int chunk = AO_SAMP;
		int queued = 0;
		int written = 0;
		int eof = 0;

		// queue first 25 buffers and start immediately
		{
			int want = 25;
			for (int tried = 0; tried < 2000 && queued < want && !aoStop; tried++)
			{
				if (avcodec_receive_frame(dec, frm) == 0)
				{
					int n = swr_convert(swr, (uint8_t **)&cvt, chunk, (const uint8_t **)frm->extended_data, frm->nb_samples);
					if (n > 0)
					{
						if (nbufs >= cap)
						{
							int ncap = cap ? cap * 2 : 64;
							ALuint *nb = (ALuint *)realloc(bufs, ncap * sizeof(ALuint));
							if (!nb)
								break;
							bufs = nb; cap = ncap;
						}
						alGenBuffers(1, &bufs[nbufs]);
						alBufferData(bufs[nbufs], AL_FORMAT_STEREO16, cvt, (ALsizei)(n * 2 * sizeof(int16_t)), 48000);
						alSourceQueueBuffers(aoSrc, 1, &bufs[nbufs]);
						nbufs++;
						queued++;
					}
					continue;
				}
				if (av_read_frame(fmt, pkt) < 0)
				{
					avcodec_send_packet(dec, NULL);
					eof = 1;
					break;
				}
				if (pkt->stream_index == idx)
					avcodec_send_packet(dec, pkt);
				av_packet_unref(pkt);
			}
		}

	printf("[audio] initial queue: %d buffers (%.2fs)\\n", queued, (double)queued * chunk / 48000.0);

	// signal the game: decode is ready, please unpause
	aoReady = 1;

		/*
			wait for the video to render its first frame before starting
			playback, so audio and video begin from time 0 together.
		*/
		printf("[audio] waiting for video first frame\\n");
		while (!aoGate && !aoStop)
		{
			{
				struct timespec ts = {0, 10000000};
				nanosleep(&ts, NULL);
			}
		}
		if (aoStop)
		{
			printf("[audio] stopped while waiting for gate\\n");
			goto end;
		}
		printf("[audio] gate open, starting playback\\n");
		aoStop_primer();

		alSourcePlay(aoSrc);
		printf("[audio] alSourcePlay err=0x%x\\n", alGetError());
		{
			ALint st = 0, q = 0, pr = 0;
			alGetSourcei(aoSrc, AL_SOURCE_STATE, &st);
			alGetSourcei(aoSrc, AL_BUFFERS_QUEUED, &q);
			alGetSourcei(aoSrc, AL_BUFFERS_PROCESSED, &pr);
			printf("[audio] after play: state=%d queued=%d processed=%d err=0x%x\\n", st, q, pr, alGetError());
		}

		/*
			keep decoding and appending; the mixer consumes from the front,
			we add to the back. AL_BUFFERS_PROCESSED and AL_SAMPLE_OFFSET
			are broken on Switch openal-soft, so we just decode until EOF
			and wait for the source to finish.
		*/
		int spike = 0;
		while (!aoStop)
		{
			state = 0;
			alGetSourcei(aoSrc, AL_SOURCE_STATE, &state);
			if (state != AL_PLAYING && state != AL_PAUSED)
			{
				ALint q = 0, pr = 0;
				alGetSourcei(aoSrc, AL_BUFFERS_QUEUED, &q);
				alGetSourcei(aoSrc, AL_BUFFERS_PROCESSED, &pr);
				printf("[audio] playback ended: state=%d queued=%d processed=%d err=0x%x\\n", state, q, pr, alGetError());
				break;
			}

			// try to decode more
			if (!eof && avcodec_receive_frame(dec, frm) == 0)
			{
				int n = swr_convert(swr, (uint8_t **)&cvt, chunk,
					(const uint8_t **)frm->extended_data, frm->nb_samples);
				if (n > 0) 
				{
					if (nbufs >= cap)
					{
						int ncap = cap ? cap * 2 : 64;
						ALuint *nb = (ALuint *)realloc(bufs, ncap * sizeof(ALuint));
						if (!nb)
							break;
						bufs = nb; cap = ncap;
					}
					alGenBuffers(1, &bufs[nbufs]);
					alBufferData(bufs[nbufs], AL_FORMAT_STEREO16, cvt, (ALsizei)(n * 2 * sizeof(int16_t)), 48000);
					alSourceQueueBuffers(aoSrc, 1, &bufs[nbufs]);
					{
						ALenum e = alGetError();
						if (e != AL_NO_ERROR)
							printf("[audio] queue path err=0x%x at nbufs=%d\\n", e, nbufs);
					}
					nbufs++;
					queued++;
					if (nbufs % 100 == 0)
						printf("[audio] total=%d queued=%d (%.2fs)\\n", nbufs, queued, (double)queued * chunk / 48000.0);
				}
			}
			else if (!eof)
			{
				if (av_read_frame(fmt, pkt) < 0)
				{
					avcodec_send_packet(dec, NULL);
					eof = 1;
					printf("[audio] decode EOF, total=%d\\n", nbufs);
				}
				else
				{
					if (pkt->stream_index == idx)
						avcodec_send_packet(dec, pkt);
					av_packet_unref(pkt);
				}
			}

			if (++spike % 500 == 0)
			{
				ALint st = 0, q = 0, pr = 0, off = 0;
				ALfloat sec = 0;
				alGetSourcei(aoSrc, AL_SOURCE_STATE, &st);
				alGetSourcei(aoSrc, AL_BUFFERS_QUEUED, &q);
				alGetSourcei(aoSrc, AL_BUFFERS_PROCESSED, &pr);
				alGetSourcei(aoSrc, AL_SAMPLE_OFFSET, &off);
				alGetSourcef(aoSrc, AL_SEC_OFFSET, &sec);
				aoPosCache = (double)sec;
				printf("[audio] tick state=%d queued=%d processed=%d offset=%d pos=%.3f\\n", st, q, pr, off, sec);
			}
			{
				struct timespec ts = {0, 2000000};
				nanosleep(&ts, NULL);
			}
		}

		printf("[audio] done: total=%d\\n", nbufs);
		if (bufs)
		{
			alSourceStop(aoSrc);
			alDeleteSources(1, &aoSrc);
			aoSrc = 0;
			alDeleteBuffers(nbufs, bufs);
			free(bufs);
		}
	}

end:
	printf("[audio] cleanup\\n");
	aoStop_primer();
	if (cvt)
		av_free(cvt);
	if (frm)
		av_frame_free(&frm);
	if (pkt)
		av_packet_free(&pkt);
	if (swr)
		swr_free(&swr);
	if (dec)
		avcodec_free_context(&dec);
	if (fmt)
		avformat_close_input(&fmt);
	if (file)
		fclose(file);
	free(path);
	aoAlive = 0;
	alcMakeContextCurrent(NULL);
	return NULL;
}

extern void dgm_mpv_audio_start(const char *cpath)
{
	printf("[audio] dgm_mpv_audio_start: %s\\n", cpath);
	dgm_mpv_audio_stop_func();
	aoStop = 0;
	aoAlive = 1;
	aoGate = 0;
	aoReady = 0;
	aoCtx = alcGetCurrentContext();
	printf("[audio] saved ctx=%p\\n", aoCtx);
	char *path = (char *)malloc(strlen(cpath) + 1);
	strcpy(path, cpath);
	pthread_create(&aoThread, NULL, dgm_mpv_ao_func, path);
	printf("[audio] thread created\\n");
}

extern void dgm_mpv_audio_gate_open(void)
{
	aoGate = 1;
}

// polled by the game: true once the first audio buffers are queued
extern int dgm_mpv_ao_is_ready(void)
{
	return aoReady;
}

// probe: seconds of audio played, updated by the audio thread
extern double dgm_mpv_ao_get_pos(void)
{
	return aoPosCache;
}

/*
	The switch openal-soft mixer stops consuming buffers if the AL device
	sits idle (no playing source) for a while, the source then stays
	AL_PLAYING forever with AL_BUFFERS_PROCESSED stuck at 0. Keep a
	looping zero-gain silence source alive while we wait for the video
	gate so the device never goes idle.
*/
static void dgm_mpv_ao_start_primer(void)
{
	if (aoPrimerBuf != 0 || aoPrimerSrc != 0)
		return;
	short *sil = (short *)malloc(48000 * 2 * (int)sizeof(short));
	memset(sil, 0, 48000 * 2 * (int)sizeof(short));
	alGenBuffers(1, &aoPrimerBuf);
	alBufferData(aoPrimerBuf, AL_FORMAT_STEREO16, sil,
		48000 * 2 * (int)sizeof(short), 48000);
	free(sil);
	alGenSources(1, &aoPrimerSrc);
	alSourcei(aoPrimerSrc, AL_LOOPING, AL_TRUE);
	alSourcei(aoPrimerSrc, AL_BUFFER, aoPrimerBuf);
	alSourcef(aoPrimerSrc, AL_GAIN, 0.0f);
	alSourcePlay(aoPrimerSrc);
	printf("[audio] primer source playing\\n");
}

static void aoStop_primer(void)
{
	if (aoPrimerSrc != 0)
	{
		alSourceStop(aoPrimerSrc);
		alDeleteSources(1, &aoPrimerSrc);
		aoPrimerSrc = 0;
	}
	if (aoPrimerBuf != 0)
	{
		alDeleteBuffers(1, &aoPrimerBuf);
		aoPrimerBuf = 0;
	}
}

extern void dgm_mpv_audio_stop_func(void)
{
	aoStop = 1;
	if (aoAlive)
		pthread_join(aoThread, NULL);
	aoAlive = 0;
	aoCtx = NULL;
}
#endif