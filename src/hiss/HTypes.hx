package hiss;

@:using(hiss.HissTools)
enum HValue {
    // Atoms used to be their own nested enum, but this way is better.
    Int(value: Int);
    Float(value: Float);
    Symbol(name: String);
    
    // Internal type for a string literal that hasn't been interpolated yet
    InterpString(value: String);
    String(value: String);

    Nil;
    T;

    List(l: HList);
    Dict(n: HDict);
    Function(f: HFunction, name: String, ?args: Array<String>);
    Macro(f: HFunction, name: String);
    SpecialForm(f: HFunction, name: String);
    // If you're going to store arbitrary objects in Hiss variables, do yourself a favor and give them a descriptive label because Haxe runtime type info can be squirrely on different platforms
    Object(t: String, v: Dynamic);

    Quote(exp: HValue);

    // Backend-only types. These are used internally but never returned by the interpreter
    Quasiquote(exp: HValue);
    Unquote(exp: HValue);
    UnquoteList(exp: HValue);

    Comment;
}

enum HArgType {
    Fixed;
    Var;
}

typedef Continuation = (HValue) -> Void;

typedef HFunction = (HValue, HValue, Continuation) -> Void;

/*
@:using(HissTools.HissTools)
enum HFunction {
    Haxe(t: HArgType, f: Dynamic, name: String);
    Hiss(f: HFunDef);
    Macro(evalResult: Bool, f: HFunction);
}*/

typedef HDict = Map<String, HValue>;

typedef HFunDef = {
    var argNames: Array<String>;
    var body: HList;
}

enum HSignal {
    Quit;
}

typedef HVarInfo = {
    var name: String;
    var value: HValue;
    var container: Null<HDict>;
}

typedef HList = Array<HValue>;