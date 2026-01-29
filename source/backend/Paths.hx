package backend;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;
import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
#if !switch
import openfl.utils.Assets as OpenFlAssets;
#end
import openfl.system.System;
import openfl.geom.Rectangle;
import lime.utils.Assets;
import flash.media.Sound;
import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
#if MODS_ALLOWED
import backend.Mods;
#end

@:access(openfl.display.BitmapData)
class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	#if switch
	inline public static var ROOT_PATH = "romfs:/";
	inline public static var MODS_PATH = "sdmc:/switch/Switch-Funkin/mods";

	// Convert asset path to filesystem path (adds romfs:/ prefix)
	public static function toFileSystemPath(path:String):String
	{
		// If it's already a mod path (sdmc:/), normalize it
		if (path.startsWith("sdmc:/"))
			return normalizeModPath(path);

		// For asset paths, add romfs:/ prefix
		// Remove duplicates first
		while (path.indexOf("romfs:/romfs:/") == 0)
			path = path.substr(7);

		if (!path.startsWith("romfs:/"))
			path = "romfs:/" + path;

		return path;
	}

	static function normalizeModPath(path:String):String
	{
		// Remove duplicate sdmc:/ prefixes
		while (path.indexOf("sdmc:/sdmc:/") == 0)
			path = path.substr(6);

		// Remove any romfs:/ prefix from mod paths
		if (path.startsWith("romfs:/"))
			path = path.substr(7);

		// Ensure we have exactly one sdmc:/ prefix for mods
		if (!path.startsWith("sdmc:/"))
			path = "sdmc:/" + path;

		return path;
	}
	#end

	public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = ['assets/shared/music/freakyMenu.$SOUND_EXT'];

	// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				destroyGraphic(currentTrackedAssets.get(key)); // get rid of the graphic
				currentTrackedAssets.remove(key); // and remove the key from local cache map
			}
		}

		// run the garbage collector for good measure lmfao
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key))
				destroyGraphic(FlxG.bitmap.get(key));
		}

		// clear all sounds that are cached
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = [];
		function checkForGraphics(spr:Dynamic)
		{
			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
				if (grp != null)
				{
					// SlDebug.log('is actually a group');
					for (member in grp)
					{
						checkForGraphics(member);
					}
					return;
				}
			}

			// SlDebug.log('check...');
			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
				if (gfx != null)
				{
					protectedGfx.push(gfx);
					// SlDebug.log('gfx added to the list successfully!');
				}
			}
			// catch(haxe.Exception) {}
		}

		for (member in FlxG.state.members)
			checkForGraphics(member);

		if (FlxG.state.subState != null)
			for (member in FlxG.state.subState.members)
				checkForGraphics(member);

		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);
				if (!protectedGfx.contains(graphic))
				{
					destroyGraphic(graphic); // get rid of the graphic
					currentTrackedAssets.remove(key); // and remove the key from local cache map
					// SlDebug.log('deleted $key');
				}
			}
		}
	}

	inline static function destroyGraphic(graphic:FlxGraphic)
	{
		// free some gpu memory
		if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null)
			graphic.bitmap.__texture.dispose();
		FlxG.bitmap.remove(graphic);
	}

	static public var currentLevel:String;

	static public function setCurrentLevel(name:String)
		currentLevel = name.toLowerCase();

	public static function getPath(file:String, ?type:AssetType = TEXT, ?parentfolder:String, ?modsAllowed:Bool = true):String
	{
		#if MODS_ALLOWED
		if (modsAllowed)
		{
			var customFile:String = file;
			if (parentfolder != null)
				customFile = '$parentfolder/$file';

			var modded:String = modFolders(customFile);
			#if switch
			if (FileSystem.exists(toFileSystemPath(modded)))
				return modded;
			#else
			if (FileSystem.exists(modded))
				return modded;
			#end
		}
		#end

		if (parentfolder != null)
			return getFolderPath(file, parentfolder);

		if (currentLevel != null && currentLevel != 'shared')
		{
			var levelPath = getFolderPath(file, currentLevel);
			#if switch
			if (FileSystem.exists(toFileSystemPath(levelPath)))
				return levelPath;
			#else
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
			#end
		}
		return getSharedPath(file);
	}

	// Returns paths WITHOUT romfs:/ prefix - compatible with both sys and Assets APIs
	inline static public function getFolderPath(file:String, folder = "shared")
		return 'assets/$folder/$file';

	inline public static function getSharedPath(file:String = '')
		return 'assets/shared/$file';

	inline static public function txt(key:String, ?folder:String)
		return getPath('data/$key.txt', TEXT, folder, true);

	inline static public function xml(key:String, ?folder:String)
		return getPath('data/$key.xml', TEXT, folder, true);

	inline static public function json(key:String, ?folder:String)
		return getPath('data/$key.json', TEXT, folder, true);

	inline static public function shaderFragment(key:String, ?folder:String)
		return getPath('shaders/$key.frag', TEXT, folder, true);

	inline static public function shaderVertex(key:String, ?folder:String)
		return getPath('shaders/$key.vert', TEXT, folder, true);

	inline static public function lua(key:String, ?folder:String)
		return getPath('$key.lua', TEXT, folder, true);

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		#if switch
		// Check mods with proper filesystem path
		var fsPath = toFileSystemPath(file);
		if (FileSystem.exists(fsPath))
			return fsPath; // Return with romfs:/ or sdmc:/ prefix
		#else
		if (FileSystem.exists(file))
			return file;
		#end
		#end

		// Return asset path with proper prefix for Switch
		var assetPath = 'assets/videos/$key.$VIDEO_EXT';
		#if switch
		return toFileSystemPath(assetPath);
		#else
		return assetPath;
		#end
	}

	inline static public function sound(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('sounds/$key', modsAllowed);

	inline static public function music(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('music/$key', modsAllowed);

	inline static public function inst(song:String, ?modsAllowed:Bool = true):Sound
		return returnSound('${formatToSongPath(song)}/Inst', 'songs', modsAllowed);

	inline static public function voices(song:String, postfix:String = null, ?modsAllowed:Bool = true):Sound
	{
		var songKey:String = '${formatToSongPath(song)}/Voices';
		if (postfix != null)
			songKey += '-' + postfix;
		// SlDebug.log('songKey test: $songKey');
		return returnSound(songKey, 'songs', modsAllowed, false);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?modsAllowed:Bool = true)
		return sound(key + FlxG.random.int(min, max), modsAllowed);

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];

	static public function image(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		// 1. Obtenemos la clave de traducción (ej: 'images/tankmanKilled1')
		var translatedKey:String = Language.getFileTranslation('images/$key') + '.png';

		// 2. Si ya está en caché, lo devolvemos directamente
		if (currentTrackedAssets.exists(translatedKey))
		{
			localTrackedAssets.push(translatedKey);
			return currentTrackedAssets.get(translatedKey);
		}

		// 3. Obtenemos la ruta real del archivo (ej: 'assets/shared/images/tankmanKilled1.png')
		var path:String = getPath(translatedKey, IMAGE, parentFolder);
		var bitmap:BitmapData = null;

		#if MODS_ALLOWED
		// 4. Lógica para Switch y sistemas de archivos (Mods/Storage)
		var fsPath:String = path;
		#if switch
		fsPath = toFileSystemPath(path);
		#end

		if (FileSystem.exists(fsPath))
		{
			// Cargamos el bitmap directamente del sistema de archivos
			bitmap = BitmapData.fromFile(fsPath);
		}
		#end

		// 5. Enviamos el bitmap a cacheBitmap.
		// Si bitmap es null, cacheBitmap intentará cargarlo desde Assets automáticamente.
		return cacheBitmap(translatedKey, parentFolder, bitmap, allowGPU);
	}

	public static function cacheBitmap(key:String, ?parentFolder:String = null, ?bitmap:BitmapData, ?allowGPU:Bool = true):FlxGraphic
	{
		if (bitmap == null)
		{
			var file:String = getPath(key, IMAGE, parentFolder, true);

			#if MODS_ALLOWED
			var fsPath = #if switch toFileSystemPath(file) #else file #end;
			if (FileSystem.exists(fsPath))
				bitmap = BitmapData.fromFile(fsPath);
			#end

			// FALLBACK PARA SWITCH (Sin usar OpenFlAssets)
			#if switch
			if (bitmap == null)
			{
				var romfsPath = toFileSystemPath(getPath(key, IMAGE, parentFolder, false));
				if (FileSystem.exists(romfsPath))
					bitmap = BitmapData.fromFile(romfsPath);
			}
			#else
			if (bitmap == null)
			{
				if (OpenFlAssets.exists(file, IMAGE))
					bitmap = OpenFlAssets.getBitmapData(file);
			}
			#end

			if (bitmap == null)
			{
				SlDebug.log('Bitmap not found: $file | key: $key', ERROR);
				return null;
			}
		}

		if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null)
		{
			bitmap.lock();
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.image.data = null;
			bitmap.image = null;
			bitmap.readable = true;
		}

		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(key, graph);
		localTrackedAssets.push(key);
		return graph;
	}

	inline static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		var path:String = getPath(key, TEXT, !ignoreMods);
		#if sys // Switch usa sys
		var fsPath = #if switch toFileSystemPath(path) #else path #end;
		return (FileSystem.exists(fsPath)) ? File.getContent(fsPath) : null;
		#else
		return (OpenFlAssets.exists(path, TEXT)) ? OpenFlAssets.getText(path) : null;
		#end
	}

	inline static public function font(key:String)
	{
		var folderKey:String = Language.getFileTranslation('fonts/$key');
		#if MODS_ALLOWED
		var file:String = modFolders(folderKey);
		#if switch
		if (FileSystem.exists(toFileSystemPath(file)))
			return file;
		#else
		if (FileSystem.exists(file))
			return file;
		#end
		#end
		return 'assets/$folderKey';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?parentFolder:String = null)
	{
		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			var modKey:String = key;
			if (parentFolder == 'songs')
				modKey = 'songs/$key';

			for (mod in Mods.getGlobalMods())
			{
				var modPath = mods('$mod/$modKey');
				#if switch
				if (FileSystem.exists(toFileSystemPath(modPath)))
					return true;
				#else
				if (FileSystem.exists(modPath))
					return true;
				#end
			}

			var modPath1 = mods(Mods.currentModDirectory + '/' + modKey);
			var modPath2 = mods(modKey);
			#if switch
			if (FileSystem.exists(toFileSystemPath(modPath1)) || FileSystem.exists(toFileSystemPath(modPath2)))
				return true;
			#else
			if (FileSystem.exists(modPath1) || FileSystem.exists(modPath2))
				return true;
			#end
		}
		#end

		var path = getPath(key, type, parentFolder, false);
		#if sys
		return FileSystem.exists(#if switch toFileSystemPath(path) #else path #end);
		#else
		return OpenFlAssets.exists(path, type);
		#end
	}

	static public function getAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var useMod = false;
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);

		var myXml:Dynamic = getPath('images/$key.xml', TEXT, parentFolder, true);
		#if switch
		var fsPath = toFileSystemPath(myXml);
		if (FileSystem.exists(fsPath))
		{
			return FlxAtlasFrames.fromSparrow(imageLoaded, File.getContent(fsPath));
		}
		#elseif MODS_ALLOWED
		if (OpenFlAssets.exists(myXml) || (FileSystem.exists(myXml) && (useMod = true)))
		{
			return FlxAtlasFrames.fromSparrow(imageLoaded, (useMod ? File.getContent(myXml) : myXml));
		}
		#else
		if (OpenFlAssets.exists(myXml))
		{
			return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
		}
		#end
	else
	{
		var myJson:Dynamic = getPath('images/$key.json', TEXT, parentFolder, true);
		#if switch
		var fsPath = toFileSystemPath(myJson);
		if (FileSystem.exists(fsPath))
		{
			return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, File.getContent(fsPath));
		}
		#elseif MODS_ALLOWED
		if (OpenFlAssets.exists(myJson) || (FileSystem.exists(myJson) && (useMod = true)))
		{
			return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (useMod ? File.getContent(myJson) : myJson));
		}
		#else
		if (OpenFlAssets.exists(myJson))
		{
			return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
		}
		#end
	}
		return getPackerAtlas(key, parentFolder);
	}

	static public function getMultiAtlas(keys:Array<String>, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var parentFrames:FlxAtlasFrames = Paths.getAtlas(keys[0].trim());
		if (keys.length > 1)
		{
			var original:FlxAtlasFrames = parentFrames;
			parentFrames = new FlxAtlasFrames(parentFrames.parent);
			parentFrames.addAtlas(original, true);
			for (i in 1...keys.length)
			{
				var extraFrames:FlxAtlasFrames = Paths.getAtlas(keys[i].trim(), parentFolder, allowGPU);
				if (extraFrames != null)
					parentFrames.addAtlas(extraFrames, true);
			}
		}
		return parentFrames;
	}

	static public function getSparrowAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		if (imageLoaded == null)
			return null;

		var xmlPath:String = getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder);

		#if switch
		var fsPath = toFileSystemPath(xmlPath);
		if (FileSystem.exists(fsPath))
			return FlxAtlasFrames.fromSparrow(imageLoaded, File.getContent(fsPath));
		#else
		#if MODS_ALLOWED
		var modsXmlPath:String = modsXml(key);
		if (FileSystem.exists(modsXmlPath))
			return FlxAtlasFrames.fromSparrow(imageLoaded, File.getContent(modsXmlPath));
		#end

		if (OpenFlAssets.exists(xmlPath, TEXT))
			return FlxAtlasFrames.fromSparrow(imageLoaded, OpenFlAssets.getText(xmlPath));
		#end

		return null;
	}
	inline static public function getPackerAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);

		#if switch
		var txt:String = getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder);
		var fsPath = toFileSystemPath(txt);
		if (FileSystem.exists(fsPath))
			return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, File.getContent(fsPath));
		return null;
		#elseif MODS_ALLOWED
		var txtExists:Bool = false;

		var txt:String = modsTxt(key);
		if (FileSystem.exists(txt))
			txtExists = true;

		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded,
			(txtExists ? File.getContent(txt) : getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder));
		#end
	}

	inline static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);

		#if switch
		var json:String = getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder);
		var fsPath = toFileSystemPath(json);
		if (FileSystem.exists(fsPath))
			return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, File.getContent(fsPath));
		return null;
		#elseif MODS_ALLOWED
		var jsonExists:Bool = false;

		var json:String = modsImagesJson(key);
		if (FileSystem.exists(json))
			jsonExists = true;

		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded,
			(jsonExists ? File.getContent(json) : getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder));
		#end
	}

	inline static public function formatToSongPath(path:String)
	{
		final invalidChars = ~/[~&;:<>#\s]/g;
		final hideChars = ~/[.,'"%?!]/g;

		return hideChars.replace(invalidChars.replace(path, '-'), '').trim().toLowerCase();
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];

	public static function returnSound(key:String, ?path:String, ?modsAllowed:Bool = true, ?beepOnNull:Bool = true)
	{
		var file:String = getPath(Language.getFileTranslation(key) + '.$SOUND_EXT', SOUND, path, modsAllowed);

		if (!currentTrackedSounds.exists(file))
		{
			var sound:Sound = null;
			#if sys // Incluye Switch
			var fsPath = #if switch toFileSystemPath(file) #else file #end;
			if (FileSystem.exists(fsPath))
				sound = Sound.fromFile(fsPath);
			#else
			if (OpenFlAssets.exists(file, SOUND))
				sound = OpenFlAssets.getSound(file);
			#end

			if (sound != null)
				currentTrackedSounds.set(file, sound);
			else if (beepOnNull)
			{
				SlDebug.log('SOUND NOT FOUND: $key', ERROR);
				return FlxAssets.getSound('flixel/sounds/beep');
			}
		}
		localTrackedAssets.push(file);
		return currentTrackedSounds.get(file);
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '')
	{
		#if switch
		// Return path with sdmc:/ prefix for mods
		var path = MODS_PATH + '/' + key;
		return normalizeModPath(path);
		#else
		return 'mods/' + key;
		#end
	}

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsVideo(key:String)
		return modFolders('videos/' + key + '.' + VIDEO_EXT);

	inline static public function modsSounds(path:String, key:String)
		return modFolders(path + '/' + key + '.' + SOUND_EXT);

	inline static public function modsImages(key:String)
		return modFolders('images/' + key + '.png');

	inline static public function modsXml(key:String)
		return modFolders('images/' + key + '.xml');

	inline static public function modsTxt(key:String)
		return modFolders('images/' + key + '.txt');

	inline static public function modsImagesJson(key:String)
		return modFolders('images/' + key + '.json');

	static public function modFolders(key:String)
	{
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var fileToCheck:String = mods(Mods.currentModDirectory + '/' + key);
			#if switch
			if (FileSystem.exists(fileToCheck)) // Already has sdmc:/ from mods()
				return fileToCheck;
			#else
			if (FileSystem.exists(fileToCheck))
				return fileToCheck;
			#end
		}

		for (mod in Mods.getGlobalMods())
		{
			var fileToCheck:String = mods(mod + '/' + key);
			#if switch
			if (FileSystem.exists(fileToCheck)) // Already has sdmc:/ from mods()
				return fileToCheck;
			#else
			if (FileSystem.exists(fileToCheck))
				return fileToCheck;
			#end
		}
		#if switch
		return normalizeModPath(MODS_PATH + '/' + key);
		#else
		return 'mods/' + key;
		#end
	}
	#end

	#if flxanimate
	public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null)
	{
		var changedAnimJson = false;
		var changedAtlasJson = false;
		var changedImage = false;

		if (spriteJson != null)
		{
			changedAtlasJson = true;
			#if switch
			spriteJson = toFileSystemPath(spriteJson);
			#end
			spriteJson = File.getContent(spriteJson);
		}

		if (animationJson != null)
		{
			changedAnimJson = true;
			#if switch
			animationJson = toFileSystemPath(animationJson);
			#end
			animationJson = File.getContent(animationJson);
		}

		// is folder or image path
		if (Std.isOfType(folderOrImg, String))
		{
			var originalPath:String = folderOrImg;
			for (i in 0...10)
			{
				var st:String = '$i';
				if (i == 0)
					st = '';

				if (!changedAtlasJson)
				{
					spriteJson = getTextFromFile('images/$originalPath/spritemap$st.json');
					if (spriteJson != null)
					{
						// SlDebug.log('found Sprite Json');
						changedImage = true;
						changedAtlasJson = true;
						folderOrImg = image('$originalPath/spritemap$st');
						break;
					}
				}
				else if (fileExists('images/$originalPath/spritemap$st.png', IMAGE))
				{
					// SlDebug.log('found Sprite PNG');
					changedImage = true;
					folderOrImg = image('$originalPath/spritemap$st');
					break;
				}
			}

			if (!changedImage)
			{
				// SlDebug.log('Changing folderOrImg to FlxGraphic');
				changedImage = true;
				folderOrImg = image(originalPath);
			}

			if (!changedAnimJson)
			{
				// SlDebug.log('found Animation Json');
				changedAnimJson = true;
				animationJson = getTextFromFile('images/$originalPath/Animation.json');
			}
		}

		// SlDebug.log(folderOrImg);
		// SlDebug.log(spriteJson);
		// SlDebug.log(animationJson);
		spr.loadAtlasEx(folderOrImg, spriteJson, animationJson);
	}
	#end
}