#if !macro
//Discord API
#if DISCORD_ALLOWED
import backend.Discord;
#end

#if TOUCH_CONTROLS_ALLOWED
import mobile.objects.Hitbox;
import mobile.objects.Hitbox.ExtraActions;
import mobile.objects.TouchButton;
import mobile.input.MobileInputID;
import mobile.input.MobileInputManager;
#end

import cpp.*;
import lime.app.Application;

#if switch
import switchLib.Result;
import switchLib.Types.ResultType;
import switchLib.runtime.Pad;
import switchLib.services.Hid;
import switchLib.arm.Counter;
import switchLib.services.Applet;

import slushi.nx.SwitchUtils;
import slushi.nx.controls.NXController;
import slushi.nx.controls.NXControlButton;
import slushi.nx.controls.NXVibrationHD;
#end

import slushi.states.freeplay.SlushiFreeplayState;
import slushi.states.SwitchTitleState;
import slushi.fixes.OpenFLVideoSprite;
import slushi.SlushiMain;
import slushi.SlDebug;
import slushi.SlGame;

//Psych
#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end

#if sys
import sys.*;
import sys.io.*;
#elseif js
import js.html.*;
#end

import backend.Paths;
import backend.Controls;
import backend.CoolUtil;
import backend.MusicBeatState;
import backend.MusicBeatSubstate;
import backend.CustomFadeTransition;
import backend.ClientPrefs;
import backend.Conductor;
import backend.BaseStage;
import backend.Difficulty;
import backend.Mods;
import backend.Language;

import backend.ui.*; //Psych-UI

import objects.Alphabet;
import objects.BGSprite;

import states.PlayState;
import states.LoadingState;

#if flxanimate
import flxanimate.*;
import flxanimate.PsychFlxAnimate as FlxAnimate;
#end

//Flixel
import flixel.sound.FlxSound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;

using StringTools;
#end
