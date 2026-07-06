package backend;

class CustomFadeTransition extends MusicBeatSubstate
{
	public static var finishCallback:Void->Void;

	var isTransIn:Bool = false;
	var transBlack:FlxSprite;

	var duration:Float;

	public function new(duration:Float, isTransIn:Bool)
	{
		this.duration = duration;
		this.isTransIn = isTransIn;
		super();
	}

	override function create()
	{
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		var width:Int = Std.int(FlxG.width / Math.max(camera.zoom, 0.001));
		var height:Int = Std.int(FlxG.height / Math.max(camera.zoom, 0.001));

		transBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		transBlack.scale.set(width, height);
		transBlack.updateHitbox();
		transBlack.scrollFactor.set();
		transBlack.screenCenter();
		// Si entra, empieza opaco y baja a 0. Si sale, empieza en 0 y sube a 1
		transBlack.alpha = isTransIn ? 1.0 : 0.0;
		add(transBlack);

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		final speed:Float = duration > 0 ? elapsed / duration : 1.0;

		if (isTransIn)
			transBlack.alpha -= speed; // Negro -> Transparente
		else
			transBlack.alpha += speed; // Transparente -> Negro

		if (isTransIn && transBlack.alpha <= 0.0)
		{
			transBlack.alpha = 0.0;
			close();
		}
		else if (!isTransIn && transBlack.alpha >= 1.0)
		{
			transBlack.alpha = 1.0;
			close();
		}
	}

	// Don't delete this
	override function close():Void
	{
		super.close();

		if (finishCallback != null)
		{
			finishCallback();
			finishCallback = null;
		}
	}
}