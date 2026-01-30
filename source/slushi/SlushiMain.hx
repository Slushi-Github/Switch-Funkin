package slushi;

import haxe.Http;
import substates.OutdatedSubState;

/**
 * Simple main class for initializing custom things of the engine
 * 
 * Author: Slushi
 */
class SlushiMain {
    /**
     * A extra comment for the version of the engine 
     */
    public static final VERSION_EXTRA_TEXT:String = "";

	/**
	 * Slushi color :3
	 */
	public static final slushiColor:FlxColor = FlxColor.fromRGB(143, 217, 209); // 0xff8FD9D1 0xffd6f3de

    /**
     * Controller manager for Nintendo Switch controllers
     */
	public static var nxController:NXController = null;

    public static function init() {
        nxController = new NXController();
        Application.current.window.onClose.add(function () {
            destroy();
        });
    }

    public static function update() {
        #if switch
        if (nxController != null) {
			nxController.update();
        }
        #end
    }

    public static function destroy() {
        #if switch
        if (nxController != null) {
            nxController.destroy();
        }
        #end
    }

    /**
     * Get the path to a file from the ``assets/SwitchFunkinAssets`` folder
     */
	inline public static function getPath(file:String = ""):String {
        if (file == null || file == "") return "";
        
		final finalFile = #if switch 'romfs:/' + #end 'assets/SwitchFunkinAssets/$file';
        if (!FileSystem.exists(finalFile)) {
            SlDebug.log('File not found: $finalFile', ERROR);
            return "";
        }

		return 'assets/SwitchFunkinAssets/$file';
    }

	public static function checkForUpdates():Void
	{
		final url = "https://raw.githubusercontent.com/Slushi-Github/Switch-Funkin/main/gitVersion.txt";

		final localVersion:String = Application.current.meta.get('version');
		if (ClientPrefs.data.checkForUpdates)
		{
			SlDebug.log('Checking for updates...');
			var http = new Http(url);
			http.onData = function(data:String)
			{
				var newVersion:String = data.split('\n')[0].trim();
				SlDebug.log('GitHub version: $newVersion, your version: $localVersion');
				if (newVersion != localVersion)
				{
					SlDebug.log('Versions arent matching!', WARNING);
					OutdatedSubState.updateVersion = newVersion;
					http.onData = null;
					http.onError = null;
					http = null;
				}
			}
			http.onError = function(error)
			{
				SlDebug.log('Error while checking for updates: $error', ERROR);
				OutdatedSubState.FAILED_CHECK = true;
			}
			http.request();
		}
	}
}