package;

import llua.*;
import llua.Lua;

import sys.FileSystem;

using StringTools;

class Lua {
	public var file(default, null):State;
	public var name(default, null):String;
	public var active:Bool = true;

	public function new(_name:String, ?startExecute:Bool = true) {
		this.name = _name;

		this.file = LuaL.newstate();
		LuaL.openlibs(file);

		if (startExecute) execute();
	}

	public function execute() {
		try {
			final isString:Bool = !FileSystem.exists(name);
			var result:Dynamic = null;

			if (!isString) result = LuaL.dofile(file, name);
			else result = LuaL.dostring(file, name);

			var resultStr:String = Lua.tostring(file, result);
			if (resultStr != null && result != 0) {
				trace(resultStr);
				destroy();
				return;
			}

			if (isString) name = 'unknown';
		} catch(e:Dynamic) {
			trace(e);
			return;
		}
	}

	public function set(name:String, value:Dynamic) {
		if (!active) return;

		if (Type.typeof(value) != TFunction) {
			Convert.toLua(file, value);
			Lua.setglobal(file, name);
		} else Lua_helper.add_callback(file, name, value);
	}

	public function call(name:String, ?args:Array<Dynamic>):Dynamic {
		if (!active) return null;

		if (args == null) args = [];

		try {
			Lua.getglobal(file, name);
			var type:Int = Lua.type(file, -1);

			for (i in 0...args.length) Convert.toLua(file, args[i]);
			var status:Int = Lua.pcall(file, args.length, 1, 0);

			if (status != Lua.LUA_OK) {
				var error:String = getErrorMessage(status);
				Sys.println('ERROR ($name): $error');
				return null;
			}

			// If successful, pass and then return the result.
			var result:Dynamic = cast Convert.fromLua(file, -1);

			Lua.pop(file, 1);
			return result;
		} catch (e:Dynamic) {
			trace(e);
			return null;
		}
	}

	public function getErrorMessage(status:Int):String {
		var v:String = Lua.tostring(file, -1);
		Lua.pop(file, 1);

		trace(v);

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
		return null;
	}

	public function destroy() {
		file = null;
		active = false;
		name = null;
	}
}
