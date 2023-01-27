package funkin;

import openfl.Assets;
import haxe.Json;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;

using StringTools;

//Char Jsons are handled similarly to how Kade 1.8 handles Char Jsons.
typedef CharJson = {
	var asset:String;
	var iconAsset:String;
	var barColor:String;
	var commonSide:String;
	var offsets:CharOffsets;
	var animations:Array<JsonAnim>;

	var ?scale:Float;
	var ?scaleAffectsOffset:Bool;
	var ?flipX:Bool;
	var ?antialiasing:Bool;
	var ?singLength:Float;
}

typedef JsonAnim = {
	var name:String;
	var prefix:String;
	var offsets:Array<Float>;

	var ?looped:Bool;
	var ?flipX:Bool;
	var ?flipY:Bool;
	var ?frameRate:Int;
	var ?frameIndices:Array<Int>;
}

typedef CharOffsets = {
	var x:Float;
	var y:Float;
	var camX:Float;
	var camY:Float;
}

class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Float>>;
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var data:CharJson = {
		asset: "characters/BOYFRIEND",
		iconAsset: "bf",
		barColor: "#31D1B0",
		commonSide: "bf",
		offsets: {x: 0, y: 350, camX: 0, camY: 0},
		animations: [{name: "idle", prefix: "bf idle dance", offsets: [-5, 0]}],
		flipX: true
	};
	public var curCharacter:String = 'bf';
	var leftRightDancer:Bool = false;

	public var stunned:Bool = false;
	public var holdTimer:Float = 0;
	public var hpcolor:FlxColor;

	public var regX:Float = 770;
	public var regY:Float = 100;

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false)
	{
		super(x, y);
		regX = x;
		regY = y;
		animOffsets = new Map<String, Array<Float>>();
		this.isPlayer = isPlayer;
		loadCharacter(character);
	}

	public function loadCharacter(charName:String) {
		animOffsets = [];
		curCharacter = charName;
		try {
			data = Json.parse(Assets.getText('assets/characters/$curCharacter.json'));
		} catch(e) {
			lime.app.Application.current.window.alert('Character file "$curCharacter" could not be parsed.\n$e\nThe game will instead load BF.', "Character Parsing Fail");
			curCharacter = "bf";
			data = Json.parse(Assets.getText('assets/characters/bf.json'));
		}

		if (data.scale == null) data.scale = 1;
		if (data.scaleAffectsOffset == null) data.scaleAffectsOffset = false;
		if (data.flipX == null) data.flipX = false;
		if (data.antialiasing == null) data.antialiasing = true;
		if (data.singLength == null) data.singLength = 4;

		// If you wanna add new spritesheet types, add an fileExists function in this array, and add a case in the switch statement.
		var boolIndex:Int = [
			Assets.exists("assets/images/game-side/" + data.asset + ".txt") // txt exists. loading packer sheet.
		].indexOf(true);
		switch (boolIndex) {
			case 0:
				frames = Paths.getPackerAtlas("game-side/" + data.asset);
			default:
				frames = Paths.getSparrowAtlas("game-side/" + data.asset);
		}
		
		hpcolor = utils.CoolUtil.stringColor(data.barColor);

		for (anim in data.animations) {
			if (anim.looped == null) anim.looped = false;
			if (anim.flipX == null) anim.flipX = false;
			if (anim.flipY == null) anim.flipY = false;
			if (anim.frameRate == null) anim.frameRate = 24;

			if (anim.frameIndices != null && anim.frameIndices.length > 0)
				animation.addByIndices(anim.name, anim.prefix, anim.frameIndices, "", anim.frameRate, anim.looped, anim.flipX, anim.flipY);
			else
				animation.addByPrefix(anim.name, anim.prefix, anim.frameRate, anim.looped, anim.flipX, anim.flipY);

			if (data.scaleAffectsOffset) {
				anim.offsets[0] = anim.offsets[0] / data.scale;
				anim.offsets[1] = anim.offsets[1] / data.scale;
			}

			if (!animation.exists(anim.name))
				trace(curCharacter + ": COULDN'T ADD ANIMATION: " + anim.name);

			animOffsets.set(anim.name, anim.offsets);
		}
		leftRightDancer = (animation.exists("danceLeft") && animation.exists("danceRight"));

		scale.set(data.scale, data.scale);
		updateHitbox();
		flipX = (data.flipX && !isPlayer);
		antialiasing = data.antialiasing;

		if ((data.commonSide == "bf") != isPlayer) {
			if (animation.getByName('singRIGHT') != null) {
				var oldFrames = animation.getByName('singRIGHT').frames;
				animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;
				animation.getByName('singLEFT').frames = oldFrames;
				var oldOffsets = animOffsets['singRIGHT'];
				animOffsets['singRIGHT'] = animOffsets['singLEFT'];
				animOffsets['singLEFT'] = oldOffsets;
			}

			if (animation.getByName('singRIGHTmiss') != null) {
				var oldMiss = animation.getByName('singRIGHTmiss').frames;
				animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
				animation.getByName('singLEFTmiss').frames = oldMiss;
				var oldOffsets = animOffsets['singRIGHTmiss'];
				animOffsets['singRIGHTmiss'] = animOffsets['singLEFTmiss'];
				animOffsets['singLEFTmiss'] = oldOffsets;
			}
		}

		playAnim(leftRightDancer ? "danceRight" : "idle");
		danced = false;
		dance();

		x = regX + data.offsets.x;
		y = regY + data.offsets.y;
	}

	override function update(elapsed:Float) {
		x = regX + data.offsets.x;
		y = regY + data.offsets.y;

		if (animation.curAnim == null || debugMode) return;

		if (animation.curAnim.name.startsWith('sing'))
			holdTimer += elapsed;
		else if (isPlayer)
			holdTimer = 0;

		if (animation.curAnim.name == 'firstDeath' && animation.curAnim.finished)
			playAnim('deathLoop');

		var missEnded = (animation.curAnim.name.endsWith('miss') && animation.curAnim.finished);
		var singEnded = (holdTimer >= base.Conductor.stepCrochet * data.singLength * 0.001 && !isPlayer);
		var hairEnded = (animation.curAnim.name == 'hairFall' && animation.curAnim.finished);
		if (missEnded || singEnded || hairEnded) {
			dance();
			danced = (danced && !hairEnded);
			if (singEnded)
				holdTimer = 0;
		}

		super.update(elapsed);
	}

	private var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance() {
		if (debugMode || (animation.curAnim != null && animation.curAnim.name.startsWith('hair'))) return;

		danced = !danced;

		var danceAnim:String = 'idle';
		if (leftRightDancer)
			danceAnim = danced ? 'danceLeft' : "danceRight";

		playAnim(danceAnim);
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void {
		if (!animOffsets.exists(AnimName) || !animation.exists(AnimName))
			return; //Prevent playing animation if unavailable.

		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (animOffsets.exists(AnimName))
		{
			offset.set(daOffset[0], daOffset[1]);
		}
		else
			offset.set(0, 0);

		if (data.commonSide == "gf" && leftRightDancer) {
			danced = switch(AnimName) {
				case "singLEFT": true;
				case "singRIGHT": false;
				case "singUP" | "singDOWN": !danced;
				default: danced;
			}
		}
	}
}
