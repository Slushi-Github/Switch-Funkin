package slushi.nx.controls;

import haxe.ds.Vector;

typedef NXJoyConColor = {
    colorMain:FlxColor,
    colorSub:FlxColor,
}

/**
 * Joycon type
 */
enum NXJoyCon {
    LEFT;
    RIGHT;
}

/**
 * A class for handling controller input and sensors
 * 
 * Ported from Vupx Engine
 * 
 * Author: Slushi
 */
class NXController {

	public static var instance:NXController;

    /**
     * Vibration manager of the controller
     */
    public var vibration:NXVibrationHD;

    ///////////////////////////

	#if switch
    /**
     * Current controller state
     */
    @:unreflective
    private var pad:PadState;
    #end

    /**
     * Currently pressed keys
     */
    private var keyDown:Int;

    /**
     * Just pressed keys
     */
    private var keyPressed:Int;

    /**
     * Just released keys
     */
    private var keyUp:Int;

    ///////////////////////////
	#if switch
    /**
     * SLeft stick controller state
     */
    @:unreflective
    private var stickL:HidAnalogStickState;

    /**
     * SRight stick controller state
     */
    @:unreflective
    private var stickR:HidAnalogStickState;
    #end

    ///////////////////////////

    ////////////////////////////

    /**
     * Controller current style
     */
    private var currentStyle:UInt64;

    ////////////////////////////

    /**
     * Controller type
     */
    private var joyConColors:Vector<NXJoyConColor>;

	#if switch
    /**
     * Left Joycon color
     */
    private var joyconLeftColor:HidNpadControllerColor;

    /**
     * Right Joycon color
     */
    private var joyconRightColor:HidNpadControllerColor;
    #end

    ////////////////////////////

    /**
     * Create a new VpControl, to handle input from the controller
     */
    public function new() {
		#if switch
        instance = this;

        SlDebug.log("Initializing controller manager...", INFO);

        // Initialize the controller
        Pad.padConfigureInput(1, HidNpadStyleTag.HidNpadStyleSet_NpadStandard);
        pad = new PadState();
        Pad.padInitializeDefault(Pointer.addressOf(pad));

        ////////////////////////

        // Initialize the controller sticks
        stickL = new HidAnalogStickState();
        stickR = new HidAnalogStickState();

        /////////////////////////

        vibration = new NXVibrationHD();

        joyConColors = new Vector<NXJoyConColor>(2);

        // Initialize the controller colors with white by default
        joyConColors[0] = {
			colorMain: FlxColor.WHITE,
			colorSub: FlxColor.WHITE
        };
        joyConColors[1] = {
            colorMain: FlxColor.WHITE,
			colorSub: FlxColor.WHITE
        };

        joyconLeftColor = new HidNpadControllerColor();
        joyconRightColor = new HidNpadControllerColor();

        var rc:ResultType = Hid.hidGetNpadControllerColorSplit(Pad.padIsHandheld(Pointer.addressOf(pad)) ? HidNpadIdType.HidNpadIdType_Handheld : HidNpadIdType.HidNpadIdType_No1, Pointer.addressOf(joyconLeftColor), Pointer.addressOf(joyconRightColor));
        if (Result.R_SUCCEEDED(rc)) {
            joyConColors[0] = {
                colorMain: new FlxColor(joyconLeftColor.main),
                colorSub: new FlxColor(joyconLeftColor.sub)
            };
            joyConColors[1] = {
                colorMain: new FlxColor(joyconRightColor.main),
                colorSub: new FlxColor(joyconRightColor.sub)
            };
        }

        /////////////////////////

        /////////////////////////

        SlDebug.log("Controller manager initialized", INFO);
        #end
    }

    /**
     * Update the controller state
     */
    public function update():Void {
        #if switch
        Pad.padUpdate(Pointer.addressOf(pad));
        if (vibration != null) {
			vibration.updateMode(Pad.padIsHandheld(Pointer.addressOf(pad)));
            vibration.update(FlxG.elapsed);
        }

        keyDown = Pad.padGetButtonsDown(Pointer.addressOf(pad)).toInt();
        keyPressed = Pad.padGetButtons(Pointer.addressOf(pad)).toInt();
        keyUp = Pad.padGetButtonsUp(Pointer.addressOf(pad)).toInt();

        stickL = Pad.padGetStickPos(Pointer.addressOf(pad), 0);
        stickR = Pad.padGetStickPos(Pointer.addressOf(pad), 1);

        // Update the controller colors
        if (joyConColors != null) {
            var rc:ResultType = Hid.hidGetNpadControllerColorSplit(Pad.padIsHandheld(Pointer.addressOf(pad)) ? HidNpadIdType.HidNpadIdType_Handheld : HidNpadIdType.HidNpadIdType_No1, Pointer.addressOf(joyconLeftColor), Pointer.addressOf(joyconRightColor));
            if (Result.R_SUCCEEDED(rc)) {
                joyConColors[0] = {
					colorMain: FlxColor.fromRGB(
                        (joyconLeftColor.main >> 0) & 0xFF,   // R
                        (joyconLeftColor.main >> 8) & 0xFF,   // G
                        (joyconLeftColor.main >> 16) & 0xFF,  // B
                        (joyconLeftColor.main >> 24) & 0xFF   // A
                    ),
					colorSub: FlxColor.fromRGB(
                        (joyconLeftColor.sub >> 0) & 0xFF,
                        (joyconLeftColor.sub >> 8) & 0xFF,
                        (joyconLeftColor.sub >> 16) & 0xFF,
                        (joyconLeftColor.sub >> 24) & 0xFF
                    )
                };
                joyConColors[1] = {
					colorMain: FlxColor.fromRGB(
                        (joyconRightColor.main >> 0) & 0xFF,
                        (joyconRightColor.main >> 8) & 0xFF,
                        (joyconRightColor.main >> 16) & 0xFF,
                        (joyconRightColor.main >> 24) & 0xFF
                    ),
					colorSub: FlxColor.fromRGB(
                        (joyconRightColor.sub >> 0) & 0xFF,
                        (joyconRightColor.sub >> 8) & 0xFF,
                        (joyconRightColor.sub >> 16) & 0xFF,
                        (joyconRightColor.sub >> 24) & 0xFF
                    )
                };
            }
            // If the function failed, use the default colors
            else if (Result.R_FAILED(rc)) {
                joyConColors[0] = {
					colorMain: FlxColor.WHITE,
					colorSub: FlxColor.WHITE,
                };
                joyConColors[1] = {
					colorMain: FlxColor.WHITE,
					colorSub: FlxColor.WHITE
                };
            }
        }
        #end
    }

    ///////////////////////////

    /**
     * Check if a key is pressed
     * @param key 
     * @return Bool
     */
    public function isPressed(key:NXControlButton):Bool {
        #if switch
        return keyPressed & getHidButton(key) != 0;
        #else
        return false;
        #end
    }

    /**
     * Check if a key is just pressed
     * @param key 
     * @return Bool
     */
	public function isJustPressed(key:NXControlButton):Bool {
		#if switch
        return (keyDown & getHidButton(key)) != 0;
        #else
        return false;
        #end
    }

    /**
     * Check if a key is released
     * @param key 
     * @return Bool
     */
	public function isReleased(key:NXControlButton):Bool {
		#if switch
        return (keyPressed & getHidButton(key)) == 0;
        #else
        return false;
        #end
    }   

    /**
     * Check if a key is just released
     * @param key 
     * @return Bool
     */
	public function isJustReleased(key:NXControlButton):Bool {
		#if switch
        return (keyUp & getHidButton(key)) != 0;
        #else
        return false;
        #end
    }

    ///////////////////////////

    /**
     * Get the left stick position of the controller
     */
    public function getStickL():{x:Float, y:Float} {
        #if switch
        return {
            x: stickL.x / Hid.JOYSTICK_MAX,
            y: stickL.y / Hid.JOYSTICK_MAX
        };
        #else
        return {
            x: 0,
            y: 0
        };
        #end
    }

    /**
     * Get the right stick position of the controller
     */
    public function getStickR():{x:Float, y:Float} {
        #if switch
        return {
            x: stickR.x / Hid.JOYSTICK_MAX,
            y: stickR.y / Hid.JOYSTICK_MAX
        };
        #else
        return {
            x: 0,
            y: 0
        };
        #end
    }

    ///////////////////////////

    /**
     * Get the main color and sub color of a Joy-Con
     * 
     * -------
     * 
     * Primary color: The color of the Joy-Con outer shell
     * 
     * Secondary color: The color of the Joy-Con buttons
     * 
     * -------
     * 
     * Sometimes it may return inverted colors, or return black, 
     * or other strange things. If non-original Joy-Cons are 
     * being used, the colors returned from this function are unknown.
     * 
     * @param index Joy-Con
     * @return VpJoyConColor
    */
    public function getJoyConColor(index:NXJoyCon):NXJoyConColor {
		#if switch
        return switch (index) {
            case NXJoyCon.LEFT:
                return joyConColors[0];
            case NXJoyCon.RIGHT:
                return joyConColors[1];
        }
        #else
        return {
            colorMain: FlxColor.WHITE,
            colorSub: FlxColor.WHITE
        };
        #end
    }

    ///////////////////////////
    
    ///////////////////////////

    public function destroy():Void {
        #if switch
        if (vibration != null) {
            vibration.destroy();
        }
        #end
    }

    /**
     * Get the HID button code
     * @param button 
     * @return Int
     */
	private static function getHidButton(button:NXControlButton):Int {
        #if switch
        return switch(button) {
            case A: HidNpadButton.HidNpadButton_A;
            case B: HidNpadButton.HidNpadButton_B;
            case X: HidNpadButton.HidNpadButton_X;
            case Y: HidNpadButton.HidNpadButton_Y;
            case STICK_L: HidNpadButton.HidNpadButton_StickL;
            case STICK_R: HidNpadButton.HidNpadButton_StickR;
            case L: HidNpadButton.HidNpadButton_L;
            case R: HidNpadButton.HidNpadButton_R;
            case ZL: HidNpadButton.HidNpadButton_ZL;
            case ZR: HidNpadButton.HidNpadButton_ZR;
            case PLUS: HidNpadButton.HidNpadButton_Plus;
            case MINUS: HidNpadButton.HidNpadButton_Minus;
            case LEFT: HidNpadButton.HidNpadButton_Left;
            case UP: HidNpadButton.HidNpadButton_Up;
            case RIGHT: HidNpadButton.HidNpadButton_Right;
            case DOWN: HidNpadButton.HidNpadButton_Down;
            case STICK_L_LEFT: HidNpadButton.HidNpadButton_StickLLeft;
            case STICK_L_UP: HidNpadButton.HidNpadButton_StickLUp;
            case STICK_L_RIGHT: HidNpadButton.HidNpadButton_StickLRight;
            case STICK_L_DOWN: HidNpadButton.HidNpadButton_StickLDown;
            case STICK_R_LEFT: HidNpadButton.HidNpadButton_StickRLeft;
            case STICK_R_UP: HidNpadButton.HidNpadButton_StickRUp;
            case STICK_R_RIGHT: HidNpadButton.HidNpadButton_StickRRight;
            case STICK_R_DOWN: HidNpadButton.HidNpadButton_StickRDown;
            case LEFT_SL: HidNpadButton.HidNpadButton_LeftSL;
            case LEFT_SR: HidNpadButton.HidNpadButton_LeftSR;
            case RIGHT_SL: HidNpadButton.HidNpadButton_RightSL;
            case RIGHT_SR: HidNpadButton.HidNpadButton_RightSR;
            case PALMA: HidNpadButton.HidNpadButton_Palma;
            case VERIFICATION: HidNpadButton.HidNpadButton_Verification;
            case HANDHELD_LEFT_B: HidNpadButton.HidNpadButton_HandheldLeftB;
            case LAGON_C_LEFT: HidNpadButton.HidNpadButton_LagonCLeft;
            case LAGON_C_UP: HidNpadButton.HidNpadButton_LagonCUp;
            case LAGON_C_RIGHT: HidNpadButton.HidNpadButton_LagonCRight;
            case LAGON_C_DOWN: HidNpadButton.HidNpadButton_LagonCDown;
            case ANY_LEFT: HidNpadButton.HidNpadButton_AnyLeft;
            case ANY_UP: HidNpadButton.HidNpadButton_AnyUp;
            case ANY_RIGHT: HidNpadButton.HidNpadButton_AnyRight;
            case ANY_DOWN: HidNpadButton.HidNpadButton_AnyDown;
            case ANY_SL: HidNpadButton.HidNpadButton_AnySL;
            case ANY_SR: HidNpadButton.HidNpadButton_AnySR;
            default: HidNpadButton.HidNpadButton_A;
        }
        #else
        return 0;
        #end
    }
}