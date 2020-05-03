package hiss;

import hiss.HissReader;
import hiss.HissInterp;
import hiss.HTypes;

using hiss.HissTools;

/**
    A HissRunner reads and executes Hiss code with the fine-grained control of an interactive debugger.
    It can step through, evaluate expressions, supports goto and other structures a simple `progn` can't.

    Due to the current implementation of HissReader and HissInterp where many functions and variables are static, more than one simultaneous HissRunner will without a doubt have side effects on other instances.
**/
class HissRunner {
    var interp: HissInterp;
    var reader: HissReader;

    /** A Hiss list of HValues representing unevaluated expressions in the program being run. May be modified at runtime, i.e. by a (load) call. **/
    var program: HValue;
    
    // TODO this HissRunner will also need to keep a structure of every intermediate expression that hasn't been evaluated yet! i.e. in (concat "Hey" "you" "rock") all of the strings will need to be stored until the funcall completes. 
    
    /** A Hiss int representing the index of the next expression to evaluate. These do not correspond to "statements" in a traditional programming language sense. Here are some examples of program counter indexing:

        "Hello world"
        0
        -------------
        ( print "Hello world")
        0 1     2
        -------------
        '( print "Hello world")
        0
        -------------
        ( setq str "Hello world")
        0 1    2   3
        `(print ,str)
        4       5
    **/
    var programCounter: HValue;

    public function new() {

    }
}