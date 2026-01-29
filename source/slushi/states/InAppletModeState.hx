package slushi.states;

import flixel.FlxState;
import flixel.text.FlxText;

/**
 * A state that is shown when the game is running in applet mode
 * 
 * Author: Slushi
 */
class InAppletModeState extends FlxState {
    override public function create() {
        super.create();
		var txt:FlxText = new FlxText(0, 0, 0,
			"YOU ARE RUNNING SWITCH FUNKIN' IN APPLET MODE\nThis is not supported on Switch.\n\nThe game requires more resources than are available in this mode.\nPlease open the game from an official Switch game \n(usually by holding down the R button while opening a game).", 12);
		txt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		txt.scrollFactor.set();
        txt.screenCenter();
		add(txt);
    }
}