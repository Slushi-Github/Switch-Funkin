package slushi.fixes;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.media.Video;
import openfl.net.NetConnection;
import openfl.net.NetStream;
import openfl.events.NetStatusEvent;
import openfl.events.AsyncErrorEvent;
import openfl.geom.Matrix;

/**
 * Wrapper object to maintain compatibility with hxvlc's bitmap API
 */
class VideoBitmapWrapper
{
	private var _rate:Float = 1.0;
	private var owner:OpenFLVideoSprite;

	public var rate(get, set):Float;

	public function new(owner:OpenFLVideoSprite)
	{
		this.owner = owner;
	}

	private function get_rate():Float
	{
		return _rate;
	}

	private function set_rate(value:Float):Float
	{
		_rate = value;
		// Note: OpenFL NetStream doesn't support playback rate natively
		// This is stored but not applied to the video
		#if debug
		if (value != 1.0)
			SlDebug.log('Warning: Video playback rate is not supported on this platform (requested: $value)', WARNING);
		#end
		return _rate;
	}
}

/**
 * Simple video sprite with OpenFL video API, inspired by FlxVideoSprite from HxVLC
 * This is because HxVLC doesn't work on Switch
 */
class OpenFLVideoSprite extends FlxSprite
{
	public var onFormatSetup:Void->Void;
	public var onEndReached:Void->Void;

	/**
	 * Compatibility wrapper to match hxvlc's bitmap API
	 */
	public var bitmap(default, null):VideoBitmapWrapper;

	private var video:Video;
	private var netConnection:NetConnection;
	private var netStream:NetStream;
	private var videoBitmapData:BitmapData;
	private var _isPlaying:Bool = false;
	private var _isPaused:Bool = false;
	private var _shouldLoop:Bool = false;
	private var _videoPath:String;
	private var _videoWidth:Int = 0;
	private var _videoHeight:Int = 0;
	private var _volumeAdjust:Float = 1.0;

	private var resumeOnFocus:Bool = false;

	public var isPlaying(get, never):Bool;

	private function get_isPlaying():Bool
		return _isPlaying && !_isPaused;

	public function new()
	{
		super();

		// Initialize compatibility wrapper
		bitmap = new VideoBitmapWrapper(this);

		netConnection = new NetConnection();
		netConnection.connect(null);

		// Initialize video
		video = new Video();
		video.visible = false;
		FlxG.game.addChild(video);

		// Focus events
		if (!FlxG.signals.focusGained.has(onFocusGained))
			FlxG.signals.focusGained.add(onFocusGained);

		if (!FlxG.signals.focusLost.has(onFocusLost))
			FlxG.signals.focusLost.add(onFocusLost);

		makeGraphic(1, 1, FlxColor.TRANSPARENT);
	}

	public function load(path:String, ?options:Array<String>):Bool
	{
		try
		{
			// In Switch, paths come with romfs:/ or sdmc:/ prefix
			// NetStream.play() doesn't need these prefixes, so we clean them
			#if switch
			var playPath = path;
			if (path.startsWith("romfs:/"))
				playPath = path.substr(7); // Remove "romfs:/"
			else if (path.startsWith("sdmc:/"))
				playPath = path.substr(6); // Remove "sdmc:/"

			_videoPath = playPath;
			#else
			_videoPath = path;
			#end

			// Cleanup previous stream if exists
			if (netStream != null)
			{
				netStream.close();
				netStream.removeEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
				netStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
			}

			// Check if should loop
			_shouldLoop = options != null && options.indexOf('input-repeat=65545') != -1;

			netStream = new NetStream(netConnection);
			netStream.client = {onMetaData: onMetaData, onPlayStatus: onPlayStatus};
			netStream.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			netStream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);

			netStream.play(_videoPath);
			netStream.pause();

			return true;
		}
		catch (e:Dynamic)
		{
			SlDebug.log('Error loading video: $e', ERROR);
			return false;
		}
	}

	public function play():Bool
	{
		if (netStream != null)
		{
			netStream.resume();
			_isPlaying = true;
			_isPaused = false;
			return true;
		}
		return false;
	}

	public function pause():Void
	{
		if (netStream != null && _isPlaying)
		{
			netStream.pause();
			_isPaused = true;
		}
	}

	public function resume():Void
	{
		if (netStream != null && _isPaused)
		{
			netStream.resume();
			_isPaused = false;
		}
	}

	public function stop():Void
	{
		if (netStream != null)
		{
			netStream.close();
			_isPlaying = false;
			_isPaused = false;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Capture video frame
		if (_isPlaying && !_isPaused && videoBitmapData != null && video != null)
		{
			try
			{
				// Clear bitmap
				videoBitmapData.fillRect(videoBitmapData.rect, 0x00000000);

				// Capture the current frame
				var matrix = new Matrix();
				videoBitmapData.draw(video, matrix, null, null, null, antialiasing);

				// Update graphic
				if (graphic != null && graphic.bitmap == videoBitmapData)
				{
					graphic.bitmap = videoBitmapData;
					dirty = true;
				}
			}
			catch (e:Dynamic)
			{
				// Silently handle frame capture errors
				// SlDebug.log('Error capturing video frame: $e', ERROR);
			}
		}
	}

	override public function destroy():Void
	{
		if (FlxG.signals.focusGained.has(onFocusGained))
			FlxG.signals.focusGained.remove(onFocusGained);

		if (FlxG.signals.focusLost.has(onFocusLost))
			FlxG.signals.focusLost.remove(onFocusLost);

		if (netStream != null)
		{
			netStream.close();
			netStream.removeEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			netStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
			netStream = null;
		}

		if (video != null)
		{
			if (FlxG.game.contains(video))
				FlxG.game.removeChild(video);
			video = null;
		}

		// Note: NetConnection.close() is not available on all targets (like Switch)
		// The connection will be cleaned up by garbage collection
		netConnection = null;

		if (videoBitmapData != null)
		{
			videoBitmapData.dispose();
			videoBitmapData = null;
		}

		super.destroy();
	}

	private function onMetaData(data:Dynamic):Void
	{
		video.attachNetStream(netStream);

		_videoWidth = Std.int(data.width);
		_videoHeight = Std.int(data.height);

		video.width = _videoWidth;
		video.height = _videoHeight;

		// Create the BitmapData for the video
		if (videoBitmapData != null)
			videoBitmapData.dispose();

		videoBitmapData = new BitmapData(_videoWidth, _videoHeight, true, 0x00000000);

		// Load the video as a FlxGraphic for the sprite
		loadGraphic(FlxGraphic.fromBitmapData(videoBitmapData, false, null, false));

		if (onFormatSetup != null)
		{
			onFormatSetup();
		}
	}

	private function onPlayStatus(data:Dynamic):Void
	{
		// Alternative callback to detect end of video
		if (data.code == "NetStream.Play.Complete")
		{
			handleVideoEnd();
		}
	}

	private function onNetStatus(event:NetStatusEvent):Void
	{
		SlDebug.log('NetStatus: ${event.info.code}', INFO);

		switch (event.info.code)
		{
			case "NetStream.Play.Stop":
				handleVideoEnd();

			case "NetStream.Play.Start":
				_isPlaying = true;
				_isPaused = false;
		}
	}

	private function handleVideoEnd():Void
	{
		if (_shouldLoop && _videoPath != null)
		{
			// Restart video for looping
			netStream.seek(0);
			netStream.resume();
		}
		else
		{
			_isPlaying = false;
			if (onEndReached != null)
			{
				onEndReached();
			}
		}
	}

	private function onAsyncError(event:AsyncErrorEvent):Void
	{
		SlDebug.log('Video async error: ${event.error}', ERROR);
	}

	public function setVolume(volume:Float):Void
	{
		if (netStream != null)
		{
			var soundTransform = netStream.soundTransform;
			soundTransform.volume = volume * _volumeAdjust;
			netStream.soundTransform = soundTransform;
		}
	}

	public function setVolumeAdjust(value:Float):Void
	{
		_volumeAdjust = value;
		#if FLX_SOUND_SYSTEM
		setVolume((FlxG.sound.muted ? 0 : 1) * FlxG.sound.volume);
		#else
		setVolume(1);
		#end
	}

	private function onFocusGained():Void
	{
		#if !mobile
		if (!FlxG.autoPause)
			return;
		#end

		if (resumeOnFocus)
		{
			resumeOnFocus = false;
			resume();
		}
	}

	private function onFocusLost():Void
	{
		#if !mobile
		if (!FlxG.autoPause)
			return;
		#end

		resumeOnFocus = isPlaying;
		pause();
	}
}