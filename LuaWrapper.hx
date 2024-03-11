package;

import llua.Lua.Lua_helper;
import llua.LuaL;
import llua.State;
import llua.Convert;
import llua.Lua;

import Type.ValueType;

using StringTools;

class LuaWrapper {
	public var file(default, null):State;
	public var name(default, null):String;
	public var active:Bool = true;

	public var executed(default, null):Bool = false;

	public function new(_name:String, ?startExecute:Bool = true) {
		this.file = LuaL.newstate();
		LuaL.openlibs(this.file);
		Lua.init_callbacks(this.file);

		this.name = _name.trim();

		if (startExecute) execute();
	}

	public function execute() {
		try {
			executed = true;
			
			var isString:Bool = !sys.FileSystem.exists(name);
			var result:Dynamic = null;

			if (!isString) result = LuaL.dofile(file, name);
			else result = LuaL.dostring(file, name);

			var resultStr:String = Lua.tostring(file, result);
			if (resultStr != null && result != 0) {
				Sys.println('ERROR: $resultStr');
				destroy();
				return;
			}

			if (isString) name = 'unknown';
		} catch(e:Dynamic) trace(e);
	}

	public function set(_name:String, value:Dynamic) {
		if (!active || this.file == null) return;

		if (Type.typeof(value) != TFunction) {
			Convert.toLua(file, value);
			Lua.setglobal(file, _name);
		} else Lua_helper.add_callback(file, _name, value);
	}

	public function call(_name:String, ?args:Array<Dynamic>):Dynamic {
		if (!active || file == null) return null;

		args ??= [];

		if (!executed) execute();

		try {
			Lua.getglobal(file, _name);
			var type:Int = Lua.type(file, -1);

			if (type != Lua.LUA_TFUNCTION) {
				if (type > Lua.LUA_TNIL)
					Sys.println('ERROR ($_name): attempt to call a $type value');

				Lua.pop(file, 1);
				return null;
			}

			for (arg in args) Convert.toLua(file, arg);
			var status:Int = Lua.pcall(file, args.length, 1, 0);

			// Checks if it's not successful, then show a error.
			if (status != Lua.LUA_OK) {
				var error:String = getErrorMessage(status);
				Sys.println('ERROR ($_name): $error');
				return null;
			}

			// If successful, pass and then return the result.
			var result:Dynamic = cast Convert.fromLua(file, -1);

			Lua.pop(file, 1);
			if (!active) destroy();
			return result;
		}
		catch (e:Dynamic) trace(e);

		return null;
	}

	public function getErrorMessage(status:Int):String {
		if (!active) return null;

		var v:String = Lua.tostring(file, -1);
		Lua.pop(file, 1);

		if (v != null) v = v.trim();
		if (v == null || v == "") {
			switch (status) {
				case Lua.LUA_ERRRUN: return "Runtime Error";
				case Lua.LUA_ERRMEM: return "Memory Allocation Error";
				case Lua.LUA_ERRERR: return "Critical Error";
			}
			return "Unknown Error";
		}

		return v;
	}

	public function destroy() {
		Lua.close(this.file);
		this.file = null;
		name = null;
	}
}
