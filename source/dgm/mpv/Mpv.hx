package dgm.mpv;

import cpp.ConstCharStar;
import cpp.RawPointer;
import cpp.UInt8;

/**
 * Minimal mpv C API bindings for Nintendo Switch (the same library
 * SwitchWave is built on top of).
 *
 * Compiled ONLY when the "DGM_MPV" define is set on the switch target
 * (see Project.xml). Requires mpv built for devkitA64, installed under
 * ${DEVKITPRO}/portlibs/switch.
 *
 * The C glue helpers ("dgm_mpv_*") and the audio pipeline live in
 * "native/dgm_native.cpp", which is added to the hxcpp build by
 * "dgm.video.SwitchVideo"'s "@:buildXml" fragment.
 */
@:include("mpv/client.h")
@:include("mpv/render.h")
@:include("mpv/render_gl.h")
extern class Mpv
{
	// instance lifecycle
	@:native("mpv_create")
	public static function create():RawPointer<cpp.Void>;

	@:native("mpv_initialize")
	public static function initialize(ctx:RawPointer<cpp.Void>):Int;

	@:native("mpv_terminate_destroy")
	public static function terminateDestroy(ctx:RawPointer<cpp.Void>):Void;

	// commands/options
	@:native("dgm_mpv_loadfile")
	public static function loadfile(ctx:RawPointer<cpp.Void>, path:ConstCharStar):Int;

	@:native("mpv_command_string")
	public static function commandString(ctx:RawPointer<cpp.Void>, args:ConstCharStar):Int;

	@:native("mpv_set_option_string")
	public static function setOptionString(ctx:RawPointer<cpp.Void>, name:ConstCharStar, data:ConstCharStar):Int;

	@:native("mpv_set_property_string")
	public static function setPropertyString(ctx:RawPointer<cpp.Void>, name:ConstCharStar, data:ConstCharStar):Int;

	@:native("dgm_mpv_set_double")
	public static function setDouble(ctx:RawPointer<cpp.Void>, name:ConstCharStar, value:Float):Void;

	// properties
	@:native("dgm_mpv_get_int")
	public static function getInt(ctx:RawPointer<cpp.Void>, name:ConstCharStar):Int;

	@:native("dgm_mpv_get_double")
	public static function getDouble(ctx:RawPointer<cpp.Void>, name:ConstCharStar):Float;

	@:native("dgm_mpv_get_boolean")
	public static function getBoolean(ctx:RawPointer<cpp.Void>, name:ConstCharStar):Int;

	@:native("mpv_get_property_string")
	public static function getPropertyString(ctx:RawPointer<cpp.Void>, name:ConstCharStar):ConstCharStar;

	@:native("mpv_free")
	public static function free(data:RawPointer<cpp.Void>):Void;

	// events
	@:native("mpv_wait_event")
	public static function waitEvent(ctx:RawPointer<cpp.Void>, timeout:Float):RawPointer<cpp.Void>;

	@:native("mpv_request_log_messages")
	public static function requestLogMessages(ctx:RawPointer<cpp.Void>, level:ConstCharStar):Int;

	@:native("dgm_mpv_event_id")
	public static function eventId(evt:RawPointer<cpp.Void>):Int;

	@:native("dgm_mpv_event_data")
	public static function eventData(evt:RawPointer<cpp.Void>):RawPointer<cpp.Void>;

	@:native("dgm_mpv_log_message_prefix")
	public static function logMessagePrefix(data:RawPointer<cpp.Void>):ConstCharStar;

	@:native("dgm_mpv_log_message_text")
	public static function logMessageText(data:RawPointer<cpp.Void>):ConstCharStar;

	@:native("dgm_mpv_end_file_reason")
	public static function endFileReason(data:RawPointer<cpp.Void>):Int;

	// render context (OpenGL ES)
	@:native("dgm_mpv_render_context_create")
	public static function renderContextCreate(ctx:RawPointer<cpp.Void>, error:RawPointer<Int>):RawPointer<cpp.Void>;

	@:native("dgm_mpv_render_context_update")
	public static function renderContextUpdate(ctx:RawPointer<cpp.Void>):Int;

	@:native("dgm_mpv_render_frame")
	public static function renderFrame(ctx:RawPointer<cpp.Void>, fbo:Int, w:Int, h:Int):Void;

	@:native("dgm_mpv_render_context_free")
	public static function renderContextFree(ctx:RawPointer<cpp.Void>):Void;

	// GL helper glue
	@:native("dgm_mpv_gl_create_fbo")
	public static function createFbo(fbo:RawPointer<Int>, tex:RawPointer<Int>, w:Int, h:Int):Void;

	@:native("dgm_mpv_gl_read_pixels")
	public static function readPixels(fbo:Int, w:Int, h:Int, out:RawPointer<UInt8>):Void;

	@:native("dgm_mpv_gl_delete_fbo")
	public static function deleteFbo(fbo:Int, tex:Int):Void;

	@:native("dgm_mpv_rgba_to_argb")
	public static function rgbaToArgb(src:RawPointer<UInt8>, dst:RawPointer<UInt8>, pixels:Int):Void;

	// event ids (mpv_event_id, see mpv/client.h)
	public static inline var EVENT_NONE:Int = 0;
	public static inline var EVENT_SHUTDOWN:Int = 1;
	public static inline var EVENT_LOG_MESSAGE:Int = 2;
	public static inline var EVENT_END_FILE:Int = 7;
	public static inline var EVENT_FILE_LOADED:Int = 8;
	public static inline var EVENT_VIDEO_RECONFIG:Int = 17;
	public static inline var EVENT_AUDIO_RECONFIG:Int = 18;

	// end_file reasons (mpv_end_file_reason)
	public static inline var END_FILE_REASON_EOF:Int = 0;
	public static inline var END_FILE_REASON_STOP:Int = 2;
	public static inline var END_FILE_REASON_ERROR:Int = 4;
}
