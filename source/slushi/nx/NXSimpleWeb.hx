package slushi.nx;

import flixel.FlxBasic;
import switchLib.applets.Web;

/**
 * TODO:
 * - Add support for Youtube embed videos
 */
/**
 * Class for start a simple web page applet
 * 
 * Note: Youtube embed videos are not supported FOR NOW
 * 
 * Ported from Vupx Engine
 * 
 * Author: Slushi
 */
class NXSimpleWeb {
    /**
     * The URL of the request
     */
    public var url:Null<String> = "";

    /**
     * The result of the request
     */
    private var result:Null<ResultType>;

    /**
     * Whether the request failed
     */
    private var failed:Bool = false;

    /**
     * Whether the request has been initialized
     */
    private var initialized:Bool = false;

    /**
     * The config of the request
     */
    @:unreflective
    private var webConfig:Null<WebCommonConfig>;

    /**
     * Creates a new web page applet with the specified URL
     * @param url The URL of the request
     */
    public function new(url:String) {
        if (SwitchUtils.isRunningAsApplet()) {
            SlDebug.log("VpSimpleWeb can't be used when is running as applet", ERROR);
            failed = true;
            return;
        }
        
        if (url == "" || url == null) {
			SlDebug.log("No URL specified or is null", ERROR);
            failed = true;
            return;
        }

        this.url = url;
        this.webConfig = new WebCommonConfig();
        this.result = Web.webPageCreate(Pointer.addressOf(this.webConfig), this.url);

        if (Result.R_SUCCEEDED(result)) {
			SlDebug.log("Successfully configured web page, starting request", DEBUG);

            result = Web.webConfigSetWhitelist(Pointer.addressOf(this.webConfig), "^http*");
			SlDebug.log("Set whitelist", DEBUG);

            if (Result.R_FAILED(result)) {
				SlDebug.log("Failed to set whitelist", ERROR);
                failed = true;
                return;
            }
        }

        if (Result.R_FAILED(result)) {
			SlDebug.log("Failed to configure web page", ERROR);
            failed = true;
            return;
        }

        initialized = true;
    }

    /**
     * Shows the web page
     */
    public function showWebPage():Void {
        if (failed || !initialized || (failed && !initialized)) return;
        var result:ResultType = Web.webConfigShow(Pointer.addressOf(this.webConfig), null);
        if (Result.R_FAILED(result)) {
			SlDebug.log("Failed to show web page: " + result, ERROR);
            failed = true;
        }
    }

    public function destroy():Void {
        url = null;
        // webConfig = null; // compiler error
        result = null;
    }
}