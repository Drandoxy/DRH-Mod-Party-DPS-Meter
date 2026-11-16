package mods.party_dps_meter;

import mods.api.Context;

/** Panel layout is UI state, stored separately from gameplay settings. */
class PanelPlacement {
    public var enabled = true;
    public var hasPosition = false;
    public var left = 0.;
    public var top = 0.;
    public var scale = 1.;
    public var zoom = 1.;
    var path:String;
    var ctx:Context;

    public function new() {}

    public function load(context:Context, name:String):Void {
        ctx = context;
        path = context.data + "/" + name + "_layout.json";
        try {
            if (!sys.FileSystem.exists(path)) return;
            var data:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
            left = number(data.left, 0, 0, 100000);
            top = number(data.top, 0, 0, 100000);
            scale = number(data.scale, 1, 0.55, 2.5);
            zoom = number(data.zoom, 1, 1, 3);
            enabled = data.enabled != false;
            hasPosition = data.hasPosition == true;
        } catch (error:Dynamic) {
            context.log("Could not load panel layout: " + Std.string(error));
        }
    }

    static function number(value:Dynamic, fallback:Float, minimum:Float, maximum:Float):Float {
        if (!Std.isOfType(value, Float) && !Std.isOfType(value, Int)) return fallback;
        var n:Float = value;
        if (!Math.isFinite(n)) return fallback;
        return Math.max(minimum, Math.min(maximum, n));
    }

    public function save():Void {
        if (path == null) return;
        try {
            sys.io.File.saveContent(path, haxe.Json.stringify({
                enabled: enabled, hasPosition: hasPosition, left: left, top: top, scale: scale, zoom: zoom
            }));
        } catch (error:Dynamic) {
            ctx.log("Could not save panel layout: " + Std.string(error));
        }
    }
}
