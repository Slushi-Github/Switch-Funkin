<h1 align="center">
  <img src="art/switchAssets/GitHubSwitchFunkinLogo.png" alt="Switch Funkin' GitHub Logo">
</h1>

<h3 align="center">Real FNF' for Nintendo Switch, just, why not?</h3>

So yeah… this is [Psych Engine 1.0.4](https://github.com/ShadowMario/FNF-PsychEngine) for Nintendo Switch. It’s not a recreation or an inspiration, this is the real [HaxeFlixel](https://haxeflixel.com) running on Switch! So yes, we have Friday Night Funkin' on Nintendo Switch!

This is possible thanks to [Lime-NX](https://github.com/Slushi-Github/lime-nx), which allows compiling Lime projects for the console using DevKitPro and DevKitA64, meaning <ins>**homebrew stuff**</ins>, so you need a modified Nintendo Switch running Atmosphère to play this game!

That’s it, there’s not much more to say. Enjoy the real Friday Night Funkin' experience on Nintendo Switch now!

Everything in Psych Engine are working on the Switch target, videos (Thanks now to [HxSwitchVideo](https://github.com/Slushi-Github/HxSwitchVideo) but its still a work in progress) HScript and Lua, shaders, and even mod folder support are functional on this platform.

If you think you can play with a keyboard or mouse... Well yes! You can play with a keyboard and mouse! Just connect a keyboard and mouse on the dock of the console and you will be able to play with them.

## Considerations

The engine **CANNOT** cache *ALL* assets, so loading screens can be slow, and even loading the game over screen a second time can be slow. This seems to be a limitation of how the game is compiled for this platform. It might have a solution by not depending on OpenFL for that, but it’s not something I want to modify at the moment, Loading times will also depend on your microSD card.

Also keep something in mind: The Nintendo Switch is hardware from around 2016, and Psych Engine is apparently not the best FNF engine for this console. This may require optimizing the engine or the mod, but in the end we are dealing with a mid-2016 device with 4 GB of RAM, so you can’t expect miracles on this platform, okay? From what I saw, [V-Slice](https://github.com/FunkinCrew/Funkin) should perform better than Psych, but it has a complexity that make it impossible for me mantain it for Nintendo Switch, [there is a attempt to do it, but it is not finished](https://github.com/FunkinNXTeam/Funkin). This is the reason I chose Psych Engine, besides it being the FNF engine I know the most and that I like.

Even though it may sound obvious, mods that use special mechanics requiring extra keys will need modifications to support controllers.

Don't expect this engine to compile to other platforms. Although I have tried to maintain compilation with at least Linux, this engine is modified to work well with the Nintendo Switch.

## Installation

Download the latest version:
- From [GitHub](https://github.com/Slushi-Github/Switch-Funkin/releases/latest).
- From [GitHub Actions](https://github.com/Slushi-Github/Switch-Funkin/actions).
- From Gamebanana:
	> [![](https://gamebanana.com/tools/embeddables/21807?type=large)](https://gamebanana.com/tools/21807)
- From [Homebrew App Store For Nintendo Switch](https://hb-app.store/switch/FNFSwitchFunkin)

The Homebrew App Store option allows you to download the game directly to your console! It's the easiest way to get the game and future updates. To do this, search for the game in the HBAS client on your Switch and download it.

But if you prefer the other options...

Inside the downloaded ZIP, you will find a file that ends with `.nro`. Drag it into the `switch` folder on your console’s SD card. 

Simply open the Homebrew Menu from an official game (usually by holding the **R** button while launching a game from the HOME menu), look for **"FNF: Switch Funkin'"**, open it, and enjoy!

For now, I do not offer an NSP file to install it directly on the console and skip the Homebrew Menu step.

## Mods and others

Installing mods in Switch Funkin' is easy. Once you open the game at least once, on your SD card, inside the `switch` folder, you will see a new folder called `Switch-Funkin`. Inside it, you will find the `mods` folder, which works exactly like normal Psych Engine. You will also find folders with crash logs or shader error logs, as well as the `saves` folder, which stores the game’s save data, the same standard [HaxeFlixel save files](https://haxeflixel.com/documentation/flxsave/).

## Compiling the engine

First, follow the [Psych Engine](https://github.com/ShadowMario/FNF-PsychEngine) setup **but using the setup files of [this repository](./setup/)**.

Then you need to follow the steps to compile with [Lime-NX](https://github.com/Slushi-Github/lime-nx/tree/lime-9778682#how-to-use) for Nintendo Switch.

You also need the following library:

```bash
haxelib git hx_libnx https://github.com/Slushi-Github/hx_libnx
```

And the DevKitPro Lua 5.1 library if you want to use Lua in this engine (otherwise, remove
or comment the define `LUA_ALLOWED` from the `Project.xml` file):

(If you are on Linux/macOS, you will most likely need to use `sudo dkp-pacman` instead of `pacman`)

```bash
pacman -S switch-liblua51
```

And follow the steps [to use HxSwitchVideo](https://github.com/Slushi-Github/HxSwitchVideo/#installation) for video playback if you want to use it in this engine (otherwise, remove or comment the define `VIDEOS_ALLOWED` from the `Project.xml` file on the section `SWITCH FUNKIN' CUSTOMIZATION`).

Change the `<config:switch ip="192.168.1.140"/>` in the `Project.xml` file to the IP of your Switch.

And that’s it! If you did everything correctly, you should be able to compile the engine with `lime test switch` or `lime build switch` and you’re done!

## Contributing

If you want to contribute to this project, you can do it by creating a pull request on this repository, test that your changes work __**on the real hardware**__, I would recommend attaching images if it is a change that can be shown.

## Credits

* [Psych Engine](https://github.com/ShadowMario/FNF-PsychEngine): The base for Switch Funkin'.

* [P-Slice](https://github.com/Psych-Slice/P-Slice): Where I took the code used to implement the hitbox for playing with the Nintendo Switch touchscreen.

* Roxy (On Discord): It helped me discover performance issues in the Weekend songs (it turned out that the **original** rain shader and Nene's speaker visualizer were too much for the Switch's CPU and GPU).

* [@doggywatty](https://github.com/doggywatty): For initially creating the entire integration between [MPV](https://github.com/mpv-player/mpv) and [HaxeFlixel](https://haxeflixel.com) to enable video playback on [Switch Funkin'](https://github.com/Slushi-Github/Switch-Funkin) as described in PR [#21](https://github.com/Slushi-Github/Switch-Funkin/pull/21), which led to the creation of [HxSwitchVideo](https://github.com/Slushi-Github/HxSwitchVideo), literally did everything I didn't dare to do, heh, also for optimizing the ABot Speaker and the rain shader used in Weekend 1 so that it would work well on the Switch as described in PR [#22](https://github.com/Slushi-Github/Switch-Funkin/pull/22), And finally, for fixing the issue where the audio would crash in Lime-NX!

## Other information

This engine uses code from [Vupx Engine (My framework engine for the Nintendo Switch)](https://slushi-github.github.io/Vupx-Engine) and also from [Slushi Engine](https://github.com/Slushi-Github/Slushi-Engine) (only the Slushi Freeplay).

... [This](https://www.youtube.com/watch?v=8RBJdMUOzrE) is no longer a meme XDD.

FNF' V-Slice for the console [here](https://github.com/FunkinNXTeam/Funkin) (Is incomplete, old and broken...).

Old FNF' vanilla for the console [here](https://github.com/FunkinNXTeam/FunkinLegacy).

## Screenshots

![Title State screenshot](./art/switchAssets/Screenshots/TitleStateScreenshot.png)

![Freeplay State screenshot](./art/switchAssets/Screenshots/FreeplayStateScreenshot.png)
