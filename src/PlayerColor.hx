package mods.party_dps_meter;

class PlayerColor {
	public static function fromName(name:String):Int {
		if (name == null || StringTools.trim(name) == "") return 0xFFFFFF;
		var normalized = StringTools.trim(name).toLowerCase();
		var hash = 0;
		for (i in 0...normalized.length) hash = (hash * 131 + normalized.charCodeAt(i)) % 65521;
		var hue = (hash % 360) / 60;
		var middle = 165 * (1 - Math.abs(hue % 2 - 1));
		var low = 86;
		var high = 251;
		var mid = low + Std.int(middle);
		return switch (Std.int(hue)) {
			case 0: (high << 16) | (mid << 8) | low;
			case 1: (mid << 16) | (high << 8) | low;
			case 2: (low << 16) | (high << 8) | mid;
			case 3: (low << 16) | (mid << 8) | high;
			case 4: (mid << 16) | (low << 8) | high;
			default: (high << 16) | (low << 8) | mid;
		};
	}
}
