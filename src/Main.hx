package mods.party_dps_meter;

import mods.api.Context;
import mods.api.Mod;
import openfl.ui.Keyboard;

class Main extends Mod {
    var meter:PartyDamage;
    var placement = new PanelPlacement();

    override public function init(context:Context):Void {
        placement.load(context, "dps");
        context.keys.action("toggleDpsChord", "Toggle party DPS meter", "Enable or disable party damage tracking.", Keyboard.D, true, true)
            .onPress(function() {
                placement.enabled = !placement.enabled;
                placement.save();
                setActive(context, placement.enabled);
            });
        setActive(context, placement.enabled);
    }

    function setActive(context:Context, enabled:Bool):Void {
        if (enabled && meter == null) {
            meter = new PartyDamage(context, placement);
            context.overlay.addChild(meter);
        } else if (!enabled) {
            dispose();
        }
    }

    override public function dispose():Void {
        if (meter == null) return;
        meter.destroy();
        meter = null;
    }
}
