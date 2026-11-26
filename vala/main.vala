/*
vattery
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

using Gtk;
using Gdk;

public class main_controller {
	StatusIcon si;
	string app_name;
	string app_version;
	int bat_percent;
	int seconds_left = -1;
	string ac_state;
	string color_draining;
	string color_charging;
	string color_charged;
	string color_background;
	string color_border;
	string color_text;
	string percent_warning;
	string percent_critical;
	string command_warning;
	string command_critical;
	bool text_mode;
	bool displaying_preferences;
	bool triggered_warning;
	bool triggered_critical;
	IconMenu iconMenu;
	Configuration config;
	Battery battery;

	public main_controller(string name,string version) {
		bool color_changed = false;
		bool percent_command_changed=false;
		this.app_name = name;
		this.app_version = version;
		this.displaying_preferences=false;
		this.triggered_warning=false;
		this.triggered_critical=false;
		//set default colors
		this.color_charging = "#0000ff";
		this.color_draining = "#ff0000";
		this.color_background = "#ffffff";
		this.color_charged="#00ff00";
		this.color_border="#000000";
		this.color_text="#000000";
		//is there text mode?
		this.text_mode=false;
		//set default percents and commands
		percent_warning = "15";
		percent_critical = "5";
		command_warning = "vattery-alert \""+_("battery is very low")+"\"";
		command_critical = "vattery-alert \""+_("battery is critically low")+"\"";
		//determine the path of the config file
		string config_file_path = Path.build_filename( Environment.get_user_config_dir(),name,"config" );
		//load the config
		this.config = new Configuration(config_file_path);
		//try to load the colors from the config
		var color_charging = this.config.get_value("colors","charging");
		if (color_charging!=null) {
			this.color_charging = color_charging;
		} else {
			this.config.set_key_value("colors","charging",this.color_charging);
			color_changed=true;
		}
		//get the charged color
		var color_charged = this.config.get_value("colors","charged");
		if(color_charged!=null) {
			this.color_charged = color_charged;
		} else {
			this.config.set_key_value("colors","charged",this.color_charged);
			color_changed=true;
		}
		var color_draining = this.config.get_value("colors","draining");
		if(color_draining!=null) {
			this.color_draining = color_draining;
		} else {
			this.config.set_key_value("colors","draining",this.color_draining);
			color_changed=true;
		}
		var color_background = this.config.get_value("colors","background");
		if (color_background!=null) {
			this.color_background = color_background;
		} else {
			this.config.set_key_value("colors","background",this.color_background);
			color_changed=true;
		}
		var color_border = this.config.get_value("colors","border");
		if(color_border!=null) {
			this.color_border = color_border;
		} else {
			this.config.set_key_value("colors","border",this.color_border);
			color_changed=true;
		}
		var color_text = this.config.get_value("colors","text");
		if(color_text!=null) {
			this.color_text = color_text;
		} else {
			this.config.set_key_value("colors","text",this.color_text);
			color_changed=true;
		}
		text_mode = this.config.get_boolean_value("mode","text");
		if (text_mode) {
		//do nothing
		} else {
			this.config.set_key_value("mode","text","false");
		}
		var warn_percent = this.config.get_value("percents","warning");
		if (warn_percent!=null) {
			this.percent_warning = warn_percent;
		} else {
			this.config.set_key_value("percents","warning",this.percent_warning);
			percent_command_changed=true;
		}
		var warn_command = this.config.get_value("commands","warning");
		if (warn_command!=null) {
			this.command_warning = warn_command;
		} else {
			this.config.set_key_value("commands","warning",this.command_warning);
			percent_command_changed=true;
		}
		var crit_percent = this.config.get_value("percents","critical");
		if (crit_percent!=null) {
			this.percent_critical = crit_percent;
		} else {
			this.config.set_key_value("percents","critical",this.percent_critical);
			percent_command_changed=true;
		}
		var crit_command = this.config.get_value("commands","critical");
		if (crit_command!=null) {
			this.command_critical = crit_command;
		} else {
			this.config.set_key_value("commands","critical",this.command_critical);
			percent_command_changed=true;
		}
			
		//if the color has changed, save the configuration
		if(color_changed || percent_command_changed) {
			try {
				this.config.save_config();
			} catch(ConfigError err) {
				stderr.printf(err.message);
			}
		}
	 
		//create a battery
		this.battery = new Battery();
		//create a statusicon
		this.si=new StatusIcon();
		//we need to keep track of clicks on the status icon
		this.si.popup_menu.connect( (source,button,time)=>{status_icon_menu(button,time); } );
		//create the icons menu
		this.iconMenu = new IconMenu();
		//connect the signals of the icon menu
		this.iconMenu.show_about.connect( display_about_dialog );
		this.iconMenu.show_preferences.connect( display_preferences_dialog );
		this.iconMenu.quit.connect( Gtk.main_quit );
		//run get_battery_status ever two second
		GLib.Timeout.add(2000,this.get_battery_status);
		//do an initial run of get_battery_status
		this.get_battery_status();
	}
	
	private void preferences_destroyed() {
		//the preferences dialog has been destroyed
		this.displaying_preferences=false;
	}
	
	private void display_preferences_dialog() {
		//is a display already visible?
		if (!this.displaying_preferences) {
			//create the preferences window
			Preferences preferences = new Preferences();
			//hey,we are about to show a preferences dialog
			this.displaying_preferences=true;
			//update the colors in the preferences
			preferences.set_colors(this.color_charging,this.color_charged,this.color_draining,
				this.color_border,this.color_background);
			//update the warnings of the preferences
			preferences.set_warnings(this.percent_warning,this.command_warning,
				this.percent_critical,this.command_critical);
			//the txt mode thing
			preferences.set_text_mode(this.text_mode);
			//connect the preferences signals
			preferences.gui_destroyed.connect( preferences_destroyed );
			preferences.emit_preferences.connect(
			(charge,charged, drain,	border, background, wp, wc, cp, cc,m)=>{ 
				update_and_save_preferences(	charge,charged, drain,	border, 
				background, wp, wc, cp, cc, m);
			} );
			//set the icon of the preferences window based on the pixbuf of the statusicon
			var pb = this.si.get_pixbuf();
			preferences.set_icon(pb);
			
			//actually display the thing
			preferences.display();
		}
	}
	private void update_and_save_preferences( Color charging,
	Color charged, Color draining, Color border, Color background, 
	string pw, string cw, string pc, string cc, bool mode)
	{
		//start with the colors
		this.color_charging = hex_color(charging);
		this.config.set_key_value("colors","charging",this.color_charging);
		this.color_charged = hex_color(charged);
		this.config.set_key_value("colors","charged",this.color_charged);
		this.color_draining = hex_color(draining);
		this.config.set_key_value("colors","draining",this.color_draining);
		this.color_border = hex_color(border);
		this.config.set_key_value("colors","border",this.color_border);
		this.color_background = hex_color(background);
		this.config.set_key_value("colors","background",this.color_background);
		/*this.color_text = hex_color(text);
		this.config.set_key_value("colors","text",this.color_text); */
		//do the commands and percents
		this.percent_warning = pw;
		this.config.set_key_value("percents","warning",this.percent_warning);
		this.command_warning = cw;
		this.config.set_key_value("commands","warning",this.command_warning);
		
		this.percent_critical = pc;
		this.config.set_key_value("percents","critical",this.percent_critical);
		this.command_critical = cc;
		this.config.set_key_value("commands","critical",this.command_critical);
		//handle the mode
		this.text_mode = mode;
		this.config.set_key_value("mode","text",mode.to_string() );
		//write the config
		try {
			this.config.save_config();
		} catch(ConfigError err) {
			stderr.printf(err.message);
		}
		//update the icon
		this.update_status_icon();
		/* EasyOS patch: start the alerts over with the new settings and check them
		 * now, instead of waiting for the battery level to change. */
		this.triggered_warning = false;
		this.triggered_critical = false;
		if (this.ac_state != null && this.ac_state != "NONE") {
			this.check_triggers();
		}
	}
	
	private void display_about_dialog()
	{
		//create an about dialog
		AboutDialog aboutDialog = new AboutDialog();
		//set the icon of the about window based on the pixbuf of the statusicon
		var pb = this.si.get_pixbuf();
		aboutDialog.set_icon(pb);
		aboutDialog.set_program_name(this.app_name);
		aboutDialog.set_version(this.app_version); 
		aboutDialog.set_comments("A fairly simple battery monitor.\nPatched for EasyOS.");
		aboutDialog.set_website("http://www.jezra.net/projects/vattery");
		aboutDialog.set_copyright("©2011 Jezra J Lickter");
		aboutDialog.show_all();
		aboutDialog.run();
		aboutDialog.destroy();
	}
	private void run() {
		//run the Gtk mainloop
		Gtk.main();
	}
	
	private void status_icon_menu(uint button, uint time) {
		//popup the iconMenu
		this.iconMenu.popup(null,null,null,button,time);
	}
	
	private void update_status_icon() {
		PixbufLoader ploader;
		Pixbuf pb;
		string svg_str,frect_color;
		double frect_y,frect_height,frect_x,frect_width;
		double brect_x,brect_width;
		int border_width = 2;
		brect_width=50;
		frect_width = brect_width-border_width;
		brect_x = (100-brect_width)/2;
		frect_x = (100-frect_width)/2;
		//what color should the bar be?
		if(ac_state=="charging") {
			frect_color = this.color_charging;
		} else if(ac_state=="charged" || this.bat_percent==100) {
			frect_color = this.color_charged;
		} else {
			frect_color = this.color_draining;
		}

		svg_str= "<?xml version=\"1.0\" standalone=\"no\"?><!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n";
		svg_str+="<svg width=\"100px\" height=\"100px\" viewBox=\"0 0 100 100\" preserveAspectRatio=\"xMidYMid meet\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\">\n";
		if (this.text_mode) {
			//add text 
			svg_str+=" <text style=\"text-align:center;\" x=\"0\" y=\"65\" fill=\"%s\" font-size = \"40\">%d%%</text>".printf(frect_color,this.bat_percent);
		} else {
			//make the border
			svg_str+="<rect x=\"%.0f\" y=\"0\" width=\"%.0fpx\" height=\"100px\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%i\"	/>\n".printf(brect_x,brect_width,this.color_background,this.color_border, border_width);
			//make the fill
			/* EasyOS patch: whole numbers only. "%0.1f" follows the language setting,
			 * so in e.g. Finnish it wrote "57,0", which the SVG reader rejects and
			 * the coloured bar vanished, leaving a white battery. */
			frect_height = double.max(0, this.bat_percent-(border_width*2));
			frect_y = 100 - (frect_height+(border_width/2) );
			svg_str+="<rect x=\"%.0f\" y=\"%.0f\" width=\"48px\" height=\"%.0fpx\" fill=\"%s\" stroke-width=\"0\"	/>\n".printf(frect_x,frect_y,frect_height,frect_color);			
		}
		//close the svg tag
		svg_str+="</svg>\n";
		//convert the str to uchar
		uchar[] svg_data = new uchar[svg_str.length];
		for (int i=0; i< svg_str.length; i++) {
			svg_data[i] = (uchar)svg_str[i];
		}

		//get a gdk pixbuf from the svg string
		try {
			//create a new pixbufloader
			ploader = new PixbufLoader.with_type("svg");
			ploader.write(svg_data);
			ploader.close();
			pb = ploader.get_pixbuf();
			this.si.set_from_pixbuf(pb);
			this.set_tooltip_text( tooltip_string() );
		} catch (Error er ) {
			this.die(er.message);
		}
	}
	
	/* EasyOS patch: e.g. "63 % - 6 hours 5 mins remaining time" */
	private string tooltip_string() {
		string text = "%i %%".printf(this.bat_percent);
		if (this.ac_state == "charged") {
			return text + " - fully charged";
		}
		if (this.seconds_left < 0) {
			return text;
		}
		int total_mins = (this.seconds_left + 30) / 60;
		int hours = total_mins / 60;
		int mins = total_mins % 60;
		string time = "";
		if (hours > 0) {
			time = "%d %s".printf(hours, hours == 1 ? "hour" : "hours");
		}
		if (mins > 0 || hours == 0) {
			if (time != "") {
				time += " ";
			}
			time += "%d %s".printf(mins, mins == 1 ? "min" : "mins");
		}
		if (this.ac_state == "charging") {
			return "%s - %s until full".printf(text, time);
		}
		return "%s - %s remaining time".printf(text, time);
	}

	private string last_tooltip = "";
	private void set_tooltip_text(string str) {
		if (str == this.last_tooltip) {
			return;
		}
		this.last_tooltip = str;
		this.si.set_tooltip_text(str);
		stdout.printf("vattery: tray: %s\n", str);
		stdout.flush();
	}
	
	private void die(string str) {
		stdout.printf("%s v%s: %s\n",this.app_name,this.app_version,str);
		Gtk.main_quit();
	}
	
	private string hex_color(Color c) {
		string ret = "#";
		string color = c.to_string();
		string red = color.substring(1,2);
		string blue = color.substring(5,2);
		string green = color.substring(9,2);
		
		ret+=red+blue+green;
		return ret;
	}
	
	private bool get_battery_status() {
		string ac_state;
		int bat_percent;
		BatteryData data = battery.get_status();
		bat_percent = data.percent;
		ac_state = data.state;
			
		if ( ac_state!="NONE" ) {
			//the remaining time changes even when the percent does not
			bool time_changed = data.seconds_left != this.seconds_left;
			this.seconds_left = data.seconds_left;
			if (time_changed && bat_percent==this.bat_percent && ac_state==this.ac_state) {
				this.set_tooltip_text( tooltip_string() );
			}
			if(bat_percent!=this.bat_percent || ac_state!=this.ac_state) {
				//record the values
				this.bat_percent = bat_percent;
				this.ac_state = ac_state;
				stdout.printf("vattery: %d%% %s\n", bat_percent, ac_state);
				stdout.flush();
				this.check_triggers();
				this.update_status_icon();
			}
		} else {
			//we should let the user know that no data was found
			this.set_tooltip_text(_("No batteries were found") );
		}
		return true;
	}

	private void check_triggers() {
		//get an int of the percents
		int wp = int.parse(this.percent_warning);
		int cp = int.parse(this.percent_critical);
		//if we are charging
		if(this.ac_state=="charging") {
			if (this.bat_percent>=wp ) {
				this.triggered_warning=false;
			}
			if( this.bat_percent>=cp ) {
				this.triggered_critical=false;
			}
		} else {
			//we are draining
			//if the bat percent is below the warning percent and not yet triggered
			if(this.bat_percent<=wp && this.triggered_warning==false ) {
				do_command(this.command_warning);
				this.triggered_warning = true;
			}
			if(this.bat_percent<=cp && this.triggered_critical==false	 ) {
				do_command(this.command_critical);
				this.triggered_critical=true;
			}
		}	
	}
	
	/* EasyOS patch: run the command through /bin/sh, so shell features such as
	 * "echo mem > /sys/power/state", pipes and && work. Without a shell the ">"
	 * was handed to echo as plain text and nothing happened. */
	public void do_command(string raw_command) {
		string command = raw_command.strip();
		if (command == "") {
			return;
		}
		stdout.printf("vattery: running: %s\n", command);
		stdout.flush();
		try {
			string[] argv = { "/bin/sh", "-c", command };
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
		} catch(SpawnError err) {
			stderr.printf("vattery: could not run \"%s\": %s\n", command, err.message);
		}
	}

	private static void main(string[] args) {		
		#if ! VALACOMPILE
		Intl.bindtextdomain( Config.GETTEXT_PACKAGE, Config.LOCALEDIR );
		Intl.bind_textdomain_codeset( Config.GETTEXT_PACKAGE, "UTF-8" );
		Intl.textdomain( Config.GETTEXT_PACKAGE );
		#endif
		
		string app_name = Config.PACKAGE_NAME;
		string app_version = Config.PACKAGE_VERSION;
		//init Gtk
		Gtk.init(ref args);
		//run the main controller
		main_controller mc = new main_controller(app_name,app_version);
		mc.run();
	}
}
