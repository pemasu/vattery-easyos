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
using GLib;

public errordomain ConfigError
{
	CREATE_DIR_FAILED,
	FILE_NOT_FOUND,
	DOCUMENT_EMPTY,
	READ_FAILED,
	WRITE_FAILED,
	NO_KEY_VALUE
}

// a configuration is a hash table of keys and values stored in a file
public class Configuration
{
	private KeyFile keyfile;
	private string config_file;
	private bool config_changed;
	public Configuration( string config_file_path ) {
		//define some defaults
		config_changed = false;
		this.config_file = config_file_path;
	//create the keyfile
	keyfile = new KeyFile();
		try {
			this.read_config();
		} catch(ConfigError error) {
			stdout.printf("%s\n",error.message);
		}
	}
	~Configuration() {
		//if the config has changed, save the config
		if(config_changed) {
			this.save_config();
		}
	}
	public void save_config() throws ConfigError {
		//get the text of the keyfile as a string
	string config_text = keyfile.to_data();
		//create a string to represent the entire config file
		try {
			//stdout.printf("write %s\nto%s\n",config_text,config_file);
			FileUtils.set_contents(this.config_file,config_text);
			config_changed=false;
		} catch(FileError err) {
			throw new ConfigError.WRITE_FAILED(err.message);
		}
	}

	public void read_config() throws ConfigError {
	string dirpath = Path.get_dirname(config_file);
		//if the dirpath doesn't exist, make it
		if(!FileUtils.test(dirpath,FileTest.EXISTS) ) {
			//making the dir will return -1 if it fails
			if(DirUtils.create_with_parents(dirpath,0744)==-1) {
				throw new ConfigError.CREATE_DIR_FAILED ( "failed to make "+dirpath);
			}
		}

		//if the config file doesn't exist
		if(!FileUtils.test(config_file, FileTest.EXISTS) ) {
			//try to make the file
			try {
				FileUtils.set_contents(this.config_file,"");
			} catch(FileError err) {
				throw new ConfigError.WRITE_FAILED(err.message);
			}
		}

		//try to read the file
		try {
			keyfile.load_from_file(config_file,KeyFileFlags.NONE);
		} catch(Error err) {
			throw new ConfigError.READ_FAILED("can not read %s: %s",config_file,err.message);
		}
	}
	
	public void set_key_value(string group, string key, string val) {
		keyfile.set_string(group,key,val);
		config_changed = true;
	}
	
	public string get_value(string group, string key) {
		string val;
		try {
			val = keyfile.get_string(group,key);
		} catch(KeyFileError err) {
			val = null;
		}
		return val;
	}
	
	public bool get_boolean_value(string group, string key)
	{
		string val;
		try {
			val = keyfile.get_string(group,key);
		} catch(KeyFileError err) {
			val = null;
		}
		if (val!=null && val!="false" ) {
			return true;
		}else{
			return false;
		}
	}
}
