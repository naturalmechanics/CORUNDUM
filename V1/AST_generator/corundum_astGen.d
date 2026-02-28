import std.stdio;
import cli.colors;
import std.string;
import std.conv;
import std.algorithm;
import std.ascii;


enum AST_STATEMACHINE_MODE {
    NULL, 
    WAITING_FOR_GLOBAL_STYLE_COMMAND,                                           // waiting for the ! include style command                        
    READING_STYLE_INCLUDE_COMMAND,                                              // read the ! include style command at te top of the file
    READING_TEXT_BLIND,                                                         // reading normal text, ignoring all style indications, because no global style command
    READING_TEXT_DEFAULT,                                                       // reading text normally
    READING_STYLE_APPLICATION_COMMAND,                                          // reading the [STYLEcommand] in an inline styling
    READING_STYLE_APPLICATION_TAG,                                              // reading just STYLEcommand inside the [STYLEcommand]
    READING_STYLED_TEXT_FLOW                                                    // reading the text between openning || [abb] and closing ||
}


enum NodeType {
    NULL, 
    BASIC_TEXT, 
    STYLED_TEXT_SCOPE, 
    STYLED_TEXT_FLOW
}




/* ============================================================================ */
enum TOKEN_GLOBAL_STYLEFILE_INCLUDE_COMMAND = '!' ;                             // Token to designate the discovery of the global 
                                                                                // include command. Must be the first non-whitespace
                                                                                // character of the file.
/* ---------------------------------------------------------------------------- */
enum TOKEN_GLOBAL_STYLEFILE_INCLUDE_COMMAND_OPERATOR_SEPARATOR = ' ' ;          // ### TODO in next version, support tab as well
/* ---------------------------------------------------------------------------- */
static immutable GLOBAL_STYLEFILE_INCLUDE_COMMAND_BEGIN_SKIPCHARS = [' ', '\t', '\r', '\n'];  // white space characters allowed until
                                                                                // the ! include xxxx command is found
/* ---------------------------------------------------------------------------- */
static immutable GLOBAL_STYLEFILE_INCLUDE_COMMAND_BODY_SKIPCHARS = [' ', '\t']; // allowed whitespace characters between 
                                                                                // `INCLUDE` and `STYLEFILE`
/* ---------------------------------------------------------------------------- */
static immutable GLOBAL_STYLEFILE_INCLUDE_COMMAND_BODY_TERMINATIONCHARS = ['\n', '\r']; // Termination characters after ! Include Stylefile
/* ============================================================================ */





/* ============================================================================ */
enum TOKEN_STYLE_APPLICATION_START  = '|';                                      // Token that designates a potential appearence of
                                                                                // "Start Application of Style here" command
/* ---------------------------------------------------------------------------- */
enum TOKEN_STYLE_APPLICATION_START_CONFIRM = '|';                               // Token that confirms the existence of 
                                                                                // "Start Application of Style here" command
/* ---------------------------------------------------------------------------- */
enum TOKEN_STYLE_APPLICATION_START_FULL = "||";                                 // this is what lookahead should discover where 
                                                                                // style needs to apply
/* ---------------------------------------------------------------------------- */
enum TOKEN_STYLE_APPLICATION_STOP = '|';
enum TOKEN_STYLE_APPLICATION_STOP_CONFIRM = '|';
enum TOKEN_STYLE_APPLICATION_STOP_FULL = "||";



/* ============================================================================ */




enum TOKEN_STYLE_APPLICATION_TAG_START = '[' ;
enum TOKEN_STYLE_APPLICATION_TAG_TREMINATION = ']' ;


static immutable STYLE_APPLICATION_COMMAND_BEGIN_SKIPCHARS = [' ', '\t', '\r', '\n'];
static immutable STYLE_APPLICATION_COMMAND_AFTER_OPENNING_SKIPCHARS = [' ', '\t'];
static immutable STYLE_APPLICATION_COMMAND_AFTER_OPENNING_DISALLOWEDCHARS = ['\r', '\n'];






/** ------- General AST-GENERATOR stack ------- **/
bool styleFound;                                                                // Global Flag
string styleFile;
bool mustCreateNewNode;
bool mustCreateChildNode;

int nodeIDCounter;                                                              // Not specified in the specs

/** ------- Specialized parsing state stack ------- **/
int WAIT_FOR_STYLE;
int SKIP_LOOP_FOR_ITERS = 0;

NODE * currNodePTR;
NODE * rootNodePTR;

struct NODE {
    int id;
    int flag;

    NodeType nodeType;

    string content;
    string [] styleStack;

    int STYLE_NESTING_DEPTH;

    NODE*[]children;
    NODE * parent;
    NODE * prevSibling;
    NODE * nextSibling;

}

struct RES {

    int id;
    int [] flags;

    int errorCode;



}

string inp;
int errorCode;


int main(string[] args) {

    if(args.length < 2) {                                                       std.stdio.writeln(orange, 
                                                        "[ERROR] - There is no source code supplied", reset);
        return 1;
    }

    
    errorCode = 0;

    size_t l = args[1].length;
    inp = args[1];

    AST_STATEMACHINE_MODE mMode = AST_STATEMACHINE_MODE.WAITING_FOR_GLOBAL_STYLE_COMMAND;
    styleFound = false;
    styleFile  = "";
    mustCreateNewNode = true;
    mustCreateChildNode = false;

    nodeIDCounter = 0;
    currNodePTR   = null;
    rootNodePTR   = null;
    
    RES result;

    string potentialStyleIncludeCommand = "";

    for (size_t i = 0; i < l; i++) {

        char currChar = inp[i];
        if (SKIP_LOOP_FOR_ITERS != 0) {
            --SKIP_LOOP_FOR_ITERS;
            continue;
        }

        switch (mMode) {
            case AST_STATEMACHINE_MODE.WAITING_FOR_GLOBAL_STYLE_COMMAND : 
                result = step_until_style_found_ASTGEN(mMode, currChar);
                break;                                                          // Break the switch case
            case AST_STATEMACHINE_MODE.READING_STYLE_INCLUDE_COMMAND :
                result = step_until_full_style_include_command_is_read_ASTGEN(mMode, currChar, 
                                                                                potentialStyleIncludeCommand);
                break;
            case AST_STATEMACHINE_MODE.READING_TEXT_DEFAULT :                   // this is where the machine begins
                                                                                // but can be hit and miss
                result = step_expecting_styleCommand_but_read_textflow_ASTGEN(mMode, currChar, i); // deal with hitting the style
                                                                                // in the function, because 
                                                                                // you might encounter a stlye trigger in the 
                                                                                // normal function run
                break;
            case AST_STATEMACHINE_MODE.READING_STYLE_APPLICATION_COMMAND :      // this happens when we are looking for [xxxxx]
                result = step_expecting_styleTag_openning_ASTGEN(mMode, currChar); // 
                break;
            case AST_STATEMACHINE_MODE.READING_STYLE_APPLICATION_TAG :          // this happens when we are looking for just the xxxxx
                                                                                // after we have found the [xxxxx]
                result = step_expecting_styleTag_including_closing_ASTGEN(mMode, currChar); // 
                break;
            case AST_STATEMACHINE_MODE.READING_STYLED_TEXT_FLOW :
                result = step_until_styled_text_flow_ends_ASTGEN(mMode, currChar, i);
                break;
            default:
                break;
        }
        

        if (result.errorCode != 0) break;                                       // break the for loop

    }

    

    {                                                                           // debug scope;
        NODE * cn = rootNodePTR;                            writeln(skyBlue, " [DEBUG] - rootNode is: ", 
                                                            rootNodePTR, "; current node is: ", cn, reset); 
        while (true) {

            if((cn.STYLE_NESTING_DEPTH >=0) && (cn.nodeType == NodeType.STYLED_TEXT_FLOW)) {
                for(int j = 0; j <= cn.STYLE_NESTING_DEPTH; j++)
                    write("\t");
            }    
            write(green, "- ");            write(cn.nodeType.to!string());  

                if(cn.content) {
                    write(" (> ##");
                    write(cn.content);
                    write("## <)");
                }

            writeln(reset);
            


            if (cn.children.length != 0) cn = cn.children[0];
            else if (! (cn.nextSibling is null)) cn = cn.nextSibling;
            else {
                bool foundUncle = false;
                while(! (cn.parent is null)) {
                    cn = cn.parent;
                    if (! (cn.nextSibling is null) ) {
                        cn = cn.nextSibling;
                        foundUncle = true;
                        break;
                    }
                }
                if (!foundUncle) break;
            }
            
        }
    }

    

    return errorCode;
}



RES step_until_style_found_ASTGEN(ref AST_STATEMACHINE_MODE ASTGEN_MODE, char c) {
                                                                                // at this point, expecting 
                                                                                // an ! include stylefile command
    

    RES result = RES();
    result.errorCode = 0;                                                       // empty result, no error

    if (GLOBAL_STYLEFILE_INCLUDE_COMMAND_BEGIN_SKIPCHARS.canFind(c)) return result; // return empty result, no error
                                                                                // the caller is a loop, 
                                                                                // and the loop ensures, that 
                                                                                // on a single iteration, there is a
                                                                                // single function call, and then
                                                                                // error check.
                                                                                // thereby, it is sufficient to 
                                                                                // return the error result
                                                                                // this return ensure, that
                                                                                // on whitespace, other conditions won't 
                                                                                // be checked.

    if (c == TOKEN_GLOBAL_STYLEFILE_INCLUDE_COMMAND) 
        ASTGEN_MODE = AST_STATEMACHINE_MODE.READING_STYLE_INCLUDE_COMMAND;      // '!' found => read the style file command
    else ASTGEN_MODE = AST_STATEMACHINE_MODE.READING_TEXT_BLIND;                // no '!' found => read the text blindly


    return result;
}

RES step_until_full_style_include_command_is_read_ASTGEN(ref AST_STATEMACHINE_MODE ASTGEN_MODE, 
                                                    char c, ref string potentialStyleIncludeCommand) {

    RES result = RES();
    result.errorCode = 0;                                                       // empty result, no error

    // if (GLOBAL_STYLEFILE_INCLUDE_COMMAND_BODY_SKIPCHARS.canFind(c)) return result;     // chars that can be skipped until the "include" command is found
                                                                                // !! IMPORTANT ... do not skip chars 
                                                                                // skip chars also affects internal occurences of the chars,
                                                                                // not just at the beginning

    if (GLOBAL_STYLEFILE_INCLUDE_COMMAND_BODY_TERMINATIONCHARS.canFind(c)) {    // potential "include stylefile" command is terminated
                                                                                std.stdio.writeln(cyan, 
                                                        "[INFO] - Full global style include command is: >",
                                                        potentialStyleIncludeCommand, "<", reset);
        

        potentialStyleIncludeCommand = potentialStyleIncludeCommand.strip();
        ptrdiff_t index = potentialStyleIncludeCommand.indexOf(
                            TOKEN_GLOBAL_STYLEFILE_INCLUDE_COMMAND_OPERATOR_SEPARATOR);

        if(index == -1) {                                                       std.stdio.writeln(orange,
                                                        "[ERROR] - First Command must start with ! INCLUDE FileName. " ~
                                                        "Found Instead: " ~ potentialStyleIncludeCommand , reset);
            result.errorCode = 11;
            return result;                                                      // Error found. returning immediately

        }

        string left  = potentialStyleIncludeCommand[0 .. index];
        string right = potentialStyleIncludeCommand[index + 1 .. $].stripLeft(); // stripLeft removes extra spaces
                    
        if (left.strip().toUpper() != "INCLUDE"){                               std.stdio.writeln(orange,
                                                        "[ERROR] - First Command must start with ! INCLUDE FileName. " ~
                                                        "`INCLUDE` seems to be missing." , reset);
            result.errorCode = 12;
            return result;

        }

        styleFile = right.strip();                                              std.stdio.writeln(cyan,
                                                        "[INFO] - Found Style File: ", styleFile, reset );




        ASTGEN_MODE = AST_STATEMACHINE_MODE.READING_TEXT_DEFAULT;
    }

    potentialStyleIncludeCommand ~= c;

    return result;



}

RES step_expecting_styleCommand_but_read_textflow_ASTGEN(ref AST_STATEMACHINE_MODE ASTGEN_MODE, char c, size_t i) {

    RES result = RES();
    result.errorCode = 0;  

    if (c == TOKEN_STYLE_APPLICATION_START ) {                                  // we are reading text flow but found style start token
        
        string lookahead = look_ahead_in_input(i, 2);

        if (lookahead == TOKEN_STYLE_APPLICATION_START_FULL) {                  // std.stdio.writeln(lookahead);
            auto N = create_new_style_scope_node();                             // Regardless of mustcreatnode, this yu must create a node
            
            mustCreateNewNode = false;
                                                        writeln(skyBlue, " [DEBUG] - CurrNodePTR is null? ", 
                                                            (currNodePTR is null), reset );

            link_to_tree(N);

            if ( ! (N.parent is null) ) N.STYLE_NESTING_DEPTH = N.parent.STYLE_NESTING_DEPTH + 1;
            else N.STYLE_NESTING_DEPTH = 0;

            currNodePTR = N;                            writeln(skyBlue, " [DEBUG] - rootNodePTR is null? ", 
                                                            (rootNodePTR is null), reset ); 
            if (rootNodePTR is null) rootNodePTR = currNodePTR;     writeln(skyBlue, " [DEBUG] - rootNode is: ", 
                                                            rootNodePTR, reset); 
                                                        writeln(skyBlue, " [DEBUG] - rootNode sibling is: ", 
                                                            rootNodePTR.nextSibling, reset); 

            ASTGEN_MODE = AST_STATEMACHINE_MODE.READING_STYLE_APPLICATION_COMMAND;

            SKIP_LOOP_FOR_ITERS = 1;
            //create_new_style_flow_node();
        } else {
            result.errorCode = 31;                                              std.stdio.writeln(orange,
                                                        "[ERROR] - We have found `|` standalone. " ~
                                                        "This is not allowed. Use instead: \\pipe " , reset);
        }

        
        
    } else {

        
        if (mustCreateNewNode) {
            auto N = create_new_text_flow_node();                               // new node created
            mustCreateNewNode = false;                                          
                                                        writeln(skyBlue, " [DEBUG] - CurrNodePTR is null? ", 
                                                            (currNodePTR is null) , reset );

            link_to_tree(N);

            currNodePTR = N;                            writeln(skyBlue, " [DEBUG] - rootNodePTR is null? ", 
                                                            (rootNodePTR is null), reset ); 
            if (rootNodePTR is null) rootNodePTR = currNodePTR;   writeln(skyBlue, " [DEBUG] - rootNode is: ", 
                                                            rootNodePTR, reset); 
                                                        writeln(skyBlue, " [DEBUG] - rootNode sibling is: ", 
                                                            rootNodePTR.nextSibling, reset); 
        }   
            currNodePTR.content ~= c;                                           // in any case, feed the content in the node
    }
    

    return result;
    

}

RES step_expecting_styleTag_openning_ASTGEN(ref AST_STATEMACHINE_MODE ASTGEN_MODE, char c) {
                                                                                // at this point, expecting 
                                                                                // an ! include stylefile command
    

    RES result = RES();
    result.errorCode = 0;                                                       // empty result, no error

    if (STYLE_APPLICATION_COMMAND_BEGIN_SKIPCHARS.canFind(c)) return result;    // return empty result, no error
                                                                                // the caller is a loop, 
                                                                                // and the loop ensures, that 
                                                                                // on a single iteration, there is a
                                                                                // single function call, and then
                                                                                // error check.
                                                                                // thereby, it is sufficient to 
                                                                                // return the error result
                                                                                // this return ensure, that
                                                                                // on whitespace, other conditions won't 
                                                                                // be checked.

    if (c == TOKEN_STYLE_APPLICATION_TAG_START) 
        ASTGEN_MODE = AST_STATEMACHINE_MODE.READING_STYLE_APPLICATION_TAG;      // '!' found => read the style file command
    // else ASTGEN_MODE = AST_STATEMACHINE_MODE.READING_STYLE_APPLICATION_COMMAND; // no '!' found => read the text blindly
                                                                                // ^--- This is not needed !


    return result;
}

RES step_expecting_styleTag_including_closing_ASTGEN(ref AST_STATEMACHINE_MODE ASTGEN_MODE, char c) {
                                                                                // at this point, expecting 
                                                                                // an ! include stylefile command
    

    RES result = RES();
    result.errorCode = 0;                                                       // empty result, no error

    if (STYLE_APPLICATION_COMMAND_AFTER_OPENNING_SKIPCHARS.canFind(c)) return result;   // return empty result, no error
                                                                                // the caller is a loop, 
                                                                                // and the loop ensures, that 
                                                                                // on a single iteration, there is a
                                                                                // single function call, and then
                                                                                // error check.
                                                                                // thereby, it is sufficient to 
                                                                                // return the error result
                                                                                // this return ensure, that
                                                                                // on whitespace, other conditions won't 
                                                                                // be checked.
    if (STYLE_APPLICATION_COMMAND_AFTER_OPENNING_DISALLOWEDCHARS.canFind(c)) {
        result.errorCode = 41;                                                  std.stdio.writeln(orange,
                                                        "[ERROR] - Line break is not allowed inside " ~
                                                        "a style application command. " ~
                                                        "Statements like [\\n TAG] is illegal." , reset);
        return result;
    }

    if (c == TOKEN_STYLE_APPLICATION_TAG_TREMINATION) {                         // disallowedchars are chars that
                                                                                // are not allowed any where within the [xxxxxx] tag
                                                                                // but, a space can be allowed at the 
                                                                                // beginning and the ned, e.g. [ xxxxxx   ]
                                                                                // so we don't include space and tab within
                                                                                // the disallowedchars list!!
                                                                                // BUT we do not allow space within the tag 
                                                                                // e.g. [xxxx yyyy] is not allowed. 
                                                                                // so we check for whitespace within the 
                                                                                // tag itself.
                                                                                //-----------------------//
                                                                                // later on, when we do [aa,bb]
                                                                                // we can change this part ... 
                                                                                // break along the comma, and then strip each item
                                                                                // from leading and trailing whitespace
                                                                                // and then for each item, check that there is
                                                                                // no whitespace in between.

        if (currNodePTR.styleStack.length > 0) {
            auto lastStyle = currNodePTR.styleStack[$-1].strip();   

            if ( lastStyle.any!isWhite) {
                result.errorCode = 43;                                          std.stdio.writeln(orange,
                                                        "[ERROR] - White Space is not allowed inside " ~
                                                        "a style tage name. " ~
                                                        "Statements like [TAG with white space] is illegal." , reset);
                return result;

            }
        }

        auto N = create_new_styled_text_flow_node();

        if (currNodePTR is null) {                                              // PANIC SOMETHIG IS REALLY WRONG
            result.errorCode = 44;                                              std.stdio.writeln(orange,
                                                        "[ERROR] - Your text is leading to the creation of a " ~
                                                        "Styled Text node, before a Style Scope node. " ~
                                                        "How did that even happen? Please don't hack me." , reset);
            return result;
        }

        N.parent = currNodePTR;
        currNodePTR.children ~= N;
        N.STYLE_NESTING_DEPTH = currNodePTR.STYLE_NESTING_DEPTH;
        N.styleStack = currNodePTR.styleStack;
        N.content = "";
        currNodePTR = N;                                                        // So we have created the first child node
                                                                                // and injected nothing into it... 
                                                                                // But control moves to the first child node
                                                                                // the first child node is expected to be a 
                                                                                // styledtext flow, i.e. we are not expecting 
                                                                                // (|| [aaaa] bbbb cccc dddd eeee ||) ... etc
                                                                                // should we encounter those stuff tho
                                                                                // we will immediately close this node,
                                                                                // and create a subordinate style scope node


                                                                                

        ASTGEN_MODE = AST_STATEMACHINE_MODE.READING_STYLED_TEXT_FLOW;
        return result;
    }

    if (c == EOF) {
         result.errorCode = 42;                                                  std.stdio.writeln(orange,
                                                        "[ERROR] - End-of-File arrived before style tag completion " ~
                                                        "- this is not realistic. " , reset);
        return result;
    }

    
    if (currNodePTR.styleStack.length == 0) {
        currNodePTR.styleStack ~="";
        currNodePTR.styleStack[$-1] ~= c;
    } else currNodePTR.styleStack[$-1] ~= c;

    return result;

}

RES step_until_styled_text_flow_ends_ASTGEN(ref AST_STATEMACHINE_MODE ASTGEN_MODE, char c, size_t i) {
    RES result = RES();
    result.errorCode = 0;  

    if (c == TOKEN_STYLE_APPLICATION_STOP ) {                                   // we are reading text flow but found style start token
        
        string lookahead = look_ahead_in_input(i, 2);

        if (lookahead == TOKEN_STYLE_APPLICATION_STOP_FULL) {                   // std.stdio.writeln(lookahead);
            
            ASTGEN_MODE = AST_STATEMACHINE_MODE.READING_TEXT_DEFAULT;
            mustCreateNewNode = true;
            if (! (currNodePTR.parent is null)) currNodePTR = currNodePTR.parent;
            else {
                result.errorCode = 45;                                              std.stdio.writeln(orange,
                                                        "[ERROR] - we are closing a Styled Text Node, " ~
                                                        "which must have a Style Scope node as a parent. " ~
                                                        "But the parent is missing!! " ~
                                                        "How did that even happen? Please don't hack me." , reset);
            }

            SKIP_LOOP_FOR_ITERS = 1;

        } else {
            result.errorCode = 31;                                              std.stdio.writeln(orange,
                                                        "[ERROR] - We have found `|` standalone " ~
                                                        "while expecting a closing. " ~
                                                        "This is not allowed. Use instead: \\pipe " , reset);
        }

        
        
    } else {

        currNodePTR.content ~= c;                                               // in any case, feed the content in the node
    }
    

    return result;
}



NODE * create_new_text_flow_node() {

    NODE * N = new NODE;

    N.nodeType = NodeType.BASIC_TEXT;
    N.content  = [];
    N.STYLE_NESTING_DEPTH = 0;

    return N;

}

NODE * create_new_style_scope_node() {                  writeln(skyBlue, " [DEBUG] - STYLE SCOPE CREATED !!", reset);

    NODE * N = new NODE;

    N.nodeType = NodeType.STYLED_TEXT_SCOPE;
    N.content  = [];
    N.STYLE_NESTING_DEPTH = 0;

    return N;

}

NODE * create_new_styled_text_flow_node() {

    NODE * N = new NODE;

    N.nodeType = NodeType.STYLED_TEXT_FLOW;
    N.content  = [];
    N.STYLE_NESTING_DEPTH = 0;

    return N;

}



string  look_ahead_in_input(size_t i, size_t r) {

    if( (i+r) > inp.length) {
        return "";
    }

    string sub = inp[i .. i + r];

    return sub;

}


void link_to_tree(NODE * N){
    if (! (currNodePTR is null) ) {
        N.prevSibling = currNodePTR;                                    
        currNodePTR.nextSibling = N;
        N.parent = currNodePTR.parent;
    }
}
