package options.nx;

class HitboxSettingsSubState extends BaseOptionsMenu
{
	final exControlTypes:Array<String> = ["NONE", "SINGLE", "DOUBLE", "ARROWS"];
	final hintOptions:Array<String> = ["No Gradient", "No Gradient (Old)", "Gradient", "Bars only", "Hidden"];

	public function new()
	{
		title = Language.getPhrase('hitbox_menu', 'Hitbox Settings');
		rpcTitle = 'Hitbox Settings Menu';

		var option = new Option('Enable HitBox', 'Enable the hitbox for use the touchscreen for playing instead of the console controls.\n(EXPERIMENTAL)', 'enableHitbox', BOOL);
		addOption(option);

		var option = new Option('Hitbox Layout', 'Select the layout for the hitboxes.\nSome contain extra programmable lanes.', 'extraHints', STRING,
			exControlTypes);
		addOption(option);

		var option = new Option('Hitbox Design', 'Choose how your hitbox should look like.', 'hitboxType', STRING, hintOptions);
		addOption(option);

		var option = new Option('Hitbox Position', 'If checked, the hitbox will be put at the bottom of the screen, otherwise will stay at the top.', 'hitbox2',
			BOOL);
		addOption(option);

		var option = new Option('Dynamic Controls Color',
			'If checked, the mobile controls color will be set to the notes color in your settings.\n(have effect during gameplay only)', 'dynamicColors',
			BOOL);
		addOption(option);

		super();
	}
}