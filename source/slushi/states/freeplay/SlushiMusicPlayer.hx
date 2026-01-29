package slushi.states.freeplay;

import flixel.group.FlxGroup;
import flixel.ui.FlxBar;
import slushi.states.freeplay.SlushiFreeplayState;
import flixel.util.FlxStringUtil;

/**
 * Music player used for Freeplay
 * 
 * Ported from Slushi Engine
 * 
 * Author: ??? - Modified by Slushi
 */
@:access(slushi.states.freeplay.SlushiFreeplayState)
class SlushiMusicPlayer extends FlxGroup
{
	public var instance:SlushiFreeplayState;
	public var controls:Controls;

	public var playing(get, never):Bool;

	public var playingMusic:Bool = false;
	public var curTime:Float;

	var timeTxt:FlxText;
	var progressBar:FlxBar;
	var playbackSymbols:Array<FlxText> = [];
	var playbackTxt:FlxText;

	public var wasPlaying:Bool;

	public var holdPitchTime:Float = 0;
	public var playbackRate(default, set):Float = 1;

	public var fadingOut:Bool;

	public var backgroundLol:FlxSprite;

	public var songTextY:Float = 0;

	public var sineValue:Float = 0;

	public function new(instance:SlushiFreeplayState)
	{
		super();

		this.instance = instance;
		this.controls = instance.controls;

		var xPos:Float = FlxG.width * 0.7;

		timeTxt = new FlxText(xPos, 0, 0, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		add(timeTxt);

		for (i in 0...2)
		{
			var text:FlxText = new FlxText();
			text.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER);
			text.text = '^';
			if (i == 1)
				text.flipY = true;
			text.visible = false;
			playbackSymbols.push(text);
			add(text);
		}

		progressBar = new FlxBar(timeTxt.x, timeTxt.y + timeTxt.height, LEFT_TO_RIGHT, Std.int(timeTxt.width), 8, null, "", 0, Math.POSITIVE_INFINITY);
		progressBar.createFilledBar(FlxColor.WHITE, SlushiMain.slushiColor);
		add(progressBar);

		playbackTxt = new FlxText(FlxG.width * 0.6, 20, 0, "", 32);
		playbackTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE);
		add(playbackTxt);

		backgroundLol = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), 0xFF000000);
		backgroundLol.alpha = 0;
		add(backgroundLol);

		switchPlayMusic();

		camera = SlushiFreeplayState.instance.camSongs;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!playingMusic)
		{
			Conductor.songPosition = -5000 / Conductor.songPosition;
			return;
		}

		Conductor.songPosition = SlushiFreeplayState.instance.inst.time;

		if (playing && !wasPlaying)
		{
			timeTxt.alpha = 1;
		}
		else
		{
			if (timeTxt != null && timeTxt.visible)
			{
				sineValue += 180 * elapsed;
				timeTxt.alpha = 1 - Math.sin((Math.PI * sineValue) / 180);
			}
		}

		if (controls.UI_LEFT_P)
		{
			if (playing)
				wasPlaying = true;

			pauseOrResume();

			curTime = SlushiFreeplayState.instance.inst.time - 1000;
			instance.holdTime = 0;

			if (curTime < 0)
				curTime = 0;

			SlushiFreeplayState.instance.inst.time = curTime;
			setVocalsTime(curTime);
		}
		if (controls.UI_RIGHT_P)
		{
			if (playing)
				wasPlaying = true;

			pauseOrResume();

			curTime = SlushiFreeplayState.instance.inst.time + 1000;
			instance.holdTime = 0;

			if (curTime > SlushiFreeplayState.instance.inst.length)
				curTime = SlushiFreeplayState.instance.inst.length;

			SlushiFreeplayState.instance.inst.time = curTime;
			setVocalsTime(curTime);
		}

		if (controls.UI_LEFT || controls.UI_RIGHT)
		{
			instance.holdTime += elapsed;
			if (instance.holdTime > 0.5)
			{
				curTime += 40000 * elapsed * (controls.UI_LEFT ? -1 : 1);
			}

			var difference:Float = Math.abs(curTime - SlushiFreeplayState.instance.inst.time);
			if (curTime + difference > SlushiFreeplayState.instance.inst.length)
				curTime = SlushiFreeplayState.instance.inst.length;
			else if (curTime - difference < 0)
				curTime = 0;

			SlushiFreeplayState.instance.inst.time = curTime;
			setVocalsTime(curTime);
		}

		if (controls.UI_LEFT_R || controls.UI_RIGHT_R)
		{
			SlushiFreeplayState.instance.inst.time = curTime;
			setVocalsTime(curTime);

			if (wasPlaying)
			{
				pauseOrResume(true);
				wasPlaying = false;
			}
		}
		if (controls.UI_UP_P)
		{
			holdPitchTime = 0;
			playbackRate += 0.05;
			setPlaybackRate();
		}
		else if (controls.UI_DOWN_P)
		{
			holdPitchTime = 0;
			playbackRate -= 0.05;
			setPlaybackRate();
		}
		if (controls.UI_DOWN || controls.UI_UP)
		{
			holdPitchTime += elapsed;
			if (holdPitchTime > 0.6)
			{
				playbackRate += 0.05 * (controls.UI_UP ? 1 : -1);
				setPlaybackRate();
			}
		}

		if (controls.RESET)
		{
			playbackRate = 1;
			setPlaybackRate();

			SlushiFreeplayState.instance.inst.time = 0;
			setVocalsTime(0);

			updateTimeTxt();
		}

		if (playing && !fadingOut)
		{
			if (SlushiFreeplayState.instance.inst != null)
				SlushiFreeplayState.instance.inst.volume = 0.8;
			if (SlushiFreeplayState.vocals != null)
				SlushiFreeplayState.vocals.volume = (SlushiFreeplayState.vocals.length > SlushiFreeplayState.instance.inst.time) ? 0.8 : 0;
			if (SlushiFreeplayState.opponentVocals != null)
				SlushiFreeplayState.opponentVocals.volume = (SlushiFreeplayState.opponentVocals.length > SlushiFreeplayState.instance.inst.time) ? 0.8 : 0;

			if ((SlushiFreeplayState.vocals != null
				&& SlushiFreeplayState.vocals.length > SlushiFreeplayState.instance.inst.time
				&& Math.abs(SlushiFreeplayState.instance.inst.time - SlushiFreeplayState.vocals.time) >= 25)
				|| (SlushiFreeplayState.opponentVocals != null
					&& SlushiFreeplayState.opponentVocals.length > SlushiFreeplayState.instance.inst.time
					&& Math.abs(SlushiFreeplayState.instance.inst.time - SlushiFreeplayState.opponentVocals.time) >= 25))
			{
				pauseOrResume();
				setVocalsTime(SlushiFreeplayState.instance.inst.time);
				pauseOrResume(true);
			}
		}
		if (playingMusic)
		{
			positionSong();
			updateTimeTxt();
			updatePlaybackTxt();
		}
	}

	function setVocalsTime(time:Float)
	{
		if (SlushiFreeplayState.vocals != null && SlushiFreeplayState.vocals.length > time)
			SlushiFreeplayState.vocals.time = time;
		if (SlushiFreeplayState.opponentVocals != null && SlushiFreeplayState.opponentVocals.length > time)
			SlushiFreeplayState.opponentVocals.time = time;
	}

	public function pauseOrResume(resume:Bool = false)
	{
		if (resume)
		{
			if (!SlushiFreeplayState.instance.inst.playing)
				SlushiFreeplayState.instance.inst.resume();

			if (SlushiFreeplayState.vocals != null
				&& SlushiFreeplayState.vocals.length > SlushiFreeplayState.instance.inst.time
				&& !SlushiFreeplayState.vocals.playing)
				SlushiFreeplayState.vocals.resume();
			if (SlushiFreeplayState.opponentVocals != null
				&& SlushiFreeplayState.opponentVocals.length > SlushiFreeplayState.instance.inst.time
				&& !SlushiFreeplayState.opponentVocals.playing)
				SlushiFreeplayState.opponentVocals.resume();
		}
		else
		{
			SlushiFreeplayState.instance.inst.pause();

			if (SlushiFreeplayState.vocals != null)
				SlushiFreeplayState.vocals.pause();

			if (SlushiFreeplayState.opponentVocals != null)
				SlushiFreeplayState.opponentVocals.pause();
		}
	}

	function positionSong()
	{
		timeTxt.y = songTextY + 90;
		timeTxt.screenCenter(X);

		progressBar.setGraphicSize(Std.int(timeTxt.width), 5);
		progressBar.y = timeTxt.y + timeTxt.height;
		progressBar.screenCenter(X);

		playbackTxt.screenCenter();
		playbackTxt.y = progressBar.y + 50;

		for (i in 0...2)
		{
			var text = playbackSymbols[i];
			text.x = playbackTxt.x + playbackTxt.width / 2 - 10;
			text.y = playbackTxt.y;
			if (i == 0)
				text.y -= playbackTxt.height;
			else
				text.y += playbackTxt.height;
		}
	}

	public function switchPlayMusic()
	{
		active = visible = playingMusic;

		instance.scoreBG.visible = instance.diffText.visible = instance.scoreText.visible = !playingMusic; // Hide Freeplay texts and boxes if playingMusic is true

		timeTxt.visible = playbackTxt.visible = progressBar.visible = playingMusic; // Show Music Player texts and boxes if playingMusic is true

		for (i in playbackSymbols)
			i.visible = playingMusic;

		holdPitchTime = 0;
		instance.holdTime = 0;
		playbackRate = 1;
		updatePlaybackTxt();

		if (playingMusic)
		{
			#if !switch
			instance.downText.text = Language.getPhrase('musicplayer_tip', "Press SPACE to Pause / Press ESCAPE to Exit / Press R to Reset the Song");
			#else
			instance.downText.text = Language.getPhrase('musicplayer_tip_switch', "Press Y to Pause / Press X to Exit / Press MINUS to Reset the Song");
			#end
			instance.downText.screenCenter(X);
			positionSong();

			progressBar.setRange(0, SlushiFreeplayState.instance.inst.length);
			progressBar.setParent(SlushiFreeplayState.instance.inst, "time");
			progressBar.numDivisions = 1600;

			updateTimeTxt();
			// backgroundLol.alpha = .5;
		}
		else
		{
			progressBar.setRange(0, Math.POSITIVE_INFINITY);
			progressBar.setParent(null, "");
			progressBar.numDivisions = 0;

			instance.downText.text = instance.leText;
			instance.downText.screenCenter(X);
			// backgroundLol.alpha = 0;
		}
		progressBar.updateBar();
	}

	function updatePlaybackTxt()
	{
		var text = "";
		if (playbackRate is Int)
			text = playbackRate + '.00';
		else
		{
			var playbackRate = Std.string(playbackRate);
			if (playbackRate.split('.')[1].length < 2)
				playbackRate += '0';

			text = playbackRate;
		}
		playbackTxt.text = text + 'x';
	}

	function updateTimeTxt()
	{
		var text = FlxStringUtil.formatTime(FlxMath.roundDecimal(Conductor.songPosition / 1000 / playbackRate, 2), false)
			+ ' / '
			+ FlxStringUtil.formatTime(FlxMath.roundDecimal(SlushiFreeplayState.instance.inst.length / 1000 / playbackRate, 2), false);
		timeTxt.text = '< ' + text + ' >';
	}

	function setPlaybackRate()
	{
		SlushiFreeplayState.instance.inst.pitch = playbackRate;
		if (SlushiFreeplayState.vocals != null)
			SlushiFreeplayState.vocals.pitch = playbackRate;
		if (SlushiFreeplayState.opponentVocals != null)
			SlushiFreeplayState.opponentVocals.pitch = playbackRate;
	}

	function get_playing():Bool
	{
		return SlushiFreeplayState.instance.inst.playing;
	}

	function set_playbackRate(value:Float):Float
	{
		var value = FlxMath.roundDecimal(value, 2);
		if (value > 3)
			value = 3;
		else if (value <= 0.25)
			value = 0.25;
		return playbackRate = value;
	}
}