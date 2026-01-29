package;

#if android
import android.content.Context;
#end

import debug.FPSCounter;

import flixel.graphics.FlxGraphic;
import flixel.FlxGame;
import flixel.FlxState;
import haxe.io.Path;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import lime.app.Application;
import haxe.PosInfos;

import states.TitleState;
import slushi.states.InAppletModeState;

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import psychlua.HScript.HScriptInfos;
#end

#if (linux || mac)
import lime.graphics.Image;
#end

#if desktop
import backend.ALSoftConfig; // Just to make sure DCE doesn't remove this, since it's not directly referenced anywhere else.
#end

//crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#end

import backend.Highscore;

// NATIVE API STUFF, YOU CAN IGNORE THIS AND SCROLL //
#if (linux && !debug)
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end

// // // // // // // // //
class Main extends Sprite
{
	public static final game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: SwitchTitleState, // initial game state
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var fpsVar:FPSCounter;

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		#if CRASH_HANDLER
		untyped __global__.__hxcpp_set_critical_error_handler(onHXCPPError);
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		#if (cpp && windows)
		backend.Native.fixScaling();
		#end

		// Credits to MAJigsaw77 (he's the og author for this code)
		#if android
		Sys.setCwd(Path.addTrailingSlash(Context.getExternalFilesDir()));
		#elseif ios
		Sys.setCwd(lime.system.System.applicationStorageDirectory);
		#elseif switch
		Sys.setCwd("romfs:/");
		#end

		#if (VIDEOS_ALLOWED && !switch)
		hxvlc.util.Handle.init(#if (hxvlc >= "1.8.0")  ['--no-lua'] #end);
		#end

		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if switch
		flixel.util.FlxSave._SWITCH_SAVE_PATH = "sdmc:/switch/Switch-Funkin/saves";
		FlxG.save.bind('funkin', 'SwitchFunkinSave');
		#else
		FlxG.save.bind('funkin', CoolUtil.getSavePath());
		#end
		Highscore.load();

		#if HSCRIPT_ALLOWED
		Iris.warn = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(WARN, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('WARNING: $msgInfo', FlxColor.YELLOW);
		}
		Iris.error = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(ERROR, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('ERROR: $msgInfo', FlxColor.RED);
		}
		Iris.fatal = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(FATAL, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('FATAL: $msgInfo', 0xFFBB0000);
		}
		#end

		haxe.Log.trace = function(v:Dynamic, ?infos:PosInfos) {
			SlDebug.log(v, INFO, infos);
		}

		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end

		#if switch
		SlushiMain.init();
		#end

		#if switch
		addChild(new SlGame(game.width, game.height, SwitchUtils.isRunningAsApplet() ? InAppletModeState : game.initialState, game.framerate, game.framerate, game.skipSplash, game.startFullscreen));
		#else
		addChild(new FlxGame(game.width, game.height, game.initialState, game.framerate, game.framerate, game.skipSplash, game.startFullscreen));
		#end

		#if !mobile
		fpsVar = new FPSCounter(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.data.showFPS;
		}
		#end

		#if (linux || mac) // fix the app icon not showing up on the Linux Panel / Mac Dock
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];

		#if DISCORD_ALLOWED
		DiscordClient.prepare();
		#end

		// shader coords fix
		FlxG.signals.gameResized.add(function (w, h) {
		     if (FlxG.cameras != null) {
			   for (cam in FlxG.cameras.list) {
				if (cam != null && cam.filters != null)
					resetSpriteCache(cam.flashSprite);
			   }
			}

			if (FlxG.game != null)
			resetSpriteCache(FlxG.game);
		});
	}

	static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
		        sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "Switch Funkin' has crashed!\n\nHaxe call stack:\n";
		var editorError:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = #if switch "sdmc:/switch/Switch-Funkin/crash/" #else "./crash/" #end + "SwitchFunkin_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
					if (editorError == "")
					{
						// Underline only the first line
						editorError += "\033[4m" + file + "#" + line + "\033[24m\n";
					}
					else
					{
						editorError += file + "#" + line + "\n";
					}
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nError: " + e.error;
		errMsg += "\n--------\nPlease report this error to the GitHub page: https://github.com/Slushi-Github/Switch-Funkin/issues\n";

		#if !switch
		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");
		#else
		if (!FileSystem.exists("sdmc:/switch/Switch-Funkin/crash/"))
			FileSystem.createDirectory("sdmc:/switch/Switch-Funkin/crash/");
		#end

		File.saveContent(path, errMsg + "\n");

		Sys.println("\n\nENGINE CRASH!\nHaxe call stack:\n" + editorError + "\n--------\nError: " + e.error);
		Sys.println("Crash dump saved in " + Path.normalize(path) + "\n\n");

		#if !switch
		Application.current.window.alert(errMsg, "Switch Funkin' - Engine Crash!");
		#else
		SwitchUtils.showError(0, errMsg);
		#end

		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end

		SlushiMain.destroy();
		
		Sys.exit(1);
	}

	/**
	 * Handle critical errors of HXCPP
	 * @param message The error message
	 */
	private static function onHXCPPError(message:Dynamic):Void
	{
		var mainText:String = '\nSwitch Funkin - HXCPP side critical error!:\n';
		var editorError:String = "\nENGINE CRASH! - HXCPP CRITICAL ERROR:\nHaxe call stack:\n";

		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var callStackText:String = "Haxe call stack:\n";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					callStackText += file + " (line " + line + ")\n";
					if (editorError == "")
					{
						// Underline only the first line
						editorError += "\033[4m" + file + "#" + line + "\033[24m\n";
					}
					else
					{
						editorError += file + "#" + line + "\n";
					}
				case CFunction:
					callStackText += "Non-Haxe (C) Function\n";
				case Module(c):
					callStackText += 'Module ${c}\n';
				default:
					callStackText += stackItem + '\n';
			}
		}

		mainText += callStackText + '\n\nError: ' + message;

		var path:String = #if switch "sdmc:/switch/Switch-Funkin/crash/SwitchFunkinCPP_" #else "./crash/SwitchFunkinCPP_" #end
			+ Date.now().toString().replace(" ", "_").replace(":", "'")
			+ ".txt";

		#if switch
		if (!FileSystem.exists("sdmc:/switch/Switch-Funkin/crash/"))
			FileSystem.createDirectory("sdmc:/switch/Switch-Funkin/crash/");
		#else
		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");
		#end
		File.saveContent(path, mainText);

		Sys.println(editorError + "\n------\nError: " + message);

		#if !switch
		Application.current.window.alert(mainText, "Switch Funkin' - HXCPP CRASH!");
		#else
		SwitchUtils.showError(0, mainText);
		#end

		SlushiMain.destroy();

		Sys.exit(1);
	}
	#end
}
