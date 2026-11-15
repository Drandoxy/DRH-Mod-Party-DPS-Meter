package mods.party_dps_meter;

import actor.ActorGameObject;
import brain.render.MovieClipRenderController;
import distributedObjects.DistributedDungeonFloor;
import distributedObjects.NPCGameObject;
import dBGlobals.DBGlobal;
import generatedCode.AttackChoreography;
import generatedCode.CombatResult;
import mods.api.Context;
import mods.api.Subscription;
import modding.ModSubscription;
import mods.api.dungeon.Hero;
import mods.api.dungeon.Player;
import networkCode.DcNetworkPacket;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

private typedef DamageRow = {
	var player:Player;
	var name:String;
	var color:Int;
	var portrait:Sprite;
	var total:Float;
	var activeWindows:Int;
	var windowEndsAt:Int;
}

class PartyDamage extends Sprite {
	static inline final WIDTH = 298;
	static inline final ROW_HEIGHT = 24;

	var context:Context;
	var controls:PanelControls;
	var rows:Map<UInt, DamageRow> = new Map();
	var heroRows:Map<UInt, DamageRow> = new Map();
	var lastDraw = -1000;
	var packetWarning = false;
	var packet = new DcNetworkPacket();
	var dirty = true;
	var textPool:Array<TextField> = [];
	var textFormats:Map<Int, TextFormat> = new Map();
	var nextText = 0;
	var subscriptions:Array<Subscription> = [];
	var combat:ModSubscription;
    var endingFloor:DistributedDungeonFloor;
    var nextVisibilityCheck = 0;
    var waitingRenderers = ["mStartRenderer", "mKillSwitchRenderer", "mVictoryRenderer", "mDefeatRenderer"];

	public function new(context:Context) {
		super();
		this.context = context;
		var placement = new PanelPlacement();
		placement.load(context, "dps");
		controls = new PanelControls(this, context, placement,
			WIDTH, 53, 362);

		subscriptions.push(context.onTownEnter(function() resetRun()));
		subscriptions.push(context.onFloorEnter(function(floor) {
			if (floor.number == 1) resetRun();
			for (hero in context.state.heroes) if (!heroRows.exists(hero.id)) addHero(hero);
			visible = false;
			nextVisibilityCheck = 0;
			dirty = true;
		}));
		subscriptions.push(context.onFloorExit(function(_) {
			visible = false;
			endingFloor = null;
			controls.finish(null);
			heroRows = new Map();
		}));
		subscriptions.push(context.onHeroSpawned(addHero));
		subscriptions.push(context.onHeroDespawned(function(hero) {
			heroRows.remove(hero.id);
			lastDraw = -1000;
			dirty = true;
		}));
		combat = context.core.onFieldReceived(function(object, field, name) {
            if (StringTools.endsWith(name, ".floorEnding") || StringTools.endsWith(name, ".dungeonEnding")) {
                var floor = dungeonFloor();
                if (floor != null && object == floor.parentArea) {
                    endingFloor = floor;
                    visible = false;
                    controls.finish(null);
                }
            }
            if (!visible) return;
			var kind = StringTools.endsWith(name, ".ReceiveCombatResult") ? 1
				: StringTools.endsWith(name, ".ReceiveAttackChoreography") ? 2
				: StringTools.endsWith(name, ".setStateAndAttackChoreography") ? 3 : 0;
			if (kind == 0 || context.state.floor == null) return;
			var actor = Std.downcast(object, ActorGameObject);
			if (actor != null) readCombat(actor, field, kind);
		});
		visible = false;
		if (context.state.floor != null) for (hero in context.state.heroes) addHero(hero);
		addEventListener(Event.ENTER_FRAME, draw);
	}

	function addHero(hero:Hero):Void {
		var player = hero.player;
		if (player == null) return;
		var key = player.accountId;
		var row = rows.get(key);
		if (row == null) {
			row = {
				player: player,
				name: "",
				color: 0xFFFFFF,
				portrait: player.createPortrait(19),
				total: 0,
				activeWindows: 0,
				windowEndsAt: 0
			};
			rows.set(key, row);
		} else {
			row.player = player;
			row.portrait = player.createPortrait(19);
		}
		heroRows.set(hero.id, row);
		lastDraw = -1000;
		dirty = true;
	}

	function resetRun():Void {
		rows = new Map();
		heroRows = new Map();
		lastDraw = -1000;
		dirty = true;
	}

	function readCombat(actor:ActorGameObject, field:UInt, kind:Int):Void {
		var manager = context.core.facade.mDistributedObjectManager;
		if (manager == null || manager.socket == null) return;
		try {
			var socket = manager.socket;
			var received:DcNetworkPacket = Reflect.field(socket, "mPacket");
			if (received == null || received.length < 8) return;

			// Decode a copy. The game's packet cursor and contents belong to the socket.
			packet.length = 0;
			packet.position = 0;
			packet.writeBytes(received, 0, received.length);
			packet.position = 0;
			if (packet.readUnsignedShort() != socket.CLIENT_OBJECT_UPDATE_FIELD
				|| packet.readUnsignedInt() != actor.id || packet.readUnsignedShort() != field) return;
			if (kind == 1) {
				record(actor, CombatResult.readFromPacket(packet));
			} else {
				if (kind == 3) packet.readUTF();
				var choreography = AttackChoreography.readFromPacket(packet);
				var hits = choreography.combatResults;
				if (hits != null) {
					for (i in 0...hits.length) record(actor, hits[i]);
				}
			}
		} catch (error:Dynamic) {
			if (!packetWarning) context.log("Cannot decode a combat update: " + Std.string(error));
			packetWarning = true;
		}
	}

	function record(actor:ActorGameObject, hit:CombatResult):Void {
		if (hit.damage == 0 || hit.blocked != 0 || hit.attack == null) return;
		var floor = actor.distributedDungeonFloor;
		if (floor == null) return;
		var source = floor.getActor(hit.attacker);
		var target = floor.getActor(hit.attackee);
		if (source == null || !Std.isOfType(target, NPCGameObject)) return;
		if (target.team == source.team || target.team == DBGlobal.TEAM_ENVIRONMENT ||
			target.team == DBGlobal.TEAM_3 || target.isProp) return;
		var row = heroRows.get(hit.attacker);
		if (row == null && source.isPet) {
			var pet = Std.downcast(source, NPCGameObject);
			if (pet != null) row = heroRows.get(pet.masterId);
		}
		if (row == null) return;
		var attack:gameMasterDictionary.GMAttack = cast context.core.facade.gameMaster.attackById.itemFor(hit.attack.attackType);
		if (attack == null || attack.DamageMod > 0) return;
		addDamage(row, Math.abs(hit.damage), Lib.getTimer());
	}

	function addDamage(row:DamageRow, amount:Float, now:Int):Void {
		if (amount <= 0) return;
		if (row.activeWindows == 0 || now >= row.windowEndsAt) {
			row.windowEndsAt = now + 5000;
			row.activeWindows++;
		}
		row.total += amount;
		dirty = true;
	}

	function text(value:String, left:Float, top:Float, color:Int, bold:Bool):TextField {
		var field:TextField;
		if (nextText < textPool.length) {
			field = textPool[nextText];
		} else {
			field = new TextField();
			field.autoSize = TextFieldAutoSize.LEFT;
			field.selectable = false;
			textPool.push(field);
		}
		nextText++;
		var key = (color << 1) | (bold ? 1 : 0);
		var format = textFormats.get(key);
		if (format == null) {
			format = new TextFormat("_sans", 11, color, bold);
			textFormats.set(key, format);
		}
		field.defaultTextFormat = format;
		field.text = value;
		field.x = left;
		field.y = top;
		addChild(field);
		return field;
	}

	function rightText(value:String, right:Float, top:Float, color:Int):Void {
		var field = text(value, 0, top, color, true);
		field.x = right - field.width;
	}

	function number(value:Float):String {
		if (value >= 1000000) return Std.string(Math.round(value / 10000) / 100) + "M";
		if (value >= 1000) return Std.string(Math.round(value / 10) / 100) + "K";
		return Std.string(Math.round(value));
	}

    function dungeonFloor():DistributedDungeonFloor {
        var floor = context.state.floor;
        return floor == null ? null : @:privateAccess floor.floor;
    }

    function canShow():Bool {
        var facade = context.core.facade;
        if (facade == null || facade.mainStateMachine == null ||
            facade.mainStateMachine.currentStateName != "RunState") return false;
        var floor = dungeonFloor();
        if (floor == null || floor.isDestroyed || floor == endingFloor ||
            Reflect.field(floor, "mRevealed") == false) return false;
        var gui:Dynamic = Reflect.field(floor, "mFloorEndingGui");
        if (gui == null) return true;
        if (Reflect.field(gui, "mUpdateCountdownTask") != null) return false;
        for (name in waitingRenderers) {
            var renderer:MovieClipRenderController = Reflect.field(gui, name);
            if (renderer != null && renderer.isPlaying) return false;
        }
        return true;
    }

	function draw(event:Event):Void {
		var now = Lib.getTimer();
        if (now >= nextVisibilityCheck) {
            nextVisibilityCheck = now + 80;
            var show = canShow();
            if (visible != show) {
                visible = show;
                if (!visible) controls.finish(null);
            }
        }
		if (!visible || !context.overlay.visible) return;
		if (now - lastDraw < 200) return;
		lastDraw = now;

		controls.layout();
		for (row in rows) {
			var hero = row.player.hero;
			if (hero == null || heroRows.get(hero.id) != row) continue;
			var value = row.player.name;
			var name = value == null ? "" : StringTools.trim(value);
			if (name != row.name) {
				row.name = name;
				row.color = name == "" ? 0xFFFFFF : PlayerColor.fromName(name);
				dirty = true;
			}
		}
		if (!dirty) return;
		dirty = false;
		var sorted = [];
		for (row in rows) {
			var hero = row.player.hero;
			if (hero != null && heroRows.get(hero.id) == row && row.name != "") sorted.push(row);
		}
		sorted.sort(function(a, b) return a.total == b.total ? Reflect.compare(a.name, b.name) : (a.total > b.total ? -1 : 1));
		var total = 0.0;
		for (row in sorted) total += row.total;
		var highest = sorted.length == 0 ? 0 : sorted[0].total;

		nextText = 0;
		removeChildren();
		graphics.clear();
		graphics.lineStyle(1, 0x5B6975);
		graphics.beginFill(0x0E151D, 0.95);
		var panelHeight = 29 + Math.max(1, sorted.length) * ROW_HEIGHT;
		graphics.drawRoundRect(0, 0, WIDTH, panelHeight, 8, 8);
		graphics.endFill();
		graphics.lineStyle(0, 0, 0);
		text("Damage Done", 7, 4, 0xF4F7FA, true);
		rightText("DPS", WIDTH - 7, 4, 0xB6C2CC);
		if (sorted.length == 0) text("Waiting for party", 7, 27, 0xB6C2CC, false);

		for (index in 0...sorted.length) {
			var row = sorted[index];
			var dps = row.activeWindows == 0 ? 0 : row.total / (row.activeWindows * 5);
			var top = 24 + index * ROW_HEIGHT;
			var rowWidth = WIDTH - 8;
			graphics.beginFill(0x171C23);
			graphics.drawRect(4, top, rowWidth, 22);
			graphics.endFill();
			if (highest > 0 && row.total > 0) {
				var fillWidth = rowWidth * row.total / highest;
				graphics.beginFill(row.color, 0.50);
				graphics.drawRect(4, top, fillWidth, 22);
				graphics.endFill();
				graphics.beginFill(row.color, 0.85);
				graphics.drawRect(4, top + 21, fillWidth, 1);
				graphics.endFill();
			}

			row.portrait.x = 5;
			row.portrait.y = top + 1;
			addChild(row.portrait);
			text((index + 1) + ". " + row.name.substr(0, 13), 25, top + 2, 0xFFFFFF, true);
			var share = total == 0 ? 0 : Math.round(row.total * 1000 / total) / 10;
			rightText(number(row.total) + " (" + share + "%)", WIDTH - 62, top + 2, 0xFFFFFF);
			rightText(number(dps), WIDTH - 7, top + 2, 0xFFFFFF);
		}
		controls.layout(panelHeight);
	}

	public function destroy():Void {
		for (subscription in subscriptions) subscription.cancel();
		subscriptions = [];
		combat.cancel();
		controls.destroy();
		removeEventListener(Event.ENTER_FRAME, draw);
		if (parent != null) parent.removeChild(this);
	}
}
