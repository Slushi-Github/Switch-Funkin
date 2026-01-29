package slushi.states.freeplay;

import objects.HealthIcon;

/**
 * Just a simple change to the HealthIcon, for the Slushi Freeplay
 * 
 * Ported from Slushi Engine
 * 
 * Author: Slushi
 */
class SlushiFreeplayHealthIcon extends HealthIcon
{
	public var songTxtTracker:FlxSprite;

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (songTxtTracker != null)
		{
			setPosition(songTxtTracker.x + (songTxtTracker.width / 2) - (this.width / 2), songTxtTracker.y - 100);
		}
	}
}