package slushi;

import flixel.FlxGame;

/**
 * Just a override of FlxGame for have a way to update SlushiMain constantly easier
 * 
 * Author: Slushi
 */
class SlGame extends FlxGame
{
	override public function update()
	{
		SlushiMain.update();
		super.update();
	}
}