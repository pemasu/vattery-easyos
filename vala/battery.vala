/*

this is a part of vattery
copyright 2011 jezra lickter http://www.jezra.net

vattery is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

vattery is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with vattery.	If not, see <http://www.gnu.org/licenses/>.

*/
public enum BatteryDataType {
	PROC,
	SYS
}

public struct BatteryData {
	public int percent;
	public string state;
	/* EasyOS patch: estimated seconds until empty (draining) or full (charging), -1 if unknown */
	public int seconds_left;
}
const string DIR_PROC = "/proc/acpi/battery";
const string DIR_SYS = "/sys/class/power_supply";

public class Battery {
	Regex bat_curr_regex_proc;
	Regex bat_tot_regex_proc;
	Regex ac_regex;
	int64 bat_percent;
	string ac_state;
	int seconds_left = -1;
	/* EasyOS patch: the power draw jumps around from one reading to the next,
	 * so it is smoothed before the remaining time is worked out. */
	double smooth_rate = 0;
	string rate_state = "";
	public BatteryDataType data_type;
	
	
	public Battery() {
		//create a regex to retrieve the current battery power
		try {
			this.bat_curr_regex_proc = new Regex(".*remaining.*:[ \t\n\r\f]*([0-9]*).*",GLib.RegexCompileFlags.CASELESS,RegexMatchFlags.NEWLINE_ANY);
		}catch(GLib.RegexError error) {
			stdout.printf(error.message);
		}
		//create a regex to retrieve the last full capacity of the battery
		try {
			this.bat_tot_regex_proc = new Regex(".*last full capacity:[ \t\n\r\f]*([0-9]*).*",GLib.RegexCompileFlags.CASELESS,RegexMatchFlags.NEWLINE_ANY);
		} catch(GLib.RegexError error) {
			stdout.printf(error.message);
		}
		//create a regex to detect the "charging" status
		try {
			this.ac_regex = new Regex(".*charging.*:[ \t\n\r\f]*([a-z]*).*");
		} catch(GLib.RegexError error) {
			stdout.printf(error.message);
		}
    //check the files and see what sort of data type we should use
		check_data_type();
	}
	
	public BatteryData get_status( ) {
		BatteryData ret = BatteryData();
		//determine if we need to get sys or proc
		switch ( data_type ) {
			case BatteryDataType.SYS : 
				get_sys_status();
				break;
			case BatteryDataType.PROC :
				get_proc_status();
				break;
			default :
				//do nothing?
				break;
		}

		ret.percent = (int)this.bat_percent;
		ret.state = this.ac_state;
		ret.seconds_left = this.seconds_left;
		return ret;	
	}
	
	public void check_data_type() {
		string t;
		//can we use the sys?
		if (get_sys_status() ) {
			data_type = BatteryDataType.SYS;
			t="SYS";
		} else if ( get_proc_status() ) {
			data_type = BatteryDataType.PROC;
			t="PROC";
		} else {
			//bummer. unknown batterydatatype
			t="None";
		}
		stdout.printf("using data type: %s\n", t);
	}

	private bool get_proc_status() {
		string contents;
		MatchInfo match_info;
		string bat_curr="";
		string bat_total="";
		string ac_state="";
		int bats_current=0;
		int bats_total=0;
		int bats_percent;
		string state_file;
		string info_file;
		bool battery_data_found=false;
		
		//open the battery root for reading
		bool tloop = true;
		try {
			//stdout.printf("reading %s\n", DIR_PROC);
			GLib.Dir dir = GLib.Dir.open(DIR_PROC,0);
			dir.rewind();
			while (tloop) {
				var name = dir.read_name();
				if(name == null){
					tloop=false;
				}else{
					//something was found
					var check_path = "%s/%s".printf(DIR_PROC,name);
					//is this a directory?
					if(FileUtils.test(check_path,GLib.FileTest.IS_DIR) ) {
						//this is a directory, pretend it is a battery
						state_file = "%s/state".printf(check_path);
						info_file = "%s/info".printf(check_path);
						//does the state_file exist?
						if(FileUtils.test(state_file,FileTest.EXISTS) ){	
							try{
								if ( FileUtils.get_contents(state_file, out contents) ) {
									//regex to get current capacity
									this.bat_curr_regex_proc.match(contents,GLib.RegexMatchFlags.NEWLINE_ANY, out match_info);
									bat_curr = match_info.fetch(1);
									//regex to get the "charging" only if no ac state has been detected so far
									if (ac_state==""){
										this.ac_regex.match(contents,GLib.RegexMatchFlags.NEWLINE_ANY,out match_info);
										ac_state = match_info.fetch(1);
									}
									//now check the info file to get the last recorded max capacity
									if(FileUtils.get_contents(info_file, out contents) ) {
										//regex to get total capacity
										this.bat_tot_regex_proc.match(contents,GLib.RegexMatchFlags.NEWLINE_ANY,out match_info);
										bat_total = match_info.fetch(1);
										//if we ever get this far, then data was found
										battery_data_found=true;
										//add this batteries current charge to the overall charge
										bats_current+= int.parse(bat_curr);
										//add this batteries current total to the overall total
										bats_total+=int.parse(bat_total);
									}
								}
							}catch( GLib.FileError error){
								//there is a chance that no files exist
							}
						}
					}
				}
			}	 
		}catch(Error e){
			stderr.printf( e.message );
		}

		//did we find any data?
		if(battery_data_found && bats_total > 0){
			bats_percent = (bats_current*100/bats_total).clamp(0, 100);
			this.bat_percent = bats_percent;
			this.ac_state = ac_state;
			this.seconds_left = -1;
		
		}else{
			this.bat_percent = 0;
			this.ac_state = "NONE";
			stdout.printf("No battery info found in %s\n", DIR_PROC);
			return false;
		}
		return true;
	}
	private static string read_trimmed(string path) {
		string contents;
		try {
			if (FileUtils.get_contents(path, out contents)) {
				return contents.strip();
			}
		} catch (GLib.FileError error) {
			//the file may not exist on this machine
		}
		return "";
	}

	/* EasyOS patch: read /sys/class/power_supply the way modern kernels expose it.
	 * - any supply with type "Battery" counts (not only BAT*), except peripheral
	 *   batteries such as wireless mice (scope "Device")
	 * - energy_*, charge_* or plain "capacity" files are accepted
	 * - status "Full"/"Not charging"/"Unknown" while on mains power shows as charged
	 * - VATTERY_POWER_SUPPLY_DIR may point elsewhere (for testing) */
	private bool get_sys_status() {
		string root = Environment.get_variable("VATTERY_POWER_SUPPLY_DIR") ?? DIR_SYS;
		int64 sum_now = 0;
		int64 sum_full = 0;
		int64 pct_sum = 0;
		int count = 0;
		bool all_units = true;
		bool any_charging = false;
		bool any_discharging = false;
		bool mains_online = false;
		int64 sum_rate = 0;
		bool rate_ok = true;
		string units = "";

		try {
			GLib.Dir dir = GLib.Dir.open(root, 0);
			string? name;
			while ((name = dir.read_name()) != null) {
				var path = Path.build_filename(root, name);
				var type = read_trimmed(Path.build_filename(path, "type")).down();
				if (type == "mains" || type == "usb") {
					if (read_trimmed(Path.build_filename(path, "online")) == "1") {
						mains_online = true;
					}
					continue;
				}
				if (type != "battery" && !(type == "" && name.has_prefix("BAT"))) {
					continue;
				}
				if (read_trimmed(Path.build_filename(path, "scope")).down() == "device") {
					continue;
				}
				//find the charge level of this battery
				int64 now = -1;
				int64 full = -1;
				foreach (string prefix in new string[] {"energy", "charge"}) {
					var n = read_trimmed(Path.build_filename(path, prefix + "_now"));
					var f = read_trimmed(Path.build_filename(path, prefix + "_full"));
					if (n != "" && f != "" && int64.parse(f) > 0) {
						now = int64.parse(n);
						full = int64.parse(f);
						//how fast it is charging or draining: power_now goes with
						//energy_* (uW / uWh), current_now with charge_* (uA / uAh)
						var r = read_trimmed(Path.build_filename(path,
							prefix == "energy" ? "power_now" : "current_now"));
						if (r == "" || (units != "" && units != prefix)) {
							rate_ok = false;
						} else {
							int64 rv = int64.parse(r);
							sum_rate += rv < 0 ? -rv : rv;
						}
						units = prefix;
						break;
					}
				}
				int64 pct;
				if (full > 0) {
					pct = now * 100 / full;
					sum_now += now;
					sum_full += full;
				} else {
					var cap = read_trimmed(Path.build_filename(path, "capacity"));
					if (cap == "") {
						continue;
					}
					pct = int64.parse(cap);
					all_units = false;
				}
				pct_sum += pct.clamp(0, 100);
				count++;
				var status = read_trimmed(Path.build_filename(path, "status")).down();
				if (status == "charging") {
					any_charging = true;
				} else if (status == "discharging") {
					any_discharging = true;
				}
			}
		} catch (Error e) {
			stderr.printf("%s\n", e.message);
		}

		if (count == 0) {
			this.bat_percent = 0;
			this.ac_state = "NONE";
			stdout.printf("No battery info found in %s\n", root);
			return false;
		}

		int64 percent = (all_units && sum_full > 0) ? sum_now * 100 / sum_full : pct_sum / count;
		this.bat_percent = percent.clamp(0, 100);
		if (any_charging) {
			this.ac_state = "charging";
		} else if (any_discharging && !mains_online) {
			this.ac_state = "discharging";
		} else if (mains_online || !any_discharging) {
			this.ac_state = "charged";
		} else {
			this.ac_state = "discharging";
		}
		update_time_left(all_units && rate_ok, sum_now, sum_full, sum_rate);
		return true;
	}

	/* EasyOS patch: remaining time = charge left / power draw (or the missing
	 * charge / charging power while charging). */
	private void update_time_left(bool usable, int64 now, int64 full, int64 rate) {
		bool moving = this.ac_state == "discharging" || this.ac_state == "charging";
		if (!usable || !moving || rate <= 0 || full <= 0) {
			this.seconds_left = -1;
			if (!moving) {
				this.smooth_rate = 0;
			}
			this.rate_state = this.ac_state;
			return;
		}
		if (this.rate_state != this.ac_state || this.smooth_rate <= 0) {
			//just plugged in or unplugged: start fresh
			this.smooth_rate = (double) rate;
		} else {
			this.smooth_rate = this.smooth_rate * 0.9 + (double) rate * 0.1;
		}
		this.rate_state = this.ac_state;
		double amount = this.ac_state == "charging" ? (double)(full - now) : (double) now;
		double secs = amount / this.smooth_rate * 3600.0;
		//ignore silly values (e.g. a battery that reports almost no draw)
		this.seconds_left = (secs < 0 || secs > 48 * 3600) ? -1 : (int) secs;
	}

}
