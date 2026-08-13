package dgm.video;

#if switch
import cpp.RawPointer;
import cpp.UInt8;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;
import slushi.SlDebug;
import dgm.mpv.Mpv;
import dgm.util.DebugLog;
#end

/**
 * Wrapper object to maintain compatibility with hxvlc's bitmap API
 * (mirrors slushi.fixes.OpenFLVideoSprite.VideoBitmapWrapper).
 */
class VideoBitmapWrapper
{
	private var owner:SwitchVideo;
	private var _rate:Float = 1.0;

	public var rate(get, set):Float;

	public function new(owner:SwitchVideo)
	{
		this.owner = owner;
	}

	private function get_rate():Float
	{
		return _rate;
	}

	private function set_rate(value:Float):Float
	{
		_rate = value;
		owner.setRate(value);
		return _rate;
	}
}

/**
 * mpv-based video sprite for Nintendo Switch.
 *
 * API-compatible drop-in for "slushi.fixes.OpenFLVideoSprite" and mirrors
 * hxvlc's "FlxVideoSprite" surface (bitmap.rate, onEndReached, onFormatSetup,
 * load/play/pause/resume/stop, setVolume, isPlaying).
 *
 * Renders via mpv's OpenGL ES render API into an FBO, reads the frame back
 * and pushes it into a BitmapData every frame.
 *
 * Compiled ONLY when "DGM_MPV" is defined on the switch target (Project.xml).
 */
@:buildXml('
<files id="haxe">
    <file name="${this_dir}/../../../../native/dgm_mpv_native.cpp" />
</files>
')
@:cppFileCode('
#ifdef __SWITCH__
// native backend, implemented it in native/dgm_native.cpp (see buildXml)
extern void *dgm_mpv_render_context_create(void *mpv, int *error);
extern int dgm_mpv_render_context_update(void *ctx);
extern void dgm_mpv_render_frame(void *ctx, int fbo, int w, int h);
extern void dgm_mpv_render_context_free(void *ctx);
extern int dgm_mpv_loadfile(void *ctx, const char *path);
extern void dgm_mpv_set_double(void *ctx, const char *name, double v);
extern int dgm_mpv_get_int(void *ctx, const char *name);
extern double dgm_mpv_get_double(void *ctx, const char *name);
extern int dgm_mpv_get_boolean(void *ctx, const char *name);
extern int dgm_mpv_end_file_reason(const void *event_data);
extern int dgm_mpv_event_id(const void *evt);
extern const void *dgm_mpv_event_data(const void *evt);
extern const char *dgm_mpv_log_message_prefix(const void *data);
extern const char *dgm_mpv_log_message_text(const void *data);
extern void dgm_mpv_gl_create_fbo(int *fbo, int *tex, int w, int h);
extern void dgm_mpv_gl_read_pixels(int fbo, int w, int h, unsigned char *out);
extern void dgm_mpv_gl_delete_fbo(int fbo, int tex);
extern void dgm_mpv_gl_clear_default(void);
extern void dgm_mpv_rgba_to_argb(const unsigned char *src, unsigned char *dst, int pixels);
extern void dgm_mpv_audio_start(const char *cpath);
extern void dgm_mpv_audio_stop_func(void);
extern void dgm_mpv_audio_gate_open(void);
extern double dgm_mpv_ao_get_pos(void);
extern int dgm_mpv_ao_is_ready(void);
#endif
')
class SwitchVideo extends FlxSprite
{
	#if switch
	public var onFormatSetup:Void->Void;
	public var onEndReached:Void->Void;

	/**
	 * Compatibility wrapper to match hxvlc's bitmap API
	 */
	public var bitmap(default, null):VideoBitmapWrapper;

	private var mpvCtx:RawPointer<cpp.Void> = null;
	private var renderCtx:RawPointer<cpp.Void> = null;
	private var fbo:Int = 0;
	private var texture:Int = 0;
	private var videoBitmapData:BitmapData;
	private var rect:Rectangle;
	private var rgbaBytes:haxe.io.Bytes;
	private var argbBytes:haxe.io.Bytes;
	private var rgbaPtr:RawPointer<UInt8> = null;
	private var argbPtr:RawPointer<UInt8> = null;

	private var _isPlaying:Bool = false;
	private var _isPaused:Bool = false;
	private var _shouldLoop:Bool = false;
	private var _formatReady:Bool = false;
	private var _started:Bool = false;
	private var _stopRequested:Bool = false;
	private var _videoPath:String;
	private var _videoWidth:Int = 0;
	private var _videoHeight:Int = 0;
	private var _volumeAdjust:Float = 1.0;
	private var _rate:Float = 1.0;

	private var resumeOnFocus:Bool = false;
	private var _hasLoggedScreen:Bool = false;
	private var _startWait:Float = 0;
	private var _teardownQueued:Bool = false;

	public var isPlaying(get, never):Bool;

	private function get_isPlaying():Bool
		return _isPlaying && !_isPaused;

	#end

	public function new()
	{
		super();
		#if switch
		bitmap = new VideoBitmapWrapper(this);
		makeGraphic(1, 1, FlxColor.TRANSPARENT);

		if (!FlxG.signals.focusGained.has(onFocusGained))
			FlxG.signals.focusGained.add(onFocusGained);
		if (!FlxG.signals.focusLost.has(onFocusLost))
			FlxG.signals.focusLost.add(onFocusLost);
		#end
	}

	#if switch
	public function load(path:String, ?options:Array<String>):Bool
	{
		DebugLog.log('SwitchVideo.load: path=$path');
		try
		{
			dispose();

			_videoPath = path;
			_shouldLoop = options != null && options.indexOf('input-repeat=65545') != -1;
			_formatReady = false;
			_stopRequested = true;

			mpvCtx = Mpv.create();
			if (mpvCtx == null)
			{
				DebugLog.log('SwitchVideo.load: Mpv.create() returned null');
				return false;
			}

			// SwitchWave style thing setup; hardware decode plus OpenGL render API
			Mpv.setOptionString(mpvCtx, 'vo', 'libmpv');
			Mpv.setOptionString(mpvCtx, 'ao', 'null');
			Mpv.setOptionString(mpvCtx, 'msg-level', 'all=v');
			Mpv.setPropertyString(mpvCtx, 'keepaspect', 'no');
			if (_shouldLoop)
				Mpv.setPropertyString(mpvCtx, 'loop-file', 'inf');

			if (Mpv.initialize(mpvCtx) < 0)
			{
				DebugLog.log('SwitchVideo.load: mpv_initialize FAILED');
				dispose();
				return false;
			}
			DebugLog.log('SwitchVideo.load: mpv_initialize OK');

			Mpv.requestLogMessages(mpvCtx, 'info');

			var err:Int = 0;
			renderCtx = Mpv.renderContextCreate(mpvCtx, RawPointer.addressOf(err));
			if (renderCtx == null)
			{
				DebugLog.log('SwitchVideo.load: render context FAILED (err=$err)');
				dispose();
				return false;
			}
			DebugLog.log('SwitchVideo.load: render context OK');

			if (Mpv.loadfile(mpvCtx, path) < 0)
			{
				DebugLog.log('SwitchVideo.load: loadfile FAILED for "$path"');
				dispose();
				return false;
			}
			DebugLog.log('SwitchVideo.load: loadfile OK, waiting for events');

			// keep the movie clock frozen while mpv prerolls its first fame,
			// the game unpauses when the audio thread reports ready
			Mpv.setPropertyString(mpvCtx, 'pause', 'yes');
			_started = false;

			_stopRequested = false;
			_isPlaying = false;
			_isPaused = false;
			return true;
		}
		catch (e:Dynamic)
		{
			SlDebug.log('dgm.SwitchVideo: load error: $e', ERROR);
			return false;
		}
	}

	public function play():Bool
	{
		if (mpvCtx == null)
			return false;
		#if FLX_SOUND_SYSTEM
		try
		{
			FlxG.sound.play('assets/shared/sounds/confirmMenu.ogg', 1, false);
			DebugLog.log('SwitchVideo.play: played FlxG test beep');
		}
		catch (e:Dynamic)
		{
			DebugLog.log('SwitchVideo.play: FlxG beep FAILED: $e');
		}
		#end
		untyped __cpp__('dgm_audio_start({0}.__CStr())', _videoPath);
		_isPlaying = true;
		_isPaused = false;
		_startWait = 0;
		return true;
	}

	public function pause():Void
	{
		if (mpvCtx != null && _isPlaying)
		{
			Mpv.setPropertyString(mpvCtx, 'pause', 'yes');
			_isPaused = true;
		}
	}

	public function resume():Void
	{
		if (mpvCtx != null && _isPaused)
		{
			Mpv.setPropertyString(mpvCtx, 'pause', 'no');
			_isPaused = false;
		}
	}

	public function stop():Void
	{
		if (mpvCtx != null)
		{
			_stopRequested = true;
			Mpv.commandString(mpvCtx, 'stop');
			_isPlaying = false;
			_isPaused = false;
			_teardownQueued = true;
		}
	}

	public function setRate(value:Float):Void
	{
		_rate = value;
		if (mpvCtx != null)
			Mpv.setDouble(mpvCtx, 'speed', value);
	}

	public function setVolume(volume:Float):Void
	{
		if (mpvCtx != null)
		{
			var mpvVolume:Int = Math.round(Math.max(0, Math.min(100, volume * 100 * _volumeAdjust)));
			Mpv.setPropertyString(mpvCtx, 'volume', Std.string(mpvVolume));
		}
	}

	public function setVolumeAdjust(value:Float):Void
	{
		_volumeAdjust = value;
		#if FLX_SOUND_SYSTEM
		setVolume((FlxG.sound.muted ? 0 : 1) * FlxG.sound.volume);
		#else
		setVolume(1);
		#end
	}

	// hxvlc(-ish) time helpers (ms)
	public var time(get, set):Int;
	public var duration(get, never):Int;
	public var position(get, set):Single;
	public var isSeekable(get, never):Bool;

	private function get_time():Int
		return Math.round(Mpv.getDouble(mpvCtx, 'time-pos') * 1000);

	private function set_time(value:Int):Int
	{
		if (mpvCtx != null)
			Mpv.setDouble(mpvCtx, 'time-pos', value / 1000);
		return value;
	}

	private function get_duration():Int
		return Math.round(Mpv.getDouble(mpvCtx, 'duration') * 1000);

	private function get_position():Single
		return Mpv.getDouble(mpvCtx, 'percent-pos') / 100;

	private function set_position(value:Single):Single
	{
		if (mpvCtx != null)
			Mpv.setDouble(mpvCtx, 'percent-pos', value * 100);
		return value;
	}

	private function get_isSeekable():Bool
		return mpvCtx != null && Mpv.getBoolean(mpvCtx, 'seekable') != 0;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (mpvCtx == null)
			return;

		if (_teardownQueued)
		{
			_teardownQueued = false;
			DebugLog.log('update: running queued teardown');
			dispose();
			return;
		}

		pollEvents();

		if (_teardownQueued)
			DebugLog.log('update: post-poll, teardown still queued');

		if (_isPlaying && !_isPaused)
		{
			if (!_started && _formatReady && mpvCtx != null
				&& untyped __cpp__('dgm_ao_is_ready()') != 0)
			{
				_started = true;
				Mpv.setPropertyString(mpvCtx, 'pause', 'no');
				untyped __cpp__('dgm_audio_gate_open();');
				DebugLog.log('start: audio ready, unpaused mpv');
			}
		}

		if (_isPlaying && !_isPaused && _formatReady && renderCtx != null && videoBitmapData != null)
		{
			try
			{
				var flags:Int = Mpv.renderContextUpdate(renderCtx);
				if ((flags & 1) == 0)
					return;

				Mpv.renderFrame(renderCtx, fbo, _videoWidth, _videoHeight);
				Mpv.readPixels(fbo, _videoWidth, _videoHeight, rgbaPtr);
				Mpv.rgbaToArgb(rgbaPtr, argbPtr, _videoWidth * _videoHeight);

				videoBitmapData.lock();
				videoBitmapData.setPixels(rect, ByteArray.fromBytes(argbBytes));
				videoBitmapData.unlock();

				if (graphic != null && graphic.bitmap == videoBitmapData)
				{
					graphic.bitmap = videoBitmapData;
					dirty = true;
				}

				if (!_hasLoggedScreen)
				{
					_hasLoggedScreen = true;
					if (!_started && mpvCtx != null)
					{
						_started = true;
						Mpv.setPropertyString(mpvCtx, 'pause', 'no');
						DebugLog.log('first frame: fallback unpause (audio not ready)');
					}
					untyped __cpp__('dgm_audio_gate_open();');
					DebugLog.log('first frame: opened audio gate, video_time=${get_time()}ms');
					var cam = cameras != null && cameras.length > 0 ? cameras[0] : null;
					DebugLog.log('first frame: sprite x=$x y=$y w=$width h=$height scale=${scale.x}x${scale.y}');
					DebugLog.log('first frame: screenPos=${getScreenPosition()} screenBounds=${getScreenBounds()}');
					DebugLog.log('first frame: cam=${cam != null ? cam.width + "x" + cam.height + " zoom=" + cam.zoom : "null"}');
					DebugLog.log('first frame: FlxG.screen=${FlxG.width}x${FlxG.height} zoom=${FlxG.camera.zoom}');
				}

				_startWait += elapsed;
				if (_startWait >= 1.0)
				{
					_startWait = 0;
					DebugLog.log('probe w=${Std.int(Sys.time() * 1000000)} v=${get_time()} a=${Std.int(untyped __cpp__('(double)dgm_ao_get_pos()') * 1000)}');
				}
			}
			catch (e:Dynamic)
			{
				// silently skip bad frames
			}
		}
	}

	private function pollEvents():Void
	{
		var evt:RawPointer<cpp.Void> = Mpv.waitEvent(mpvCtx, 0.0);
		while (evt != null && Mpv.eventId(evt) != Mpv.EVENT_NONE)
		{
			switch (Mpv.eventId(evt))
			{
				case Mpv.EVENT_FILE_LOADED:
					DebugLog.log('mpv event: FILE_LOADED');
					setupVideo();
				case Mpv.EVENT_VIDEO_RECONFIG:
					DebugLog.log('mpv event: VIDEO_RECONFIG');
					if (_formatReady)
						setupVideo();
				case Mpv.EVENT_AUDIO_RECONFIG:
					DebugLog.log('mpv event: AUDIO_RECONFIG');
				case Mpv.EVENT_LOG_MESSAGE:
					var prefix:String = Mpv.logMessagePrefix(Mpv.eventData(evt));
					var text:String = Mpv.logMessageText(Mpv.eventData(evt));
					DebugLog.log('mpv[$prefix] ${StringTools.trim(text)}');
				case Mpv.EVENT_END_FILE:
					var reason:Int = Mpv.endFileReason(Mpv.eventData(evt));
					DebugLog.log('mpv event: END_FILE (reason=$reason)');
					if (reason == Mpv.END_FILE_REASON_EOF || reason == Mpv.END_FILE_REASON_ERROR)
					{
						handleVideoEnd();
						if (mpvCtx == null)
							return;
					}
				case Mpv.EVENT_SHUTDOWN:
					mpvCtx = null;
					return;
			}
			if (mpvCtx == null)
				return;
			evt = Mpv.waitEvent(mpvCtx, 0.0);
		}
	}

	private function setupVideo():Void
	{
		var w:Int = Mpv.getInt(mpvCtx, 'width');
		var h:Int = Mpv.getInt(mpvCtx, 'height');
		if (w <= 0 || h <= 0)
		{
			DebugLog.log('setupVideo: bad dims w=$w h=$h, bailing');
			return;
		}

		DebugLog.log('setupVideo: video=$w x $h, screen=${FlxG.width} x ${FlxG.height}, onFormatSetup=${onFormatSetup != null}');

		_videoWidth = w;
		_videoHeight = h;

		if (fbo != 0)
			Mpv.deleteFbo(fbo, texture);

		var newFbo:Int = 0;
		var newTex:Int = 0;
		Mpv.createFbo(RawPointer.addressOf(newFbo), RawPointer.addressOf(newTex), w, h);
		fbo = newFbo;
		texture = newTex;

		rgbaBytes = haxe.io.Bytes.alloc(w * h * 4);
		argbBytes = haxe.io.Bytes.alloc(w * h * 4);
		// hxcpp: Array<UInt8> is a flat buffer, GetBase() gives the raw pointer
		rgbaPtr = untyped __cpp__("{0}->b->GetBase()", rgbaBytes);
		argbPtr = untyped __cpp__("{0}->b->GetBase()", argbBytes);
		rect = new Rectangle(0, 0, w, h);

		if (videoBitmapData != null)
			videoBitmapData.dispose();

		videoBitmapData = new BitmapData(w, h, true, 0x00000000);
		loadGraphic(FlxGraphic.fromBitmapData(videoBitmapData, false, null, false));
		setGraphicSize(FlxG.width, FlxG.height);
		updateHitbox();

		_formatReady = true;

		if (_rate != 1.0)
			setRate(_rate);
		if (onFormatSetup != null)
			onFormatSetup();

		DebugLog.log('setupVideo done: scale=${scale.x} x ${scale.y}, pos=$x, $y, frame=$frameWidth x $frameHeight');
	}

	private function handleVideoEnd():Void
	{
		if (_shouldLoop)
		{
			// loop-file handles this internally, but fall back to a manual restart
			if (mpvCtx != null && _videoPath != null)
			{
				Mpv.loadfile(mpvCtx, _videoPath);
				Mpv.setPropertyString(mpvCtx, 'pause', 'no');
				_isPlaying = true;
				_isPaused = false;
			}
		}
		else
		{
			_isPlaying = false;
			// defer dispose() until the next update: mpv is still unwinding
			// after END_FILE, and tearing it down from inside the event
			// handler can block forever (see dispose())
			_teardownQueued = true;
			DebugLog.log('handleVideoEnd: EOF, teardown queued');
			if (onEndReached != null)
				onEndReached();
		}
	}

	override public function destroy():Void
	{
		if (FlxG.signals.focusGained.has(onFocusGained))
			FlxG.signals.focusGained.remove(onFocusGained);
		if (FlxG.signals.focusLost.has(onFocusLost))
			FlxG.signals.focusLost.remove(onFocusLost);

		dispose();
		super.destroy();
	}

	public function dispose():Void
	{
		untyped __cpp__('dgm_audio_stop_func()');

		// teardown order matters: the mpv core must be terminated BEFORE the
		// render context is freed - mpv_render_context_free() blocks until the
		// core releases it, and the core (mid-uninit at EOF) never does if we
		// free the context first = deadlock = frozen game + stuck last frame.
		if (mpvCtx != null)
		{
			DebugLog.log('dispose: terminating mpv');
			Mpv.terminateDestroy(mpvCtx);
			mpvCtx = null;
		}

		if (renderCtx != null)
		{
			DebugLog.log('dispose: freeing render ctx');
			Mpv.renderContextFree(renderCtx);
			renderCtx = null;
		}

		DebugLog.log('dispose: GL cleanup');

		if (fbo != 0)
		{
			Mpv.deleteFbo(fbo, texture);
			fbo = 0;
			texture = 0;
		}

		// insurance: clear the default framebuffer so no stale video pixels
		// survive into the next frame/state (ghost-frame fix)
		untyped __cpp__('dgm_mpv_gl_clear_default()');

		rgbaBytes = null;
		argbBytes = null;
		rgbaPtr = null;
		argbPtr = null;
		rect = null;

		if (videoBitmapData != null)
		{
			videoBitmapData.dispose();
			videoBitmapData = null;
		}

		_isPlaying = false;
		_isPaused = false;
		_formatReady = false;
	}

	private function onFocusGained():Void
	{
		#if !mobile
		if (!FlxG.autoPause)
			return;
		#end

		if (resumeOnFocus)
		{
			resumeOnFocus = false;
			resume();
		}
	}

	private function onFocusLost():Void
	{
		#if !mobile
		if (!FlxG.autoPause)
			return;
		#end

		resumeOnFocus = isPlaying;
		pause();
	}
	#end
}
