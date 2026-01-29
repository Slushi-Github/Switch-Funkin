package slushi;

import haxe.PosInfos;

/**
 * The log level
 */
enum LogLevel
{
	INFO;
	WARNING;
	ERROR;
	DEBUG;
}

/**
 * Simple logger, inspired by Vupx Engine
 * 
 * Author: Slushi
 */
class SlDebug {
	/**
	 * The start time of the logger
	 */
	private static var startTime:Float = Sys.time();

	/**
	 * The elapsed time from the start of the engine
	 */
	public static var elapsedTime:Float = 0.0;

	/**
	 * Log a message to the log file
	 * @param message The message to log
	 * @param level The log level
	 */
	public static function log(message:Null<Dynamic>, level:Null<LogLevel> = LogLevel.INFO, ?pos:PosInfos):Void
	{
        #if !debug
		if (level == LogLevel.DEBUG)
		{
			return;
		}
        #end

        updateLogTime();

		var formattedMessage:String = prepareText(Std.string(message), level ??= LogLevel.INFO, pos);
		Sys.println(formattedMessage);
	}

	/**
	 * Update the elapsed time
	 */
	@:noCompletion
	private static function updateLogTime():Void
	{
		var currentTime:Float = Sys.time();
		var tempTime:Float = currentTime - startTime;
		elapsedTime = Math.fround(tempTime * 10) / 10;
	}

	/**
	 * Get the current time as a string: HH:MM:SS
	 * @return String
	 */
	@:noCompletion
	private static function getCurrentTimeString():String
	{
		var now = Date.now();

		var hours = now.getHours();
		var minutes = now.getMinutes();
		var seconds = now.getSeconds();

		var hoursStr = padZero(hours, 2);
		var minutesStr = padZero(minutes, 2);
		var secondsStr = padZero(seconds, 2);

		return '${hoursStr}:${minutesStr}:${secondsStr}';
	}

	/**
	 * Pad a number with zeros
	 * @param value 
	 * @param length 
	 * @return String
	 */
	private static function padZero(value:Int, length:Int):String
	{
		var str = Std.string(value);
		while (str.length < length)
		{
			str = "0" + str;
		}
		return str;
	}

	/**
	 * Get the Haxe file position from PosInfos
	 * @param pos 
	 * @return String
	 */
	private static function getHaxeFilePos(pos:PosInfos):String
	{
		if (pos == null)
		{
			return "UnknownPosition";
		}

		return pos.className + "/" + pos.methodName + ":" + pos.lineNumber;
	}

	/**
	 * Prepare the text to be logged
	 * @param text 
	 * @param logLevel 
	 * @param pos 
	 * @param fornxlink
	 * @return String
	 */
	private static function prepareText(text:String, logLevel:LogLevel, ?pos:PosInfos):String
	{
        var finalLogLevel:String = "";
        switch (logLevel)
        {
            case INFO:
                finalLogLevel = "\x1b[38;5;7m" + Std.string(logLevel) + "\x1b[0m";
            case WARNING:
                finalLogLevel = "\x1b[38;5;3m" + Std.string(logLevel) + "\x1b[0m";
            case ERROR:
                finalLogLevel = "\x1b[38;5;1m" + Std.string(logLevel) + "\x1b[0m";
            case DEBUG:
                finalLogLevel = "\x1b[38;5;5m" + Std.string(logLevel) + "\x1b[0m";
        }

			final returnText = "["
				+ getCurrentTimeString()
				+ " ("
				+ elapsedTime
				+ ") | "
				+ finalLogLevel
				+ " - "
				+ getHaxeFilePos(pos)
				+ "] "
				+ text;

		return returnText;
	}
}