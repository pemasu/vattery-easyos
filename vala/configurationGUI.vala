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
using Gtk;
using Gdk;
delegate void RefreshFunc();
public class Preferences : Gtk.Window {
	//define some signals
	public signal void emit_preferences(Color charge, Color charged,
	Color drain, Color border,Color background,
	string wp,string wc,string cp,string cc, bool text_mode);
	
	public signal void gui_destroyed();
	
	private ColorButton borderButton;
	private ColorButton chargingButton;
	private ColorButton chargedButton;
	private ColorButton drainingButton;
	private ColorButton backgroundButton;
	//private ColorButton textButton;
	private SpinButton warningPercent;
	private SpinButton criticalPercent;
	private Entry warningCommand;
	private Entry criticalCommand;
	private CheckButton text_modeButton;
	
	construct {
		type = Gtk.WindowType.TOPLEVEL;
	}
	
	public Preferences() {
		//define four table element sides
		int table_l=0;
		int table_t =0;
		int table_r=1;
		int table_b =1;
		//set_decorated(false);
		set_modal(true);
		set_resizable(false);
		set_title(_("Preferences"));
		set_deletable(false);
		
		text_modeButton = new CheckButton.with_label(_("Text Mode"));
		
		VBox topVbox = new VBox(false,5);
		//add the button to the CheckButton
		topVbox.add(text_modeButton);
		topVbox.set_border_width(3);
		//add the topVbox to the window
		add(topVbox);
		Table table = new Table(4,2,false);
		table.set_border_width(3);
		table.set_col_spacings(3);
		table.set_row_spacings(3);
		Frame colorsFrame = new Frame(_("Colors"));
		colorsFrame.add(table);
		
		borderButton = new ColorButton();
		chargingButton = new ColorButton();
		chargedButton = new ColorButton();
		drainingButton = new ColorButton();
		backgroundButton = new ColorButton();
		//textButton = new ColorButton();
		Alignment align;

		Label chargingLabel = new Label(_("Charging:"));
		chargingLabel.set_alignment(0,(float)0.5);
		//add the label to the table
		table.attach(chargingLabel,table_l,table_r,table_t,table_b,AttachOptions.FILL,AttachOptions.FILL,0,0);
		align = new Alignment(0,0,0,0);
		align.add(chargingButton);
		table.attach(align,table_l+1,table_r+1,table_t,table_b,AttachOptions.FILL,AttachOptions.FILL,0,0);
		
		//increment the top and bottom
		table_t+=1;
		table_b+=1;
		
		Label chargedLabel = new Label(_("Charged:"));
		chargedLabel.set_alignment(0,(float)0.5);
		//add the label to the table
		table.attach(chargedLabel,table_l,table_r,table_t,table_b,AttachOptions.FILL,AttachOptions.FILL,0,0);
		align = new Alignment(0,0,0,0);
		align.add(chargedButton);
		table.attach(align,table_l+1,table_r+1,table_t,table_b,AttachOptions.FILL,AttachOptions.FILL,0,0);
		
		//increment the top and bottom
		table_t+=1;
		table_b+=1;
		
		Label drainingLabel = new Label(_("Draining:"));
		drainingLabel.set_alignment(0,(float)0.5);
		//add the label to the table
		table.attach(drainingLabel,table_l,table_r,table_t,table_b,AttachOptions.FILL,AttachOptions.FILL,0,0);
		align = new Alignment(0,0,0,0);
		align.add(drainingButton);
		table.attach(align,table_l+1,table_r+1,table_t,table_b,AttachOptions.FILL,AttachOptions.FILL,0,0);
		
		//increment the top and bottom
		table_t+=1;
		table_b+=1;
		
		Label borderLabel = new Label(_("Border:"));
		borderLabel.set_alignment(0,(float)0.5);
		//add the label to the table
		table.attach(borderLabel,table_l,table_r,table_t,table_b,AttachOptions.FILL,AttachOptions.FILL,0,0);
		align = new Alignment(0,0,0,0);
		align.add(borderButton);
		table.attach(align,table_l+1,table_r+1,table_t,table_b,AttachOptions.FILL,AttachOptions.FILL,0,0);
		
		//increment the top and bottom
		table_t+=1;
		table_b+=1;
		
		Label backgroundLabel = new Label(_("Background:"));
		backgroundLabel.set_alignment(0,(float)0.5);
		//add the label to the table
		table.attach(backgroundLabel,table_l,table_r,table_t,table_b,AttachOptions.FILL,AttachOptions.FILL,0,0);
		align = new Alignment(0,0,0,0);
		align.add(backgroundButton);
		table.attach(align,table_l+1,table_r+1,table_t,table_b,AttachOptions.FILL,AttachOptions.FILL,0,0);

		//add the colors frame to the topVbox
		topVbox.add(colorsFrame);
		/* conservation mode (EasyOS edition) */
		topVbox.add(make_conservation_frame());
		/* make stuff for warning */
		Frame warningFrame = new Frame(_("Warning"));
		//add the frame to the window
		topVbox.add(warningFrame);
		table = new Table(2,2,false);
		table.set_border_width(3);
		table.set_col_spacings(3);
		table.set_row_spacings(3);
		warningFrame.add(table);
		Label percentLabel = new Label(_("Percent:"));
		percentLabel.set_alignment(0,(float)0.5);
		table.attach(percentLabel,0,1,0,1,AttachOptions.FILL,AttachOptions.FILL,0,0);
		//create the warningPercent spinbutton
		warningPercent= new SpinButton.with_range(0,100,1);
		align = new Alignment(0,0,0,0);
		align.add(warningPercent);
		table.attach(align,1,2,0,1,AttachOptions.FILL,AttachOptions.FILL,0,0);
		Label commandLabel = new Label(_("Command:"));
		commandLabel.set_alignment(0,0);
		table.attach(commandLabel,0,1,1,2,AttachOptions.EXPAND,AttachOptions.EXPAND,0,0);
		//create and add the warning text box
		warningCommand = new Entry();
		table.attach(warningCommand,1,2,1,2,AttachOptions.FILL,AttachOptions.FILL,0,0);
		/* make stuff for critical */
		Frame criticalFrame = new Frame(_("Critical"));
		//add the frame to the window
		topVbox.add(criticalFrame);
		table = new Table(2,2,false);
		table.set_border_width(3);
		table.set_col_spacings(3);
		table.set_row_spacings(3);
		criticalFrame.add(table);
		percentLabel = new Label(_("Percent:"));
		percentLabel.set_alignment(0,(float)0.5);
		table.attach(percentLabel,0,1,0,1,AttachOptions.FILL,AttachOptions.FILL,0,0);
		//create the criticalPercent spinbutton
		criticalPercent= new SpinButton.with_range(0,100,1);
		align = new Alignment(0,0,0,0);
		align.add(criticalPercent);
		table.attach(align,1,2,0,1,AttachOptions.FILL,AttachOptions.FILL,0,0);
		commandLabel = new Label(_("Command:"));
		commandLabel.set_alignment(0,0);
		table.attach(commandLabel,0,1,1,2,AttachOptions.EXPAND,AttachOptions.EXPAND,0,0);
		//create and add the critical text box
		criticalCommand = new Entry();
		table.attach(criticalCommand,1,2,1,2,AttachOptions.FILL,AttachOptions.FILL,0,0);
		/* add some OK/Cancel buttons */
		HButtonBox bbox = new HButtonBox();
		bbox.set_layout(ButtonBoxStyle.END);
		//add the bbox to the topVpanel
		topVbox.add(bbox);
		Button OKButton = new Button.from_stock(Gtk.Stock.OK);
		OKButton.clicked.connect( update_app );
		bbox.add(OKButton);
		Button cancelButton = new Button.from_stock(Gtk.Stock.CANCEL);
		cancelButton.clicked.connect( do_destroy );
		bbox.add(cancelButton);
		//set the frames border width
		set_border_width(5);
		show_all();
		destroy.connect( destruct );
	}
	private Frame make_conservation_frame() {
		Frame frame = new Frame(_("Conservation Mode"));
		VBox box = new VBox(false,3);
		box.set_border_width(3);
		frame.add(box);
		var cons = new Conservation();
		Label info = new Label("");
		info.set_alignment(0,(float)0.5);
		info.set_line_wrap(true);
		box.add(info);
		if (!cons.detect()) {
			info.set_text(_("Not supported on this computer"));
			return frame;
		}
		HBox row = new HBox(false,3);
		box.add(row);
		Button onButton = new Button.with_label(_("Turn on"));
		Button offButton = new Button.with_label(_("Turn off"));
		row.pack_start(onButton,false,false,0);
		row.pack_start(offButton,false,false,0);
		Label result = new Label("");
		result.set_alignment(0,(float)0.5);
		box.add(result);
		RefreshFunc refresh = () => {
			int st = cons.status();
			string s = st == 1 ? _("ON (charges to about 80 %)")
				: st == 0 ? _("OFF (charges to 100 %)") : _("unknown");
			info.set_text("%s: %s  [%s]".printf(cons.vendor, s, cons.raw()));
			onButton.set_sensitive(st != 1);
			offButton.set_sensitive(st != 0);
		};
		refresh();
		onButton.clicked.connect(() => {
			result.set_text(cons.set_mode(true) ? "" : _("Could not change it (run vattery as root)"));
			refresh();
		});
		offButton.clicked.connect(() => {
			result.set_text(cons.set_mode(false) ? "" : _("Could not change it (run vattery as root)"));
			refresh();
		});
		return frame;
	}

	public void update_app() {
		//harvest the interface bits and send as a signal
		//get the colors
		Color charging,charged, draining,border,background;
		chargingButton.get_color(out charging);
		chargedButton.get_color(out charged);
		drainingButton.get_color(out draining);
		borderButton.get_color(out border);
		backgroundButton.get_color(out background);
		//textButton.get_color(out text);
		
		//get the percents and commands
		string wp = warningPercent.get_value().to_string();
		string wc = warningCommand.get_text();
		string cp = criticalPercent.get_value().to_string();
		string cc = criticalCommand.get_text();
		
		//what is the textmode value?
		bool text_mode = text_modeButton.get_active();
		//emit the signal
		emit_preferences(charging,charged,draining,border,background,
			wp,wc,cp,cc,text_mode);
		//now destroy the interface
		destroy();
	}

	public void do_destroy() {
		destroy();
	}
	public void destruct() {
		this.gui_destroyed();
	}
	public void set_colors(string charging,string charged,
		string draining, string border, string background) {
		Color color;
		//update the button colors
		Gdk.Color.parse(charging,out color);
		chargingButton.set_color(color);
		Gdk.Color.parse(charged,out color);
		chargedButton.set_color(color);
		Gdk.Color.parse(draining,out color);
		drainingButton.set_color(color);
		Gdk.Color.parse(border,out color);
		borderButton.set_color(color);
		Gdk.Color.parse(background,out color);
		backgroundButton.set_color(color);
		//Gdk.Color.parse(text,out color);
		//textButton.set_color(color);
	}
	public void set_warnings(string wp,string wc,string cp,string cc) {
		warningPercent.set_value( int.parse(wp) );
		criticalPercent.set_value( int.parse(cp) );
		warningCommand.set_text( wc );
		criticalCommand.set_text( cc );
	}
	
	public void set_text_mode(bool mode) {
		text_modeButton.set_active(mode);
	}
	
	public void display()
	{
		show_all();
	}
}

public class IconMenu : Gtk.Menu {
	//what signals do we have?
	public signal void show_preferences();
	public signal void show_about();
	public signal void quit();
	
	public IconMenu() {
		ImageMenuItem menuItem = new Gtk.ImageMenuItem.from_stock(Gtk.Stock.PREFERENCES,null);
		menuItem.activate.connect((source)=>{ show_preferences(); });
		append(menuItem);
		
		menuItem = new Gtk.ImageMenuItem.from_stock(Gtk.Stock.ABOUT,null);
		menuItem.activate.connect((source)=>{show_about(); });
		append(menuItem);
		append(new Gtk.SeparatorMenuItem());
		menuItem = new Gtk.ImageMenuItem.from_stock(Gtk.Stock.QUIT,null);
		menuItem.activate.connect((source)=>{ quit(); });
		append(menuItem);
		//attach(menuItem,0,1,0,1);
		show_all();
	}
}
