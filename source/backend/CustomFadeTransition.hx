package backend;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class CustomFadeTransition extends MusicBeatSubstate
{
	public static var finishCallback:Void->Void;

	private var tween:FlxTween = null;

	var fadeInState:Bool = true;

	public static var placedZoom:Float;
	public static var divideZoom:Bool = true; // Divide = true, multiple = false

	var duration:Float;

	public function new(duration:Float, fadeInState:Bool, zoom:Float)
	{
		this.duration = duration;
		this.fadeInState = fadeInState;
		if (placedZoom > 0)
			placedZoom = zoom;
		super();
	}

	var cameraTrans:FlxCamera = null;
	var transBlack:FlxSprite = null;

	override public function create()
	{
		cameraTrans = new FlxCamera();
		cameraTrans.bgColor.alpha = 0;

		FlxG.cameras.add(cameraTrans, false);

		var width:Int = divideZoom ? Std.int(FlxG.width / Math.max(camera.zoom, 0.001)) : Std.int(FlxG.width * Math.max(camera.zoom, 0.001));
		var height:Int = divideZoom ? Std.int(FlxG.height / Math.max(camera.zoom, 0.001)) : Std.int(FlxG.width * Math.max(camera.zoom, 0.001));

		transBlack = new FlxSprite().makeGraphic(width + 400, height + 400, FlxColor.BLACK);
		transBlack.scrollFactor.set();
		transBlack.alpha = fadeInState ? 1 : 0;
		transBlack.visible = true;
		add(transBlack);

		if (fadeInState)
		{
			FlxTween.tween(transBlack, {alpha: 0}, duration, {ease: FlxEase.quadInOut});
			new FlxTimer().start(duration, function(twn:FlxTimer)
			{
				close();
			});
		}
		else
		{
			tween = FlxTween.tween(transBlack, {alpha: 1}, duration, {ease: FlxEase.quadInOut});
			new FlxTimer().start(duration, function(twn:FlxTimer)
			{
				if (finishCallback != null)
				{
					finishCallback();
				}
			});
		}

		super.create();

		cameras = [cameraTrans];
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
	}

	override function destroy()
	{
		if (tween != null)
		{
			finishCallback();
			tween.cancel();
		}
		super.destroy();
	}
}