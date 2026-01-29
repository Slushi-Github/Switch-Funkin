package slushi.slushiLua;

import psychlua.FunkinLua;

class SwitchLua
{
	public static function implement(funk:FunkinLua)
	{
        #if !switch
		final lua = funk.lua;
		funk.set("CONSOLE_IS_DOCKED", SwitchUtils.IS_DOCKED);

		Lua_helper.add_callback(lua, "joyconRumble", function(joycon:Int, duration:Float, frequency:Array<Float>, amplitude:Array<Float>)
		{
			if (!ClientPrefs.data.vibrating)
				return;

			if (joycon != 0 && joycon != 1)
				return;
			else if (duration <= 0)
				return;
			else if (frequency.length < 2)
				return;
			else if (amplitude.length < 2)
				return;
			else if (frequency[0] < 0 || frequency[0] > 1 || amplitude[0] < 0 
                || amplitude[0] > 1 || frequency[1] < 0 
                || frequency[1] > 1 || amplitude[1] < 0
				|| amplitude[1] > 1)
				return;

			final joyconType = joycon == 0 ? NXJoyCon.LEFT : NXJoyCon.RIGHT;

            SlushiMain.nxController.vibration.vibrate({
                joycon: joyconType,
                duration: duration,
                amplitude_low: amplitude[0],
                frequency_low: frequency[0],
                amplitude_high: amplitude[1],
                frequency_high: frequency[1]
            });
		});

		Lua_helper.add_callback(lua, "joyconRumbleBoth", function(duration:Float, frequency:Array<Float>, amplitude:Array<Float>)
        {
			if (!ClientPrefs.data.vibrating)
                return;

            if (duration <= 0)
                return;
            else if (frequency.length < 2)
                return;
            else if (amplitude.length < 2)
                return;
            else if (frequency[0] < 0 || frequency[0] > 1 || amplitude[0] < 0 || amplitude[0] > 1 || frequency[1] < 0 || frequency[1] > 1 || amplitude[1] < 0
                || amplitude[1] > 1)
                return;

            SlushiMain.nxController.vibration.vibrateBoth({
                joycon: NXJoyCon.LEFT,
                duration: duration,
                amplitude_low: amplitude[0],
                frequency_low: frequency[0],
                amplitude_high: amplitude[1],
                frequency_high: frequency[1]
            });
        });

        Lua_helper.add_callback(lua, "joyconRumbleStop", function(joycon:Int)
        {
			if (!ClientPrefs.data.vibrating)
				return;

            if (joycon != 0 && joycon != 1)
                return;

            else if (joycon == 0)
                SlushiMain.nxController.vibration.stop(NXJoyCon.LEFT);
            else
                SlushiMain.nxController.vibration.stop(NXJoyCon.RIGHT);
        });

        Lua_helper.add_callback(lua, "joyconRumbleStopBoth", function()
        {
            if (!ClientPrefs.data.vibrating)
                return;

            SlushiMain.nxController.vibration.stop(NXJoyCon.LEFT);
            SlushiMain.nxController.vibration.stop(NXJoyCon.RIGHT);
        });
        #end
	}
}
