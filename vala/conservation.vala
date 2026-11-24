/*
this is a part of vattery (EasyOS edition)
vattery copyright 2011 jezra lickter, GPL v3 or later.
Conservation mode: limits charging to about 80 % on laptops whose
kernel driver supports it (same drivers as the common bash script).
Set VATTERY_SYSFS_ROOT to test against a fake /sys tree.
*/
public class Conservation : Object {
	public string vendor = "";
	public string path = "";
	private string kind = "";  // flag, threshold, huawei, limit100, limit0

	private static string root() {
		string? r = Environment.get_variable("VATTERY_SYSFS_ROOT");
		return (r == null) ? "" : r;
	}

	private static string? read(string p) {
		string s;
		try { FileUtils.get_contents(p, out s); } catch (Error e) { return null; }
		return s.strip();
	}

	// sysfs files must be written in place, not via a temporary file
	private static bool write(string p, string val) {
		var f = FileStream.open(p, "w");
		if (f == null) return false;
		f.puts(val + "\n");
		f.flush();
		return f.error() == 0;
	}

	private static string? first_child_with(string dir, string file) {
		try {
			var d = Dir.open(dir);
			string? n;
			while ((n = d.read_name()) != null) {
				string p = Path.build_filename(dir, n, file);
				if (FileUtils.test(p, FileTest.EXISTS)) return p;
			}
		} catch (Error e) {}
		return null;
	}

	private bool use(string v, string k, string? p) {
		if (p == null || !FileUtils.test(p, FileTest.EXISTS)) return false;
		vendor = v; kind = k; path = p;
		return true;
	}

	/* returns true when this computer supports conservation mode */
	public bool detect() {
		string r = root();
		return use("Lenovo IdeaPad", "flag", first_child_with(r + "/sys/bus/platform/drivers/ideapad_acpi", "conservation_mode"))
			|| use("Charge limit", "threshold", first_child_with(r + "/sys/class/power_supply", "charge_control_end_threshold"))
			|| use("Huawei", "huawei", r + "/sys/devices/platform/huawei-wmi/charge_control_thresholds")
			|| use("LG Gram", "limit100", r + "/sys/devices/platform/lg-laptop/battery_care_limit")
			|| use("Samsung", "flag", r + "/sys/bus/platform/devices/samsung/battery_life_extender")
			|| use("Sony VAIO", "limit0", r + "/sys/devices/platform/sony-laptop/battery_care_limiter")
			|| use("Acer", "flag", r + "/sys/bus/wmi/drivers/acer-wmi/health_mode");
	}

	/* 1 = on, 0 = off, -1 = cannot read */
	public int status() {
		string? v = read(path);
		if (v == null || v == "") return -1;
		switch (kind) {
		case "flag": return v == "1" ? 1 : 0;
		case "threshold":
		case "limit100": return int.parse(v) < 100 ? 1 : 0;
		case "limit0": return int.parse(v) > 0 ? 1 : 0;
		case "huawei":
			string[] parts = v.split(" ");
			return int.parse(parts[parts.length - 1]) < 100 ? 1 : 0;
		}
		return -1;
	}

	public string raw() { string? v = read(path); return v == null ? "?" : v; }

	public bool set_mode(bool on) {
		bool ok;
		string start = path.replace("end_threshold", "start_threshold");
		switch (kind) {
		case "flag": ok = write(path, on ? "1" : "0"); break;
		case "threshold":
			if (on) {
				if (FileUtils.test(start, FileTest.EXISTS)) write(start, "75");
				ok = write(path, "80");
			} else {
				ok = write(path, "100");
				if (FileUtils.test(start, FileTest.EXISTS)) write(start, "0");
			}
			break;
		case "huawei": ok = write(path, on ? "75 80" : "0 100"); break;
		case "limit100": ok = write(path, on ? "80" : "100"); break;
		case "limit0": ok = write(path, on ? "80" : "0"); break;
		default: ok = false; break;
		}
		stdout.printf("vattery: conservation %s %s (%s)\n", on ? "on" : "off", ok ? "ok" : "FAILED", path);
		return ok && status() == (on ? 1 : 0);
	}
}
