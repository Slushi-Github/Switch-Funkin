package dgm.video;

import slushi.SlDebug;

/**
 * Global handle for dgm video playback.
 *
 * Drop-in stand-in for `hxvlc.util.Handle` so the game's init code stays
 * similar on Switch. mpv instances are created per-video, so there is no
 * real global state to set up - this exists for API compatibility.
 */
class Handle
{
	public static var loading:Bool = false;
	public static var sharedInstance(default, null):Dynamic = null;

	public static function init(?options:Array<String>):Bool
	{
		#if switch
		if (sharedInstance != null)
			return true;

		loading = true;
		SlDebug.log('dgm.video.Handle: mpv ready', INFO);
		sharedInstance = true;
		loading = false;
		return true;
		#else
		return false;
		#end
	}

	public static function initAsync(?options:Array<String>, ?finishCallback:Bool->Void):Void
	{
		var result:Bool = init(options);
		if (finishCallback != null)
			finishCallback(result);
	}

	public static function dispose():Void
	{
		sharedInstance = null;
		loading = false;
	}
}
