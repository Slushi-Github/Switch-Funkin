package options.nx;

class NXOtherSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('switch_menu_other', 'Nintendo Switch Other Settings');
		rpcTitle = 'Nintendo Switch other Settings Menu';

		var option = new Option('Enable vibration', 'Enable the vibration for the Nintendo Switch Joy-Con and other controllers.\n(EXPERIMENTAL)', 'vibrating', BOOL);
		addOption(option);

		super();
	}
}