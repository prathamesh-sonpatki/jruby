package org.jruby.lexer;

import beaver.Symbol;
import beaver.Scanner;
import org.jruby.parser.JavaSignatureBeaverParser;
import org.jruby.parser.JavaSignatureBeaverParser.Terminals;

%%

%public
%class JavaSignatureBeaverLexer
%extends Scanner
%function nextToken
%type Symbol
%yylexthrow Scanner.Exception
%eofval {
          return new Symbol(Terminals.EOF, "end-of-file");
%eofval }
%standalone
%unicode
%line
%column
%{
  boolean stringResult = false;
  boolean characterResult = false;
  StringBuilder stringBuf = new StringBuilder();

  public Object value() {
    if (stringResult) {
        stringResult = false;
        String value = stringBuf.toString();
        stringBuf.setLength(0);
        return value;
    } else if (characterResult) {
        characterResult = false;
        String value = stringBuf.toString();
        if (stringBuf.length() != 1) throw new Error("Character not on char ("+ value +")");
        stringBuf.setLength(0);
        return value;
    }
    return yytext();
  }

  public static JavaSignatureBeaverLexer create(java.io.InputStream stream) {
    return new JavaSignatureBeaverLexer(stream);
  }

  private Symbol newToken(short id)
  {
    return new Symbol(id, yyline + 1, yycolumn + 1, yylength());
  }

  private Symbol newToken(short id, Object value)
  {
    return new Symbol(id, yyline + 1, yycolumn + 1, yylength(), value);
  }

%}

LineTerminator = \r|\n|\r\n
WhiteSpace     = {LineTerminator} | [ \t\f]
Identifier     = [:jletter:] [:jletterdigit:]*
//Digit          = [0-9]
//HexDigit       = {Digit} | [a-f] | [A-F]
//UnicodeEscape  = "\\u" {HexDigit} {HexDigit} {HexDigit} {HexDigit}
//EscapedChar    = "\\" [nybrf\\'\"]
//NonEscapedChar = [^nybrf\\'\"]
//CharacterLiteral = "'" ({NonEscapedChar} | {EscapedChar} | {UnicodeEscape}) "'"
//StringLiteral  = "\"" ({NonEscapedChar} | {EscapedChar} | {UnicodeEscape})* "\""

%state CHARACTER
%state STRING

%%

<YYINITIAL> {
    // primitive types
    "boolean"       { return newToken(Terminals.BOOLEAN);      }
    "byte"          { return return newToken(Terminals.BYTE);         }
    "short"         { return return newToken(Terminals.SHORT);        }
    "int"           { return return newToken(Terminals.INT);          }
    "long"          { return return newToken(Terminals.LONG);         }
    "char"          { return return newToken(Terminals.CHAR);         }
    "float"         { return return newToken(Terminals.FLOAT);        }
    "double"        { return return newToken(Terminals.DOUBLE);       }
    "void"          { return return newToken(Terminals.VOID);         }

    // modifiers
    "public"        { return JavaSignatureBeaverParser.PUBLIC;       }
    "protected"     { return JavaSignatureBeaverParser.PROTECTED;    }
    "private"       { return JavaSignatureParser.PRIVATE;      }
    "static"        { return JavaSignatureParser.STATIC;       }
    "abstract"      { return JavaSignatureParser.ABSTRACT;     }
    "final"         { return JavaSignatureParser.FINAL;        }
    "native"        { return JavaSignatureParser.NATIVE;       }
    "synchronized"  { return JavaSignatureParser.SYNCHRONIZED; }
    "transient"     { return JavaSignatureParser.TRANSIENT;    }
    "volatile"      { return JavaSignatureParser.VOLATILE;     }
    "strictfp"      { return JavaSignatureParser.STRICTFP;     }

    "@"             { return JavaSignatureParser.AT;           }
    "&"             { return JavaSignatureParser.AND;          }
    "."             { return JavaSignatureParser.DOT;          }
    ","             { return JavaSignatureParser.COMMA;        }
    "\u2026"        { return JavaSignatureParser.ELLIPSIS;     }
    "..."           { return JavaSignatureParser.ELLIPSIS;     }
    "="             { return JavaSignatureParser.EQUAL;        }
    "{"             { return JavaSignatureParser.LCURLY;       }
    "}"             { return JavaSignatureParser.RCURLY;       }
    "("             { return JavaSignatureParser.LPAREN;       }
    ")"             { return JavaSignatureParser.RPAREN;       }
    "["             { return JavaSignatureParser.LBRACK;       }
    "]"             { return JavaSignatureParser.RBRACK;       }
    "?"             { return JavaSignatureParser.QUESTION;     }
    "<"             { return JavaSignatureParser.LT;           }
    ">"             { return JavaSignatureParser.GT;           }
    "throws"        { return JavaSignatureParser.THROWS;       }
    "extends"       { return JavaSignatureParser.EXTENDS;      }
    "super"         { return JavaSignatureParser.SUPER;        }
    ">>"            { return JavaSignatureParser.RSHIFT;       }
    ">>>"           { return JavaSignatureParser.URSHIFT;      }

    {Identifier}    { return JavaSignatureParser.IDENTIFIER;   }
    \"              { yybegin(STRING); } 
    \'              { yybegin(CHARACTER); } 
    {WhiteSpace}    { }
}

<CHARACTER> {
    \' { characterResult = true;
         yybegin(YYINITIAL);
         return JavaSignatureParser.CHARACTER_LITERAL; 
       }
    .  { stringBuf.append(yytext()); }
}

<STRING> {
  \"                {
                     stringResult = true;
                     yybegin(YYINITIAL); 
                     return JavaSignatureParser.STRING_LITERAL;
  }
  [^\n\r\"\\]+      { stringBuf.append( yytext() ); }
  \\t               { stringBuf.append('\t'); }
  \\n               { stringBuf.append('\n'); }
  \\r               { stringBuf.append('\r'); }
  \\\"              { stringBuf.append('\"'); }
  \\                { stringBuf.append('\\'); }
}

.|\n  { throw new Error("Invalid character ("+yytext()+")"); }
