package mods.party_dps_meter;

import mods.api.Context;
import mods.api.Mod;

class Main extends Mod {
    var meter:PartyDamage;

    override public function init(context:Context):Void {
        var active = context.settings.flag("active", "Enable DPS meter", "Track and show party damage.", true);
        active.onChange(function(enabled) setActive(context, enabled));
        setActive(context, active.value);
    }

    function setActive(context:Context, enabled:Bool):Void {
        if (enabled && meter == null) {
            meter = new PartyDamage(context);
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
