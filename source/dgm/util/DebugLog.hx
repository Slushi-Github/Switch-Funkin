package dgm.util;

/**
 * Minimal debug logger for the dgm mpv video stack.
 *
 * On Switch it appends to sdmc:/switch/Switch-Funkin/dgm_debug.log so logs
 * are readable even when the game is launched from the SD card (no nxlink).
 * Always mirrors to stdout (nxlink console) on every target.
 */
class DebugLog
{
	static var initialized:Bool = false;

	public static function log(message:String):Void
	{
		#if switch
		if (!initialized)
		{
			initialized = true;
			try
			{
				if (!sys.FileSystem.exists('sdmc:/switch/Switch-Funkin/'))
					sys.FileSystem.createDirectory('sdmc:/switch/Switch-Funkin/');
				sys.io.File.saveContent('sdmc:/switch/Switch-Funkin/dgm_debug.log', '');
			}
			catch (e:Dynamic) {}
		}

		try
		{
			var f = sys.io.File.append('sdmc:/switch/Switch-Funkin/dgm_debug.log', false);
			f.writeString(message + '\n');
			f.close();
		}
		catch (e:Dynamic) {}
		#end

		Sys.println('[dgm] ' + message);
	}
}
