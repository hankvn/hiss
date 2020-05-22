package hiss;

using hx.strings.Strings;

using hiss.HissReader;

import hiss.HTypes;

using hiss.HissTools;
using hiss.HaxeTools;

import hiss.HStream.HPosition;

class HissReader {
    static var readTable: Map<String, Dynamic> = new Map();
    static var defaultReadFunction: Dynamic;

    static var macroLengths = [];

    public static function setMacroString(s: HValue, f: Dynamic) {
        var sk = s.toHaxeString();
        readTable.set(sk, f);
        if (macroLengths.indexOf(sk.length) == -1) {
            macroLengths.push(sk.length);
        }
        // Sort macro lengths from longest to shortest so, for example, ,@ and , can both be operators.
        macroLengths.sort(function(a, b) { return b - a; });
        //trace(macroLengths[0]);
        return f;
    }

    public static function setDefaultReadFunction(f: Dynamic) {
        defaultReadFunction = f;
    }

    static function internalSetMacroString(s: String, f: Dynamic) {
        readTable.set(s, f);
        if (macroLengths.indexOf(s.length) == -1) {
            macroLengths.push(s.length);
        }
        macroLengths.sort(function(a, b) { return b - a; });
    }

    public function new() {
        defaultReadFunction = readSymbol;

        // Literals
        internalSetMacroString('"', readString);
        var numberChars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];
        for (s in numberChars) {
            internalSetMacroString(s, readNumber);
        }
        internalSetMacroString("-", readSymbolOrSign);
        internalSetMacroString("+", readSymbolOrSign);
        internalSetMacroString(".", readSymbolOrSign);

        // Lists
        internalSetMacroString("(", readDelimitedList.bind(String(")"), null));

        // Quotes
        for (symbol in ["`", "'", ",", ",@"]) {
            internalSetMacroString(symbol, readQuoteExpression);
        }

        // Ignore comments
        internalSetMacroString("/*", readBlockComment);
        internalSetMacroString("//", readLineComment);
        internalSetMacroString(";", readLineComment);
        
    }
    
    static function toStream(stringOrStream: HValue, ?pos: HValue) {
        var position = if (pos != null) pos.value() else null;

        return switch (stringOrStream) {
            case String(s):
                HStream.FromString(s, position);
            case Object("HStream", v):
                v;
            default:
                throw 'Cannot make an hstream out of $stringOrStream';
        }
    }

    public static function readQuoteExpression(start: HValue, str: HValue, terminators: HValue, position: HValue): HValue {
        var expression = read(str, terminators, position);
        return switch (start.toHaxeString()) {
            case "`":
                Quasiquote(expression);
            case "'":
                Quote(expression);
            case ",":
                Unquote(expression);
            case ",@":
                UnquoteList(expression);
            default:
                throw 'Not a quote expression';
        }
    }

    public static function readNumber(start: HValue, str: HValue, ?terminators: HValue, position: HValue): HValue {
        var stream = toStream(str);
        stream.putBack(start.toHaxeString());

        var token = nextToken(str, terminators);
        return if (token.indexOf('.') != -1) {
            Float(Std.parseFloat(token));
        } else {
            Int(Std.parseInt(token));
        };
    }

    public static function readSymbolOrSign(start: HValue, str: HValue, terminators: HValue, position: HValue): HValue {
        // Hyphen could either be a symbol, or the start of a negative numeral
        return if (toStream(str).nextIsWhitespace() || toStream(str).nextIsOneOf([for (term in terminators.toList()) term.toHaxeString()])) {
            readSymbol(String(""), start, terminators, position);
        } else {
            readNumber(start, str, terminators, position);
        }
    }

    public static function readBlockComment(start: String, str: HValue, _: HValue, position: HValue): HValue {
        var text = toStream(str).takeUntil(["*/"]);

        return Comment;
    }

    public static function readLineComment(start: String, str: HValue, _: HValue, position: HValue): HValue {
        var text = toStream(str).takeLine();

        return Comment;
    }

    public static function readString(start: String, str: HValue, _: HValue, position: HValue): HValue {
        //trace(str);
        switch (toStream(str).takeUntil(['"'])) {
            case Some(s): 
                var escaped = s.output;

                // Via https://haxe.org/manual/std-String-literals.html, missing ASCII and Unicode code point support:
                escaped = escaped.replaceAll("\\t", "\t");
                escaped = escaped.replaceAll("\\n", "\n");
                escaped = escaped.replaceAll("\\r", "\r");
                escaped = escaped.replaceAll('\\"', '"');
                // Single quotes are not a thing in Hiss

                return String(escaped);
            case None:
                throw 'Expected close quote for read-string of $str';
        }
    }

    static function nextToken(str: HValue, ?terminators: HValue): String {
        var whitespaceOrTerminator = HStream.WHITESPACE.copy();
        if (terminators != null) {
            for (terminator in terminators.toList()) {
                whitespaceOrTerminator.push(terminator.toHaxeString());
            }
        }

        return HaxeTools.extract(toStream(str).takeUntil(whitespaceOrTerminator, true, false), Some(s) => s, "next token").output;
    }

    public static function readSymbol(start: HValue, str: HValue, terminators: HValue, position: HValue): HValue {
        var symbolName = nextToken(str, terminators);
        // We mustn't return Symbol(nil) because it creates a logical edge case
        if (symbolName == "nil") return Nil;
        if (symbolName == "t") return T;
        return Symbol(symbolName);
    }

    public static function readDelimitedList(terminator: HValue, ?delimiters: HValue, start: HValue, str: HValue, terminators: HValue, position: HValue): HValue {
        var stream = toStream(str, position);
        /*trace('t: ${terminator.toHaxeString()}');
        trace('s: $start');
        trace('str: ${toStream(str).peekAll()}');
        */

        var delims = [];
        if (delimiters == null || delimiters.match(Nil)) {
            delims = HStream.WHITESPACE.copy();
        } else {
            delims = [for (s in delimiters.toList()) s.toHaxeString()];
        }

        var delimsOrTerminator = [for (delim in delims) String(delim)];
        delimsOrTerminator.push(terminator);
        delimsOrTerminator.push(String("//"));
        delimsOrTerminator.push(String("/*"));


        var term = terminator.toHaxeString();

        var values = [];

        stream.dropWhile(delims);
        //trace(stream.length());
        while (stream.length() >= terminator.toHaxeString().length && stream.peek(term.length) != term) {
            values.push(read(Object("HStream", stream), /*terminator*/ List(delimsOrTerminator)));
            //trace(values);
            stream.dropWhile(delims);
            //trace(stream.peekAll());
            //trace(stream.length());
        }

        //trace('made it');
        stream.drop(terminator.toHaxeString());
        return List(values);
    }

    static function callReadFunction(func: Dynamic, start: String, stream: HStream, terminators: HValue): HValue {
        var pos = stream.position();
        try {
            return func(String(start), Object("HStream", stream), terminators, Object("HPosition", pos));
        } 
        #if !throwErrors
        catch (s: Dynamic) {
            if (s.indexOf("Reader error") == 0) throw s;
            throw 'Reader error `$s` at ${pos.toString()}';
        }
        #end
    }

    public static function read(str: HValue, ?terminators: HValue, ?pos: HValue): HValue {
        var stream: HStream = toStream(str, pos);
        stream.dropWhitespace();

        if (terminators == null || terminators == Nil) {
            terminators = List([String(")"), String('/*'), String('//')]);
        }

        for (length in macroLengths) {
            if (stream.length() < length) continue;
            var couldBeAMacro = stream.peek(length);
            if (readTable.exists(couldBeAMacro)) {
                stream.drop(couldBeAMacro);
                var pos = stream.position();
                var expression = null;
                //trace('read called');
                
                expression = callReadFunction(readTable[couldBeAMacro], couldBeAMacro, stream, terminators);

                // If the expression is a comment, try to read the next one
                return switch (expression) {
                    case Comment:
                        return if (stream.isEmpty()) {
                            Nil; // This is awkward but better than always erroring when the last expression is a comment
                        } else {
                            read(Object("HStream", stream), terminators); 
                        }
                    default: 
                        expression;
                }
            }
        }

        // Call default read function
        return callReadFunction(defaultReadFunction, "", stream, terminators);
    }

    public static function readAll(str: HValue, ?dropWhitespace: HValue, ?terminators: HValue, ?pos: HValue): HValue {
        var stream: HStream = toStream(str, pos);

        if (dropWhitespace == null) dropWhitespace = T;

        var exprs = [];
        while (!stream.isEmpty()) {
            exprs.push(read(Object("HStream", stream), terminators, pos));
            if (dropWhitespace != Nil) {
                stream.dropWhitespace();
            }
        }
        return List(exprs);
    }
}