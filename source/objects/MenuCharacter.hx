package objects;

#if !switch
import openfl.utils.Assets;
#end
import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef MenuCharacterFile =
{
	var image:String;
	var scale:Float;
	var position:Array<Int>;
	var idle_anim:String;
	var confirm_anim:String;
	var flipX:Bool;
	var antialiasing:Null<Bool>;
}

class MenuCharacter extends FlxSprite
{
	public var character:String;
	public var hasConfirmAnimation:Bool = false;

	private static var DEFAULT_CHARACTER:String = 'bf';

	public function new(x:Float, character:String = 'bf')
	{
		super(x);

		changeCharacter(character);
	}

	public function changeCharacter(?character:String = 'bf')
	{
		if (character == null)
			character = '';
		if (character == this.character)
			return;

		this.character = character;
		visible = true;

		var dontPlayAnim:Bool = false;
		scale.set(1, 1);
		updateHitbox();

		color = FlxColor.WHITE;
		alpha = 1;

		hasConfirmAnimation = false;
		switch (character)
		{
			case '':
				visible = false;
				dontPlayAnim = true;
			default:
				var characterPath:String = 'images/menucharacters/' + character + '.json';
				var path:String = Paths.getPath(characterPath, TEXT);

				var fileExists:Bool = false;
				#if switch
				var fsPath = Paths.toFileSystemPath(path);
				fileExists = FileSystem.exists(fsPath);
				#elseif MODS_ALLOWED
				fileExists = FileSystem.exists(path);
				#else
				fileExists = Assets.exists(path);
				#end

				if (!fileExists)
				{
					path = Paths.getSharedPath('images/menucharacters/' + DEFAULT_CHARACTER + '.json');
					#if switch
					fsPath = Paths.toFileSystemPath(path);
					#end
					color = FlxColor.BLACK;
					alpha = 0.6;
				}

				var charFile:MenuCharacterFile = null;
				try
				{
					#if switch
					if (FileSystem.exists(fsPath))
						charFile = Json.parse(File.getContent(fsPath));
					else
					{
						SlDebug.log('Menu character JSON not found: $fsPath', ERROR);
						makeGraphic(1, 1, 0x00000000);
						return;
					}
					#elseif MODS_ALLOWED
					charFile = Json.parse(File.getContent(path));
					#else
					charFile = Json.parse(Assets.getText(path));
					#end
				}
				catch (e:Dynamic)
				{
					SlDebug.log('Error loading menu character file of "$character": $e', ERROR);
					makeGraphic(1, 1, 0x00000000);
					return;
				}

				frames = Paths.getSparrowAtlas('menucharacters/' + charFile.image);
				if (frames == null)
				{
					SlDebug.log('Error loading menu character atlas: menucharacters/' + charFile.image, ERROR);
					makeGraphic(1, 1, 0x00000000);
					return;
				}

				animation.addByPrefix('idle', charFile.idle_anim, 24);

				var confirmAnim:String = charFile.confirm_anim;
				if (confirmAnim != null && confirmAnim.length > 0 && confirmAnim != charFile.idle_anim)
				{
					animation.addByPrefix('confirm', confirmAnim, 24, false);
					if (animation.getByName('confirm') != null) // check for invalid animation
						hasConfirmAnimation = true;
				}
				flipX = (charFile.flipX == true);

				if (charFile.scale != 1)
				{
					scale.set(charFile.scale, charFile.scale);
					updateHitbox();
				}
				offset.set(charFile.position[0], charFile.position[1]);
				animation.play('idle');

				antialiasing = (charFile.antialiasing != false && ClientPrefs.data.antialiasing);
		}
	}
}