package objects;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.addons.display.FlxPieDial;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
#else
import slushi.fixes.OpenFLVideoSprite;
#end

class VideoSprite extends FlxSpriteGroup
{
	#if VIDEOS_ALLOWED
	public var finishCallback:Void->Void = null;
	public var onSkip:Void->Void = null;

	final _timeToSkip:Float = 1;

	public var holdingTime:Float = 0;

	#if hxvlc
	public var videoSprite:FlxVideoSprite;
	#else
	public var videoSprite:OpenFLVideoSprite;
	#end

	public var skipSprite:FlxPieDial;
	public var cover:FlxSprite;
	public var canSkip(default, set):Bool = false;

	private var videoName:String;

	public var waiting:Bool = false;

	public function new(videoName:String, isWaiting:Bool, canSkip:Bool = false, shouldLoop:Dynamic = false)
	{
		super();

		this.videoName = videoName;
		scrollFactor.set();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		waiting = isWaiting;
		if (!waiting)
		{
			cover = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
			cover.scale.set(FlxG.width + 100, FlxG.height + 100);
			cover.screenCenter();
			cover.scrollFactor.set();
			add(cover);
		}

		// Initialize sprites
		#if hxvlc
		videoSprite = new FlxVideoSprite();
		#else
		videoSprite = new OpenFLVideoSprite();
		#end

		videoSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(videoSprite);
		if (canSkip)
			this.canSkip = true;

		// Callbacks
		#if hxvlc
		if (!shouldLoop)
			videoSprite.bitmap.onEndReached.add(finishVideo);

		videoSprite.bitmap.onFormatSetup.add(function()
		{
			videoSprite.setGraphicSize(FlxG.width);
			videoSprite.updateHitbox();
			videoSprite.screenCenter();
		});
		#else
		if (!shouldLoop)
			videoSprite.onEndReached = finishVideo;

		videoSprite.onFormatSetup = function()
		{
			var scale:Float = Math.min(FlxG.width / videoSprite.width, FlxG.height / videoSprite.height);
			videoSprite.setGraphicSize(Std.int(videoSprite.width * scale), Std.int(videoSprite.height * scale));
			videoSprite.updateHitbox();
			videoSprite.screenCenter();
		};
		#end

		// Start video and adjust resolution to screen size
		videoSprite.load(videoName, shouldLoop ? ['input-repeat=65545'] : null);
	}

	var alreadyDestroyed:Bool = false;

	override function destroy()
	{
		if (alreadyDestroyed)
			return;

		SlDebug.log('Video destroyed');
		if (cover != null)
		{
			remove(cover);
			cover.destroy();
		}

		finishCallback = null;
		onSkip = null;

		if (FlxG.state != null)
		{
			if (FlxG.state.members.contains(this))
				FlxG.state.remove(this);

			if (FlxG.state.subState != null && FlxG.state.subState.members.contains(this))
				FlxG.state.subState.remove(this);
		}

		super.destroy();
		alreadyDestroyed = true;
	}

	function finishVideo()
	{
		if (!alreadyDestroyed)
		{
			if (finishCallback != null)
				finishCallback();

			destroy();
		}
	}

	override function update(elapsed:Float)
	{
		if (canSkip)
		{
			if (Controls.instance.pressed('accept'))
			{
				holdingTime = Math.max(0, Math.min(_timeToSkip, holdingTime + elapsed));
			}
			else if (holdingTime > 0)
			{
				holdingTime = Math.max(0, FlxMath.lerp(holdingTime, -0.1, FlxMath.bound(elapsed * 3, 0, 1)));
			}
			updateSkipAlpha();

			if (holdingTime >= _timeToSkip)
			{
				if (onSkip != null)
					onSkip();
				finishCallback = null;

				#if hxvlc
				videoSprite.bitmap.onEndReached.dispatch();
				#else
				if (videoSprite.onEndReached != null)
					videoSprite.onEndReached();
				#end

				SlDebug.log('Skipped video');
				return;
			}
		}

		// Update volume based on FlxG.sound
		#if FLX_SOUND_SYSTEM
		var volume = (FlxG.sound.muted ? 0 : 1) * FlxG.sound.volume;
		#if !hxvlc
		videoSprite.setVolume(volume);
		#end
		#end

		super.update(elapsed);
	}

	function set_canSkip(newValue:Bool)
	{
		canSkip = newValue;
		if (canSkip)
		{
			if (skipSprite == null)
			{
				skipSprite = new FlxPieDial(0, 0, 40, FlxColor.WHITE, 40, true, 24);
				skipSprite.replaceColor(FlxColor.BLACK, FlxColor.TRANSPARENT);
				skipSprite.x = FlxG.width - (skipSprite.width + 80);
				skipSprite.y = FlxG.height - (skipSprite.height + 72);
				skipSprite.amount = 0;
				add(skipSprite);
			}
		}
		else if (skipSprite != null)
		{
			remove(skipSprite);
			skipSprite.destroy();
			skipSprite = null;
		}
		return canSkip;
	}

	function updateSkipAlpha()
	{
		if (skipSprite == null)
			return;

		skipSprite.amount = Math.min(1, Math.max(0, (holdingTime / _timeToSkip) * 1.025));
		skipSprite.alpha = FlxMath.remapToRange(skipSprite.amount, 0.025, 1, 0, 1);
	}

	public function play()
		videoSprite?.play();

	public function resume()
		videoSprite?.resume();

	public function pause()
		videoSprite?.pause();
	#end
}