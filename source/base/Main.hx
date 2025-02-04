package base;

import webm.WebmPlayer;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
#if windows
import Discord.DiscordClient;
#end

class Main extends Sprite
{
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = menus.TitleState; // The FlxState the game starts with.
	var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var framerate:Int = 120; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets

	public static var watermarks = true; // Whether to put Kade Engine liteartly anywhere

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{

		// quick checks 

		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	public static var webmHandler:WebmHandler;

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		scripts.HaxeScript.initParser(); // Init the parser for hscript before creating the game because TitleState.
		scripts.LuaScript.filePrefixes.push(["-- ADD PSYCH PREFIX --", openfl.Assets.getText("assets/data/PSYCH_HANDLER.lua")]);

		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (zoom == -1)
		{
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}

		game = new base.CustomFlxGame(gameWidth, gameHeight, initialState, framerate, framerate, skipSplash, startFullscreen);

		addChild(game);

		initStuff();

		#if !mobile
		fpsCounter = new FPS(10, 3, 0xFFFFFF);
		addChild(fpsCounter);
		toggleFPS(FlxG.save.data.fps);
		setFPSCap(FlxG.save.data.fpsCap);
		#end
	}

	function initStuff() {
		flixel.graphics.FlxGraphic.defaultPersist = true;
		flixel.FlxG.fixedTimestep = false;

		#if sys
		if (!sys.FileSystem.exists(Sys.getCwd() + "/assets/replays"))
			sys.FileSystem.createDirectory(Sys.getCwd() + "/assets/replays");
		#end

		#if windows
		DiscordClient.initialize();
		lime.app.Application.current.onExit.add (function (exitCode) {
			DiscordClient.shutdown();
		 });
		#end

		settings.PlayerSettings.init();
		FlxG.save.bind('funkin', 'ninjamuffin99');
		settings.KadeEngineData.initSave();
		utils.Highscore.load();

		var diamond:flixel.graphics.FlxGraphic = flixel.graphics.FlxGraphic.fromClass(flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond);
		diamond.persist = true;
		diamond.destroyOnNoUse = false;

		flixel.addons.transition.FlxTransitionableState.defaultTransIn = new flixel.addons.transition.TransitionData(
			FADE,
			0xFF000000,
			1,
			new flixel.math.FlxPoint(0, -1),
			{asset: diamond, width: 32, height: 32},
			new flixel.math.FlxRect(-200, -200, FlxG.width * 1.4, FlxG.height * 1.4)
		);
		flixel.addons.transition.FlxTransitionableState.defaultTransOut = new flixel.addons.transition.TransitionData(
			FADE,
			0xFF000000,
			0.7,
			new flixel.math.FlxPoint(0, 1),
			{asset: diamond, width: 32, height: 32},
			new flixel.math.FlxRect(-200, -200, FlxG.width * 1.4, FlxG.height * 1.4)
		);
	}

	var game:FlxGame;

	var fpsCounter:FPS;

	public function toggleFPS(fpsEnabled:Bool):Void {
		fpsCounter.visible = fpsEnabled;
	}

	public function changeFPSColor(color:FlxColor)
	{
		fpsCounter.textColor = color;
	}

	public function setFPSCap(cap:Float)
	{
		openfl.Lib.current.stage.frameRate = cap;

		var intCap = Std.int(cap);
		if (intCap > FlxG.drawFramerate) {
			FlxG.updateFramerate = intCap;
			FlxG.drawFramerate = intCap;
		} else {
			FlxG.drawFramerate = intCap;
			FlxG.updateFramerate = intCap;
		}
	}

	public function getFPSCap():Float
	{
		return openfl.Lib.current.stage.frameRate;
	}

	public function getFPS():Float
	{
		return fpsCounter.currentFPS;
	}
}
