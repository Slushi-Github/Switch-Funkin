package states.stages.objects;

#if funkin.vis
import funkin.vis.dsp.SpectralAnalyzer;
#end

#if (switch && funkin.vis)
import cpp.vm.Thread;
import cpp.vm.Lock;
#end

class ABotSpeaker extends FlxSpriteGroup
{
	final VIZ_MAX = 7; //ranges from viz1 to viz7
	final VIZ_POS_X:Array<Float> = [0, 59, 56, 66, 54, 52, 51];
	final VIZ_POS_Y:Array<Float> = [0, -8, -3.5, -0.4, 0.5, 4.7, 7];

	public var bg:FlxSprite;
	public var vizSprites:Array<FlxSprite> = [];
	public var eyeBg:FlxSprite;
	public var eyes:FlxAnimate;
	public var speaker:FlxAnimate;

	#if funkin.vis
	var analyzer:SpectralAnalyzer;
	#end
	var volumes:Array<Float> = [];

	#if (switch && funkin.vis)
	var _fftThread:Thread;
	var _dataLock:Lock;
	var _resultLock:Lock;
	var _fftRunning:Bool;
	var _resultValues:Array<Float>;
	#end

	public var snd(default, set):FlxSound;
	function set_snd(changed:FlxSound)
	{
		snd = changed;
		#if funkin.vis
		initAnalyzer();
		#end
		return snd;
	}

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);

		var antialias = ClientPrefs.data.antialiasing;

		bg = new FlxSprite(90, 20).loadGraphic(Paths.image('abot/stereoBG'));
		bg.antialiasing = antialias;
		add(bg);

		var vizX:Float = 0;
		var vizY:Float = 0;
		var vizFrames = Paths.getSparrowAtlas('abot/aBotViz');
		for (i in 1...VIZ_MAX+1)
		{
			volumes.push(0.0);
			vizX += VIZ_POS_X[i-1];
			vizY += VIZ_POS_Y[i-1];
			var viz:FlxSprite = new FlxSprite(vizX + 140, vizY + 74);
			viz.frames = vizFrames;
			viz.animation.addByPrefix('VIZ', 'viz$i', 0);
			viz.animation.play('VIZ', true);
			viz.animation.curAnim.finish(); //make it go to the lowest point
			viz.antialiasing = antialias;
			vizSprites.push(viz);
			viz.updateHitbox();
			viz.centerOffsets();
			add(viz);
		}

		eyeBg = new FlxSprite(-30, 215).makeGraphic(1, 1, FlxColor.WHITE);
		eyeBg.scale.set(160, 60);
		eyeBg.updateHitbox();
		add(eyeBg);

		eyes = new FlxAnimate(-10, 230);
		Paths.loadAnimateAtlas(eyes, 'abot/systemEyes');
		eyes.anim.addBySymbolIndices('lookleft', 'a bot eyes lookin', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17], 24, false);
		eyes.anim.addBySymbolIndices('lookright', 'a bot eyes lookin', [18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35], 24, false);
		eyes.anim.play('lookright', true);
		eyes.anim.curFrame = eyes.anim.length - 1;
		add(eyes);

		speaker = new FlxAnimate(-65, -10);
		Paths.loadAnimateAtlas(speaker, 'abot/abotSystem');
		speaker.anim.addBySymbol('anim', 'Abot System', 24, false);
		speaker.anim.play('anim', true);
		speaker.anim.curFrame = speaker.anim.length - 1;
		speaker.antialiasing = #if switch false #else antialias #end;
		add(speaker);

		#if switch
		eyes.active = false;
		speaker.active = false;
		#end
	}

	#if funkin.vis
	var levels:Array<Bar>;
	var levelMax:Int = 0;
	#end

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		#if funkin.vis
		if (analyzer == null)
			return;

		#if switch
		if (_resultLock != null && _resultLock.wait(0))
		{
			for (i in 0...Std.int(Math.min(vizSprites.length, _resultValues.length)))
			{
				var animFrame:Int = Math.round(_resultValues[i] * 5);
				animFrame = Std.int(Math.abs(FlxMath.bound(animFrame, 0, 5) - 5));
				vizSprites[i].animation.curAnim.curFrame = animFrame;
			}
			_dataLock.release();
		}
		#else
		levels = analyzer.getLevels(levels);
		var oldLevelMax = levelMax;
		levelMax = 0;
		for (i in 0...Std.int(Math.min(vizSprites.length, levels.length)))
		{
			var animFrame:Int = Math.round(levels[i].value * 5);
			animFrame = Std.int(Math.abs(FlxMath.bound(animFrame, 0, 5) - 5));
			vizSprites[i].animation.curAnim.curFrame = animFrame;
			levelMax = Std.int(Math.max(levelMax, 5 - animFrame));
		}
		if (levelMax >= 4)
		{
			if (oldLevelMax <= levelMax && (levelMax >= 5 || speaker.anim.curFrame >= 3))
				beatHit();
		}
		#end
		#end
	}

	public function beatHit()
	{
		#if switch
		speaker.active = true;
		#end
		speaker.anim.play('anim', true);
	}

	#if funkin.vis
	public function initAnalyzer()
	{
		@:privateAccess
		analyzer = new SpectralAnalyzer(snd._channel.__audioSource, 7, 0.1, 40);
	
		#if desktop
		// On desktop it uses FFT stuff that isn't as optimized as the direct browser stuff we use on HTML5
		// So we want to manually change it!
		analyzer.fftN = 256;
		#end

		#if switch
		_resultValues = [];
		for (i in 0...7)
			_resultValues.push(0.0);
		_dataLock = new Lock();
		_resultLock = new Lock();
		_fftRunning = true;
		_dataLock.release();
		_fftThread = Thread.create(fftWorker);
		#end
	}

	#if switch
	function fftWorker()
	{
		while (_fftRunning)
		{
			_dataLock.wait();
			if (!_fftRunning)
				break;
			var bars = analyzer.getLevels();
			for (i in 0..._resultValues.length)
				_resultValues[i] = (i < bars.length) ? bars[i].value : 0.0;
			_resultLock.release();
		}
	}
	#end
	#end

	var lookingAtRight:Bool = true;
	public function lookLeft()
	{
		if(lookingAtRight) {
			#if switch
			eyes.active = true;
			#end
			eyes.anim.play('lookleft', true);
		}
		lookingAtRight = false;
	}
	public function lookRight()
	{
		if(!lookingAtRight) {
			#if switch
			eyes.active = true;
			#end
			eyes.anim.play('lookright', true);
		}
		lookingAtRight = true;
	}
}