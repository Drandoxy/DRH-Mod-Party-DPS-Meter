package mods.party_dps_meter;

import mods.api.Context;
import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.events.Event;
import openfl.events.MouseEvent;

class PanelControls {
	static inline final CORNER = 15.;
	static inline final MIN_SCALE = 0.55;
	static inline final MAX_SCALE = 2.5;

	var panel:Sprite;
	var context:Context;
	var placement:PanelPlacement;
	var hint:Sprite = new Sprite();
	var panelWidth:Float;
	var panelHeight:Float;
	var defaultTop:Float;
	var gestureStage:Stage;
	var mode = 0;
	public var dragHeaderHeight = 0.0;
	var startMouseX = 0.;
	var startMouseY = 0.;
	var startX = 0.;
	var startY = 0.;
	var startScale = 1.;

	public function new(panel:Sprite, context:Context, placement:PanelPlacement, width:Float, height:Float, defaultTop:Float) {
		this.panel = panel;
		this.context = context;
		this.placement = placement;
		this.panelWidth = width;
		this.panelHeight = height;
		this.defaultTop = defaultTop;
		panel.mouseEnabled = true;
		panel.mouseChildren = false;
		panel.addEventListener(MouseEvent.MOUSE_DOWN, start);
		panel.addEventListener(MouseEvent.MOUSE_MOVE, hover);
		panel.addEventListener(MouseEvent.ROLL_OUT, leave);
	}

	public function layout(?height:Float):Void {
		if (height != null) panelHeight = height;
		if (hint.parent != panel) panel.addChild(hint);
		if (mode != 0 || context.viewWidth <= 0 || context.viewHeight <= 0) return;
		var zoom = Math.min(placement.scale, Math.min(context.viewWidth / panelWidth, context.viewHeight / panelHeight));
		panel.scaleX = panel.scaleY = zoom;
		var maxX = Math.max(0, context.viewWidth - panelWidth * zoom);
		var maxY = Math.max(0, context.viewHeight - panelHeight * zoom);
		panel.x = Math.max(0, Math.min(maxX, !placement.hasPosition ? maxX - 10 : placement.left));
		panel.y = Math.max(0, Math.min(maxY, !placement.hasPosition ? defaultTop : placement.top));
	}

	function corner():Int {
		var x = panel.mouseX;
		var y = panel.mouseY;
		if (y < panelHeight - CORNER || y > panelHeight || x < 0 || x > panelWidth) return 0;
		if (x < CORNER) return -1;
		return x > panelWidth - CORNER ? 1 : 0;
	}

	function showCorner(side:Int):Void {
		var pen = hint.graphics;
		pen.clear();
		if (side == 0) return;
		var x = side < 0 ? 3. : panelWidth - 3;
		pen.lineStyle(1.4, 0xE6F1FA, 0.95);
		pen.moveTo(x, panelHeight - 12);
		pen.lineTo(x, panelHeight - 3);
		pen.lineTo(x - side * 9, panelHeight - 3);
		pen.moveTo(x, panelHeight - 3);
		pen.lineTo(x - side * 8, panelHeight - 11);
	}

	function hover(event:MouseEvent):Void {
		if (mode == 0) showCorner(corner());
	}

	function leave(event:MouseEvent):Void {
		if (mode == 0) showCorner(0);
	}

	function start(event:MouseEvent):Void {
		if (mode != 0 || panel.stage == null || panel.parent == null) return;
		var side = corner();
		if (side == 0 && dragHeaderHeight > 0 && panel.mouseY > dragHeaderHeight) return;
		mode = side == 0 ? 2 : side;
		startMouseX = panel.parent.mouseX;
		startMouseY = panel.parent.mouseY;
		startX = panel.x;
		startY = panel.y;
		startScale = panel.scaleX;
		gestureStage = panel.stage;
		gestureStage.addEventListener(MouseEvent.MOUSE_MOVE, change);
		gestureStage.addEventListener(MouseEvent.MOUSE_UP, finish);
		gestureStage.addEventListener(Event.DEACTIVATE, finish);
		event.stopPropagation();
	}

	function change(event:MouseEvent):Void {
		if (panel.parent == null) return;
		var dx = panel.parent.mouseX - startMouseX;
		var dy = panel.parent.mouseY - startMouseY;
		var width = context.viewWidth;
		var height = context.viewHeight;
		if (mode == 2) {
			panel.x = Math.max(0, Math.min(width - panelWidth * panel.scaleX, startX + dx));
			panel.y = Math.max(0, Math.min(height - panelHeight * panel.scaleY, startY + dy));
		} else {
			var right = startX + panelWidth * startScale;
			var available = mode < 0 ? right : width - startX;
			var limit = Math.min(MAX_SCALE, Math.min(available / panelWidth, (height - startY) / panelHeight));
			var delta = (mode * dx * panelWidth + dy * panelHeight)
				/ (panelWidth * panelWidth + panelHeight * panelHeight);
			var zoom = Math.max(Math.min(MIN_SCALE, limit), Math.min(limit, startScale + delta));
			panel.scaleX = panel.scaleY = zoom;
			panel.x = mode < 0 ? right - panelWidth * zoom : startX;
		}
		placement.hasPosition = true;
		placement.left = panel.x;
		placement.top = panel.y;
		placement.scale = panel.scaleX;
	}

	public function finish(event:Event):Void {
		if (mode != 0) placement.save();
		if (gestureStage != null) {
			gestureStage.removeEventListener(MouseEvent.MOUSE_MOVE, change);
			gestureStage.removeEventListener(MouseEvent.MOUSE_UP, finish);
			gestureStage.removeEventListener(Event.DEACTIVATE, finish);
			gestureStage = null;
		}
		mode = 0;
		showCorner(0);
	}

	public function destroy():Void {
		finish(null);
		panel.removeEventListener(MouseEvent.MOUSE_DOWN, start);
		panel.removeEventListener(MouseEvent.MOUSE_MOVE, hover);
		panel.removeEventListener(MouseEvent.ROLL_OUT, leave);
	}
}
