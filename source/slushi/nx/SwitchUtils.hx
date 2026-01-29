package slushi.nx;

import cpp.Pointer;

#if switch
import switchLib.applets.Error;
import switchLib.applets.Error.ErrorApplicationConfig;
import switchLib.services.Set;
import switchLib.Result;
import switchLib.Types.ResultType;
import switchLib.services.Applet;
#end

/**
 * States of the applet
 */
enum AppletStateMode
{
	/**
	 * The applet/program is in focus
	 */
	APP_IN_FOCUS;

	/**
	 * The applet/program is out of focus
	 */
	APP_OUT_OF_FOCUS;

	/**
	 * The applet/program is suspended (In HOME menu or the console is sleeping)
	 */
	APP_SUSPENDED;

	/**
	 * Unknown state
	 */
	APP_UNKNOWN;
}

/**
 * Nintendo Switch utility functions, from Vupx Engine
 * 
 * Author: Slushi
 */
class SwitchUtils {
	/**
	 * Checks if the console is docked (TV mode).
	 */
	public static var IS_DOCKED(get, never):Bool;

	/**
	 * The current applet state.
	 */
	public static var appState(get, never):AppletStateMode;

	/**
	 * Checks if the application is running on Applet mode.
	 * @return Bool
	 */
	public static function isRunningAsApplet():Bool
	{
		#if switch
		return Applet.appletGetAppletType() != AppletType.AppletType_Application
			&& Applet.appletGetAppletType() != AppletType.AppletType_SystemApplication;
		#else
		return false;
		#end
	}


    /**
     * Shows an error message
     * @param msg The error message
     */
    public static function showError(code:Null<Int> = 0, msg:String = '', ?full_message:String = null):Void {
        #if switch
		if (!isRunningAsApplet())
		{
			var config:ErrorApplicationConfig = new ErrorApplicationConfig();
			var result:ResultType = Error.errorApplicationCreate(Pointer.addressOf(config), msg, full_message);

			if (Result.R_SUCCEEDED(result))
			{
				Error.errorApplicationSetNumber(Pointer.addressOf(config), code ?? 0);
				Error.errorApplicationShow(Pointer.addressOf(config));
			}
		}
        #end
    }

	private static function get_IS_DOCKED():Bool
	{
		#if switch
		return Applet.appletGetOperationMode() == AppletOperationMode.AppletOperationMode_Console;
		#else
		return false;
		#end
	}

	private static function get_appState():AppletStateMode
	{
		#if switch
		return switch (Applet.appletGetFocusState())
		{
			case AppletFocusState.AppletFocusState_InFocus: AppletStateMode.APP_IN_FOCUS;
			case AppletFocusState.AppletFocusState_OutOfFocus: AppletStateMode.APP_OUT_OF_FOCUS;
			case AppletFocusState.AppletFocusState_Background: AppletStateMode.APP_SUSPENDED;
			default: AppletStateMode.APP_UNKNOWN;
		}
		#else
		return AppletStateMode.APP_UNKNOWN;
		#end
	}
}