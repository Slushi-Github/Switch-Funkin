package slushi.states.freeplay;

import slushi.others.SlushiUtils;
import flixel.effects.FlxFlicker;
import flixel.math.FlxMath;
import flixel.util.FlxStringUtil;
import flixel.util.FlxDestroyUtil;
import haxe.Json;
import backend.WeekData;
import backend.Highscore;
import backend.Song;
import openfl.utils.Assets;
import slushi.states.freeplay.SlushiMusicPlayer;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import slushi.states.freeplay.SlushiFreeplayHealthIcon;
import states.MainMenuState;
import states.StoryMenuState;
import states.editors.WeekEditorState;
import states.ErrorState;
import objects.Character.CharacterFile;
import objects.Character;
import flixel.addons.effects.FlxTrail;
import backend.PsychCamera;

/**
 * Custom freeplay state
 * 
 * Ported from Slushi Engine
 * 
 * Author: Slushi
 */
class SlushiFreeplayState extends MusicBeatState
{
	public static var instance:SlushiFreeplayState = null;
	private static var lastDifficultyName:String = Difficulty.getDefault();
	private static var curSelected:Int = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;
	private var iconArray:Array<SlushiFreeplayHealthIcon> = [];

	public var rate:Float = 1.0;
	public var lastRate:Float = 1.0;

	public var scoreBG:FlxSprite;
	public var scoreText:FlxText;
	public var diffText:FlxText;
	public var downText:FlxText;

	public var leText:String = "";

	public var scorecolorDifficulty:Map<String, FlxColor> = ['EASY' => FlxColor.GREEN, 'NORMAL' => FlxColor.YELLOW, 'HARD' => FlxColor.RED];

	public var curStringDifficulty:String = 'NORMAL';

	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;

	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;
	var rating:String;
	var combo:String = 'N/A';

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var opponentMode:Bool = false;

	var bg:FlxSprite;
	var intendedColor:Int;
	var player:SlushiMusicPlayer;

	var inst:FlxSound;

	var camNotes:FlxCamera;
	var camBG:FlxCamera;

	public var camSongs:FlxCamera;

	override function create()
	{
		instance = this;

		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		if (WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new WeekEditorState()), function() MusicBeatState.switchState(new MainMenuState())));
			return;
		}

		camNotes = initPsychCamera();
		camBG = new FlxCamera();
		camSongs = new FlxCamera();
		camNotes.bgColor.alpha = 0;
		camBG.bgColor.alpha = 0;
		camSongs.bgColor.alpha = 0;
		FlxG.cameras.add(camNotes, false);
		FlxG.cameras.add(camBG, false);
		FlxG.cameras.add(camSongs, false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Searching to play song - SL Freeplay Menu', null);
		#end

		for (i in 0...WeekData.weeksList.length)
		{
			if (weekIsLocked(WeekData.weeksList[i]))
				continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			WeekData.setDirectoryFromWeek(leWeek);

			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if (colors == null || colors.length < 3)
					colors = [146, 113, 253];
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		Mods.loadTopMod();

		bg = new FlxSprite().loadGraphic(SlushiMain.getPath('SlushiFreeplayStateAssets/BG.png'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();
		bg.camera = camBG;

		grpSongs = new FlxTypedGroup<Alphabet>();

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.targetY = i;
			songText.screenCenter(X);
			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;
			var icon:SlushiFreeplayHealthIcon = new SlushiFreeplayHealthIcon(songs[i].songCharacter);
			icon.songTxtTracker = songText;

			songText.visible = songText.active = songText.isMenuItem = false;
			icon.visible = icon.active = false;

			iconArray.push(icon);
			add(icon);
			icon.camera = camSongs;
			grpSongs.add(songText);
		}

		add(grpSongs);
		grpSongs.camera = camSongs;

		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);

		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 27, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);

		#if !switch
		leText = Language.getPhrase("freeplay_tip",
			"Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.");
		#else
		leText = Language.getPhrase("freeplay_tip_switch",
			"Press X to listen to the Song / Press Y to open the Gameplay Changers Menu / Press MINUS to Reset your Score and Accuracy.");
		#end
		downText = new FlxText(0, FlxG.height - 26, 0, leText, 24);
		downText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, LEFT);
		downText.antialiasing = ClientPrefs.data.antialiasing;
		downText.scrollFactor.set();
		downText.screenCenter(X);
		add(downText);

		for (obj in [scoreText, diffText, downText, missingText, textBG, missingTextBG, scoreBG])
		{
			if (obj != null)
				obj.camera = camSongs;
		}

		if (curSelected >= songs.length)
			curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		player = new SlushiMusicPlayer(this);
		add(player);

		changeSelection();
		updateTexts();
		positionHighscore();
		super.create();
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		changeDiff(0);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked
			&& leWeek.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;

	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;

	var holdTime:Float = 0;
	var stopMusicPlay:Bool = false;

	override function update(elapsed:Float)
	{
		if (WeekData.weeksList.length < 1)
		{
			super.update(elapsed);
			return;
		}

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (player != null && player.playingMusic)
		{
			var bpmRatio = Conductor.bpm / 100;
			if (ClientPrefs.data.camZooms)
			{
				FlxG.camera.zoom = FlxMath.lerp(1, FlxG.camera.zoom, SlushiUtils.boundTo(1 - (elapsed * 3.125 * bpmRatio * player.playbackRate), 0, 1));
			}

			for (i in 0...iconArray.length)
			{
				if (iconArray[i] != null)
				{
					var mult:Float = FlxMath.lerp(1, iconArray[i].scale.x, SlushiUtils.boundTo(1 - (elapsed * 35 * player.playbackRate), 0, 1));
					iconArray[i].scale.set(mult, mult);
					iconArray[i].updateHitbox();
				}
			}

			#if DISCORD_ALLOWED
			DiscordClient.changePresence('Listening to ' + Paths.formatToSongPath(songs[curSelected].songName), null);
			#end
		}

		if (!player.playingMusic)
		{
			if (FlxG.camera.zoom != 1)
				FlxG.camera.zoom = 1;
			#if DISCORD_ALLOWED
			DiscordClient.changePresence('Searching to play song - SL Freeplay Menu', null);
			#end
		}

		var mult:Float = FlxMath.lerp(1, bg.scale.x, SlushiUtils.clamp(1 - (elapsed * 9), 0, 1));
		bg.scale.set(mult, mult);
		bg.updateHitbox();
		bg.offset.set();

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if (ratingSplit.length < 2)
			ratingSplit.push('');

		while (ratingSplit[1].length < 2)
			ratingSplit[1] += '0';

		var shiftMult:Int = 1;
		if (FlxG.keys.pressed.SHIFT)
			shiftMult = 3;

		if (player != null && !player.playingMusic)
		{
			scoreText.text = Language.getPhrase('personal_best', 'PERSONAL BEST: {1} ({2}%)', [lerpScore, ratingSplit.join('.')]);
			positionHighscore();

			if (songs.length > 1)
			{
				if (FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;
				}
				else if (FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if (FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		if (controls.BACK)
		{
			if (player != null && player.playingMusic)
			{
				destroyFreeplayVocals();
				inst.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.music.volume = 0;
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
		}

		if (FlxG.keys.justPressed.CONTROL || FlxG.gamepads.anyJustPressed(#if switch X #else Y #end) && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if (FlxG.keys.justPressed.SPACE || FlxG.gamepads.anyJustPressed(#if switch Y #else X #end))
		{
			playSong();
		}
		else if (controls.RESET && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			persistentUpdate = false;
			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

			try
			{
				Song.loadFromJson(poop, songLowercase);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;

				#if switch
				if (ClientPrefs.data.vibrating)
				{
					SlushiMain.nxController.vibration.vibrateBoth({
						joycon: NXJoyCon.LEFT,
						duration: 0.4,
						amplitude_low: 0.4,
						frequency_low: 0.4,
						amplitude_high: 0.4,
						frequency_high: 0.4
					});
				}
				#end

				LoadingState.prepareToSong();
				LoadingState.loadAndSwitchState(new PlayState());
				#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
				stopMusicPlay = true;

				destroyFreeplayVocals();
				#if (MODS_ALLOWED && DISCORD_ALLOWED)
				DiscordClient.loadModRPC();
				#end
			}
			catch (e:haxe.Exception)
			{
				var errorStr:String = e.message;
				if (errorStr.contains('There is no TEXT asset with an ID of'))
					errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length - 1);
				else
					errorStr += '\n\n' + e.stack;

				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
		}

		updateTexts(elapsed);
		super.update(elapsed);
	}

	private function playSong():Void
	{
		if (instPlaying != curSelected && !player.playingMusic)
		{
			destroyFreeplayVocals();
			FlxG.sound.music.volume = 0;

			Mods.currentModDirectory = songs[curSelected].folder;
			var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
			Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());

			if (PlayState.SONG.needsVoices)
			{
				vocals = new FlxSound();
				try
				{
					var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
					var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
					if (loadedVocals == null)
						loadedVocals = Paths.voices(PlayState.SONG.song);

					if (loadedVocals != null && loadedVocals.length > 0)
					{
						vocals.loadEmbedded(loadedVocals);
						FlxG.sound.list.add(vocals);
						vocals.persist = vocals.looped = true;
						vocals.volume = 0.8;
						vocals.play();
						vocals.pause();
					}
					else
						vocals = FlxDestroyUtil.destroy(vocals);
				}
				catch (e:Dynamic)
				{
					vocals = FlxDestroyUtil.destroy(vocals);
				}

				opponentVocals = new FlxSound();
				try
				{
					var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
					var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');

					if (loadedVocals != null && loadedVocals.length > 0)
					{
						opponentVocals.loadEmbedded(loadedVocals);
						FlxG.sound.list.add(opponentVocals);
						opponentVocals.persist = opponentVocals.looped = true;
						opponentVocals.volume = 0.8;
						opponentVocals.play();
						opponentVocals.pause();
					}
					else
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
				}
				catch (e:Dynamic)
				{
					opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
				}
			}

			inst = FlxG.sound.play(Paths.inst(PlayState.SONG.song), 0.8);
			inst.pause();
			instPlaying = curSelected;

			player.playingMusic = true;
			player.curTime = 0;
			player.switchPlayMusic();
			player.pauseOrResume(true);
		}
		else if (instPlaying == curSelected && player.playingMusic)
		{
			player.pauseOrResume(!player.playing);
		}
	}

	function getVocalFromCharacter(char:String):String
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic)
		{
		}
		return null;
	}

	public static function destroyFreeplayVocals()
	{
		if (vocals != null)
			vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if (opponentVocals != null)
			opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		#if switch
		if (ClientPrefs.data.vibrating)
		{
			SlushiMain.nxController.vibration.vibrateBoth({
				joycon: NXJoyCon.LEFT,
				duration: 0.2,
				amplitude_low: 0.2,
				frequency_low: 0.2,
				amplitude_high: 0.2,
				frequency_high: 0.2
			});
		}
		#end

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length - 1);

		// #if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		// #end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();

		curStringDifficulty = lastDifficultyName;

		missingText.visible = false;
		missingTextBG.visible = false;
		diffText.alpha = 1;

		positionHighscore();

		FlxTween.color(diffText, 0.3, diffText.color,
			scorecolorDifficulty.exists(curStringDifficulty) ? scorecolorDifficulty.get(curStringDifficulty) : FlxColor.WHITE, {
				ease: FlxEase.quadInOut
			});
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
		_updateSongLastDifficulty();
		if (playSound)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var newColor:Int = songs[curSelected].color;
		if (newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpSongs.members)
		{
			var icon:SlushiFreeplayHealthIcon = iconArray[num];
			icon.alpha = item.alpha = (item.targetY == curSelected) ? 1 : 0.2;
		}

		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();

		#if switch
		if (ClientPrefs.data.vibrating)
		{
			SlushiMain.nxController.vibration.vibrateBoth({
				joycon: NXJoyCon.LEFT,
				duration: 0.2,
				amplitude_low: 0.2,
				frequency_low: 0.2,
				amplitude_high: 0.2,
				frequency_high: 0.2
			});
		}
		#end

		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if (savedDiff != null && !Difficulty.list.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if (lastDiff > -1)
			curDifficulty = lastDiff;
		else if (Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
	{
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);
	}

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];

	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
			iconArray[i].visible = iconArray[i].active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			var item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;

			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.screenCenter(X);
			item.y = ((item.targetY - lerpSelected) * 1.8 * item.distancePerItem.y) + item.startPosition.y;

			var icon:SlushiFreeplayHealthIcon = iconArray[i];
			icon.visible = icon.active = true;
			_lastVisibles.push(i);
		}
	}

	override function beatHit()
	{
		super.beatHit();

		if (!player.playingMusic)
			return;

		if (curBeat % 2 == 0)
		{
			if (ClientPrefs.data.camZooms)
			{
				FlxG.camera.zoom += 0.03;
				FlxTween.tween(FlxG.camera, {zoom: 1}, Conductor.crochet / 1300, {
					ease: FlxEase.quadOut
				});
			}
		}
	}

	override function stepHit()
	{
		super.stepHit();

		if (!player.playingMusic)
			return;

		if (curStep % 4 == 0)
		{
			noteEffect();
		}
		else
		{
			noteEffectUP();
		}
	}

	private function noteEffect()
	{
		if (ClientPrefs.data.lowQuality || !ClientPrefs.data.flashing)
			return;

		var note:FlxSprite = new FlxSprite().loadGraphic(SlushiMain.getPath("SlushiFreeplayStateAssets/DANOTE.png"));
		note.antialiasing = ClientPrefs.data.antialiasing;
		note.camera = camNotes;
		var randomFloat:Float = FlxG.random.float(0.3, 0.6);
		note.scale.set(randomFloat, randomFloat);
		note.updateHitbox();
		note.y = -200;
		note.x = FlxG.random.int(0, FlxG.width);
		note.angle = FlxG.random.int(0, 360);
		note.alpha = 0.3;

		var noteRGBFirstColumn:Array<FlxColor> = [];
		for (row in ClientPrefs.data.arrowRGB)
		{
			noteRGBFirstColumn.push(row[0]);
		}

		var randomIndex:Int = FlxG.random.int(0, noteRGBFirstColumn.length - 1);
		note.color = noteRGBFirstColumn[randomIndex];
		add(note);

		var noteTrail = new FlxTrail(note, null, 2, 4, 0.15, 0.10);
		noteTrail.camera = camNotes;
		noteTrail.alpha = 0.3;
		noteTrail.color = note.color;
		add(noteTrail);
		FlxTween.tween(noteTrail, {alpha: 0}, 2, {ease: FlxEase.quadInOut});
		FlxTween.tween(note, {
			x: note.x - 125,
			y: 730,
			angle: note.angle + 360,
			alpha: 0
		}, 2, {
			ease: FlxEase.quadInOut,
			onComplete: function(twn:FlxTween)
			{
				remove(note);
				remove(noteTrail);
				note.destroy();
				noteTrail.destroy();
			}
		});
	}

	private function noteEffectUP()
	{
		if (ClientPrefs.data.lowQuality || !ClientPrefs.data.flashing)
			return;

		var note:FlxSprite = new FlxSprite().loadGraphic(SlushiMain.getPath("SlushiFreeplayStateAssets/DANOTE.png"));
		note.antialiasing = ClientPrefs.data.antialiasing;
		note.camera = camNotes;
		note.scale.set(0.5, 0.5);
		note.updateHitbox();
		note.y = FlxG.height + 100;
		note.x = FlxG.random.int(0, FlxG.width);
		note.angle = FlxG.random.int(0, 360);
		note.alpha = 0.3;

		var firstColumn:Array<FlxColor> = [];
		for (row in ClientPrefs.data.arrowRGB)
		{
			firstColumn.push(row[0]);
		}

		var randomIndex:Int = FlxG.random.int(0, firstColumn.length - 1);
		note.color = firstColumn[randomIndex];
		add(note);

		var noteTrail = new FlxTrail(note, null, 2, 4, 0.15, 0.10);
		noteTrail.camera = camNotes;
		noteTrail.alpha = 0.3;
		noteTrail.color = note.color;
		insert(members.indexOf(note), noteTrail);
		FlxTween.tween(noteTrail, {alpha: 0}, 2, {ease: FlxEase.quadInOut});
		FlxTween.tween(note, {
			x: note.x - 125,
			y: 0,
			angle: note.angle + 360,
			alpha: 0
		}, 2, {
			ease: FlxEase.quadInOut,
			onComplete: function(twn:FlxTween)
			{
				remove(note);
				remove(noteTrail);
				note.destroy();
				noteTrail.destroy();
			}
		});
	}

	override function destroy()
	{
		destroyFreeplayVocals();
		if (player != null)
			player.destroy();
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (inst != null && !inst.playing && !stopMusicPlay && !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if (this.folder == null)
			this.folder = '';
	}
}