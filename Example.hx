package;

class Main {
    public static function main() {
        final file = new LuaWrapper('file.lua', false);

        file.set('test', 2);
        file.execute();
    }
}
