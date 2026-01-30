package slushi.states;

import substates.OutdatedSubState;
import backend.WeekData;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.util.FlxGradient;
import haxe.Json;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import shaders.ColorSwap;
import states.StoryMenuState;
import states.MainMenuState;
import states.FlashingState;

typedef TitleData =
{
	var titlex:Float;
	var titley:Float;
	var startx:Float;
	var starty:Float;
	var gfx:Float;
	var gfy:Float;
	var backgroundSprite:String;
	var bpm:Float;

	@:optional var animation:String;
	@:optional var dance_left:Array<Int>;
	@:optional var dance_right:Array<Int>;
	@:optional var idle:Bool;
}

class SwitchTitleState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;

	var credGroup:FlxGroup = new FlxGroup();
	var textGroup:FlxGroup = new FlxGroup();
	var blackScreen:FlxSprite;
	var credTextShit:Alphabet;
	var ngSpr:FlxSprite;

	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	var grayGrad:FlxSprite = null;
	var whiteGrad:FlxSprite = null;
	var grayTween:FlxTween;
	var whiteTween:FlxTween;
	var grayTweenColor:FlxTween;
	var whiteTweenColor:FlxTween;
	var joyconColors = {
		left: FlxColor.BLACK,
		right: FlxColor.BLACK
	};
	public static var backToSwitchTitle:Bool = false;

	override public function create():Void
	{
		Paths.clearStoredMemory();
		super.create();
		Paths.clearUnusedMemory();

		if (!initialized)
		{
			ClientPrefs.loadPrefs();
			Language.reloadPhrases();
		}

		curWacky = FlxG.random.getObject(getIntroTextShit());

		if (!initialized)
		{
			if (FlxG.save.data != null && FlxG.save.data.fullscreen)
			{
				FlxG.fullscreen = FlxG.save.data.fullscreen;
			}
			persistentUpdate = true;
			persistentDraw = true;
		}

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		SlushiMain.checkForUpdates();

		FlxG.mouse.visible = false;
		#if FREEPLAY
		MusicBeatState.switchState(new SlushiFreeplayState());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if (FlxG.save.data.flashing == null && !FlashingState.leftState)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		}
		else
			startIntro();
		#end
	}

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;

	function startIntro()
	{
		persistentUpdate = true;
		if (!initialized && FlxG.sound.music == null)
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

		loadJsonData();
		Conductor.bpm = musicBPM;

		#if switch
		joyconColors.left = SlushiMain.nxController.getJoyConColor(NXJoyCon.LEFT).colorMain;
		joyconColors.right = SlushiMain.nxController.getJoyConColor(NXJoyCon.RIGHT).colorMain;

		grayGrad = FlxGradient.createGradientFlxSprite(400, FlxG.height, [0x0, FlxColor.WHITE], 1, 0);
		grayGrad.x = -100;
		grayGrad.y = 0;
		grayGrad.flipX = true;

		whiteGrad = FlxGradient.createGradientFlxSprite(400, FlxG.height, [0x0, FlxColor.WHITE], 1, 0);
		whiteGrad.x = FlxG.width - 300;
		whiteGrad.y = 0;

		whiteGrad.alpha = 0;
		grayGrad.alpha = 0;
		grayGrad.visible = false;
		whiteGrad.visible = false;

		if (joyconColors.left == FlxColor.WHITE)
		{
			joyconColors.left = FlxColor.BLACK;
			whiteGrad.visible = false;
		}
		if (joyconColors.right == FlxColor.WHITE)
		{
			joyconColors.right = FlxColor.BLACK;
			grayGrad.visible = false;
		}
		#end

		logoBl = new FlxSprite(logoPosition.x, logoPosition.y);
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
		logoBl.antialiasing = ClientPrefs.data.antialiasing;

		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();

		gfDance = new FlxSprite(gfPosition.x, gfPosition.y);
		gfDance.antialiasing = ClientPrefs.data.antialiasing;

		if (ClientPrefs.data.shaders)
		{
			swagShader = new ColorSwap();
			gfDance.shader = swagShader.shader;
			logoBl.shader = swagShader.shader;
		}

		gfDance.frames = Paths.getSparrowAtlas(characterImage);
		if (!useIdle)
		{
			gfDance.animation.addByIndices('danceLeft', animationName, danceLeftFrames, "", 24, false);
			gfDance.animation.addByIndices('danceRight', animationName, danceRightFrames, "", 24, false);
			gfDance.animation.play('danceRight');
		}
		else
		{
			gfDance.animation.addByPrefix('idle', animationName, 24, false);
			gfDance.animation.play('idle');
		}

		var animFrames:Array<FlxFrame> = [];
		titleText = new FlxSprite(enterPosition.x, enterPosition.y);
		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		@:privateAccess
		{
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}

		if (newTitle = animFrames.length > 0)
		{
			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.data.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else
		{
			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}
		titleText.animation.play('idle');
		titleText.updateHitbox();

		blackScreen = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		blackScreen.scale.set(FlxG.width, FlxG.height);
		blackScreen.updateHitbox();
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();
		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.data.antialiasing;

		add(gfDance);
		add(logoBl);
		add(titleText);
		add(credGroup);
		add(ngSpr);

		if (initialized)
			skipIntro();
		else
			initialized = true;
	}

	// JSON data
	var characterImage:String = 'gfDanceTitle';
	var animationName:String = 'gfDance';

	var gfPosition:FlxPoint = FlxPoint.get(512, 40);
	var logoPosition:FlxPoint = FlxPoint.get(-150, -100);
	var enterPosition:FlxPoint = FlxPoint.get(100, 576);

	var useIdle:Bool = false;
	var musicBPM:Float = 102;
	var danceLeftFrames:Array<Int> = [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29];
	var danceRightFrames:Array<Int> = [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];

	function loadJsonData()
	{
		if (Paths.fileExists('images/gfDanceTitle.json', TEXT))
		{
			var titleRaw:String = Paths.getTextFromFile('images/gfDanceTitle.json');
			if (titleRaw != null && titleRaw.length > 0)
			{
				try
				{
					var titleJSON:TitleData = tjson.TJSON.parse(titleRaw);
					gfPosition.set(titleJSON.gfx, titleJSON.gfy);
					logoPosition.set(titleJSON.titlex, titleJSON.titley);
					enterPosition.set(titleJSON.startx, titleJSON.starty);
					musicBPM = titleJSON.bpm;

					if (titleJSON.animation != null && titleJSON.animation.length > 0)
						animationName = titleJSON.animation;
					if (titleJSON.dance_left != null && titleJSON.dance_left.length > 0)
						danceLeftFrames = titleJSON.dance_left;
					if (titleJSON.dance_right != null && titleJSON.dance_right.length > 0)
						danceRightFrames = titleJSON.dance_right;
					useIdle = (titleJSON.idle == true);

					if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.trim().length > 0)
					{
						var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image(titleJSON.backgroundSprite));
						bg.antialiasing = ClientPrefs.data.antialiasing;
						add(bg);
					}
				}
				catch (e:haxe.Exception)
				{
					SlDebug.log('[WARN] Title JSON might broken, ignoring issue...\n${e.details()}');
				}
			}
			else
				SlDebug.log('[WARN] No Title JSON detected, using default values.');
		}
	}

	function getIntroTextShit():Array<Array<String>>
	{
		#if MODS_ALLOWED
		var firstArray:Array<String> = Mods.mergeAllTextsNamed('data/introText.txt');
		#else
		var fullText:String = Assets.getText(Paths.txt('introText'));
		var firstArray:Array<String> = fullText.split('\n');
		#end
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;

	private static var playJingle:Bool = false;

	var newTitle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;

		#if switch
		if (backToSwitchTitle) {
			if (grayGrad != null && whiteGrad != null) {
				grayGrad.color = joyconColors.left;
				whiteGrad.color = joyconColors.right;
			}
			backToSwitchTitle = false;
		}

		if (joyconColors.left != SlushiMain.nxController.getJoyConColor(NXJoyCon.LEFT).colorMain) {
			joyconColors.left = SlushiMain.nxController.getJoyConColor(NXJoyCon.LEFT).colorMain;
			if (grayTweenColor != null)
				grayTweenColor.cancel();
			if (joyconColors.left == FlxColor.WHITE) {
				joyconColors.left = FlxColor.BLACK;
				grayGrad.visible = false;
			}
			else {
				grayGrad.visible = true;
			}
			grayTweenColor = FlxTween.color(grayGrad, 0.8, grayGrad.color, joyconColors.left, {ease: FlxEase.quadOut });
		}

		if (joyconColors.right != SlushiMain.nxController.getJoyConColor(NXJoyCon.RIGHT).colorMain) {
			joyconColors.right = SlushiMain.nxController.getJoyConColor(NXJoyCon.RIGHT).colorMain;
			if (whiteTweenColor != null)
				whiteTweenColor.cancel();
			if (joyconColors.right == FlxColor.WHITE) {
				joyconColors.right = FlxColor.BLACK;
				whiteGrad.visible = false;
			}
			else {
				whiteGrad.visible = true;
			}
			whiteTweenColor = FlxTween.color(whiteGrad, 0.8, whiteGrad.color, joyconColors.right, {ease: FlxEase.quadOut });
		}
		#end

		#if (mobile || switch)
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}

		if (newTitle)
		{
			titleTimer += FlxMath.bound(elapsed, 0, 1);
			if (titleTimer > 2)
				titleTimer -= 2;
		}

		if (initialized && !transitioning && skippedIntro)
		{
			if (newTitle && !pressedEnter)
			{
				var timer:Float = titleTimer;
				if (timer >= 1)
					timer = (-timer) + 2;

				timer = FlxEase.quadInOut(timer);

				titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
				titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
			}

			if (pressedEnter)
			{
				titleText.color = FlxColor.WHITE;
				titleText.alpha = 1;

				if (titleText != null)
					titleText.animation.play('press');

				FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;

				#if switch
				if (ClientPrefs.data.vibrating) {
					SlushiMain.nxController.vibration.vibrateBoth({
						joycon: NXJoyCon.LEFT,
						duration: 0.2,
						amplitude_low: 0.4,
						frequency_low: 0.4,
						amplitude_high: 0.4,
						frequency_high: 0.4
					});
				}
				#end

				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					MusicBeatState.switchState(new MainMenuState());
					closedState = true;
				});
			}
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		if (swagShader != null)
		{
			if (controls.UI_LEFT)
				swagShader.hue -= elapsed * 0.1;
			if (controls.UI_RIGHT)
				swagShader.hue += elapsed * 0.1;
		}

		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if (credGroup != null && textGroup != null)
			{
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if (textGroup != null && credGroup != null)
		{
			var coolText:Alphabet = new Alphabet(0, 0, text, true);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
		}
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0;

	public static var closedState:Bool = false;

	override function beatHit()
	{
		super.beatHit();

		if (logoBl != null)
			logoBl.animation.play('bump', true);

		if (gfDance != null)
		{
			danceLeft = !danceLeft;
			if (!useIdle)
			{
				if (danceLeft)
					gfDance.animation.play('danceRight');
				else
					gfDance.animation.play('danceLeft');
			}
			else if (curBeat % 2 == 0)
				gfDance.animation.play('idle', true);
		}

		#if switch
		if (skippedIntro && !transitioning)
		{
			if (joyconColors.left != FlxColor.BLACK)
			{
				grayGrad.visible = true;
			}
			if (joyconColors.right != FlxColor.BLACK)
			{
				whiteGrad.visible = true;
			}

			if (curBeat % 2 == 0)
			{
				if (grayTween != null)
					grayTween.cancel();
				if (whiteTween != null)
					whiteTween.cancel();

				grayTween = FlxTween.tween(grayGrad, {alpha: 0.7}, Conductor.crochet / 4000, {
					ease: FlxEase.quadIn,
					onComplete: function(twn:FlxTween)
					{
						grayTween = FlxTween.tween(grayGrad, {alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.quadOut
						});
					}
				});

				whiteTween = FlxTween.tween(whiteGrad, {alpha: 0.7}, Conductor.crochet / 4000, {
					ease: FlxEase.quadIn,
					onComplete: function(twn:FlxTween)
					{
						whiteTween = FlxTween.tween(whiteGrad, {alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.quadOut
						});
					}
				});
			}
		}
		#end

		if (!closedState)
		{
			sickBeats++;
			switch (sickBeats)
			{
				case 1:
					FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
					FlxG.sound.music.fadeIn(4, 0, 0.7);
				case 2:
					createCoolText(['Psych Engine by'], 40);
				case 4:
					addMoreText('Shadow Mario', 40);
					addMoreText('Riveren', 40);
					#if switch
					if (ClientPrefs.data.vibrating)
					{
						SlushiMain.nxController.vibration.vibrateBoth({
							joycon: NXJoyCon.LEFT,
							duration: 0.1,
							amplitude_low: 0.2,
							frequency_low: 0.2,
							amplitude_high: 0.2,
							frequency_high: 0.2
						});
					}
					#end
				case 5:
					deleteCoolText();
				case 6:
					createCoolText(['Not associated', 'with'], -40);
				case 8:
					addMoreText('newgrounds', -40);
					ngSpr.visible = true;
					#if switch
					if (ClientPrefs.data.vibrating) {
						SlushiMain.nxController.vibration.vibrateBoth({
							joycon: NXJoyCon.LEFT,
							duration: 0.1,
							amplitude_low: 0.2,
							frequency_low: 0.2,
							amplitude_high: 0.2,
							frequency_high: 0.2
						});
					}
					#end
				case 9:
					deleteCoolText();
					ngSpr.visible = false;
				case 10:
					createCoolText([curWacky[0]]);
				case 12:
					addMoreText(curWacky[1]);
				case 13:
					deleteCoolText();
				case 14:
					
					addMoreText('Friday');
					#if switch
					if (ClientPrefs.data.vibrating) {
						SlushiMain.nxController.vibration.vibrateBoth({
							joycon: NXJoyCon.LEFT,
							duration: 0.1,
							amplitude_low: 0.4,
							frequency_low: 0.4,
							amplitude_high: 0.4,
							frequency_high: 0.4
						});
					}
					#end
				case 15:
					addMoreText('Night');
					#if switch
					if (ClientPrefs.data.vibrating) {
						SlushiMain.nxController.vibration.vibrateBoth({
							joycon: NXJoyCon.LEFT,
							duration: 0.1,
							amplitude_low: 0.4,
							frequency_low: 0.4,
							amplitude_high: 0.4,
							frequency_high: 0.4
						});
					}
					#end
				case 16:
					addMoreText('Funkin');
					#if switch
					addMoreText('On Nintendo Switch!');
					if (ClientPrefs.data.vibrating) {
						SlushiMain.nxController.vibration.vibrateBoth({
							joycon: NXJoyCon.LEFT,
							duration: 0.3,
							amplitude_low: 0.6,
							frequency_low: 0.6,
							amplitude_high: 0.6,
							frequency_high: 0.6
						});
					}
					#end
				case 17:
					skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;

	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			remove(ngSpr);
			remove(credGroup);
			FlxG.camera.flash(FlxColor.WHITE, 4);
			skippedIntro = true;

			#if switch
			if (grayGrad != null)
				add(grayGrad);
			if (whiteGrad != null)
				add(whiteGrad);
			#end
		}
	}
}