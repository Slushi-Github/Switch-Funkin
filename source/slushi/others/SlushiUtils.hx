package slushi.others;

/**
 * Just a collection of useful functions
 * 
 * Ported from Slushi Engine
 * 
 * Author: Slushi
 */
class SlushiUtils {
	inline public static function clamp(value:Float, min:Float, max:Float):Float
		return Math.max(min, Math.min(max, value));

	inline public static function boundTo(value:Float, min:Float, max:Float):Float
	{
		return Math.max(min, Math.min(max, value));
	}
}