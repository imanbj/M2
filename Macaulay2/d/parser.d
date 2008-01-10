--		Copyright 1994 by Daniel R. Grayson
use C;
use err;
use system;
use strings;
use varstrin;
use lex;
use stdio;
use stdiop;
use gmp;
use nets;
use tokens;
use ctype;
use gmp;

export parseInt(s:string):ZZ := (
     i := toInteger(0);
     foreach c in s do (
	  if c == '\"'
	  then nothing
	  else i = 10 * i + (c - '0')
	  );
     i);
export parseRR(s:string):RR := (			    -- 4.33234234234p345e-9
     inPrec := false;
     inExpon := false;
     extra := 16;
     prec := ulong(53);
     exsign := false;
     expon := long(0);
     foreach c in s do (
	  if c == 'e' then (
		    inPrec = false;
		    inExpon = true;
		    )
	  else if c == 'p' then (
	       inPrec = true;
	       prec = ulong(0);
	       )
	  else if inPrec then (
	       if isdigit(c) then prec = 10 * prec + (c - '0')
	       )
	  else if inExpon then (
	       if isdigit(c) then expon = 10 * expon + (c - '0')
	       else if c == '-' then exsign = true;
	       ));
     if exsign then expon = -expon;
     pointSeen := false;
     x := toRR(0,prec+extra);
     y := toRR(1,prec+extra);
     foreach c in s do (
	  if c == '\"' then nothing
	  else if c == '.' then pointSeen = true
	  else if isdigit(c) then (
	       if pointSeen then (
	       	    x = x + (y * (c - '0'))/10;
	       	    y = y / 10;
	       	    )
	       else x = x * 10 + (c - '0'))
	  else break;);
     x = x * pow10(expon,prec+extra);
     toRR(x,prec));
parseError := false;
parseMessage := "";
utf8(w:varstring,i:int):varstring := (
     -- this code appears twice
     if (i &     ~0x7f) == 0 then w << char(i) else
     if (i &    ~0x7ff) == 0 then w << char(0xc0 | (i >> 6)) << char(0x80 | (i & 0x3f)) else
     if (i &   ~0xffff) == 0 then w << char(0xe0 | (i >> 12)) << char(0x80 | ((i >> 6) & 0x3f)) << char(0x80 | (i & 0x3f)) else
     if (i & ~0x1fffff) == 0 then w << char(0xf0 | (i >> 18)) << char(0x80 | ((i >> 12) & 0x3f)) << char(0x80 | ((i >> 6) & 0x3f)) << char(0x80 | (i & 0x3f))
     else w
     );

export hexvalue   (c:char ):int  := (
     if c >= '0' && c <= '9' then c - '0' else
     if c >= 'a' && c <= 'f' then 10 + (c - 'a') else
     if c >= 'A' && c <= 'F' then 10 + (c - 'A')
     else 0						    -- we don't expect this to happen
     );
export hexvalue   (c:int ):int  := hexvalue(char(c));

export parseString(s:string):string := (
     parseError = false;
     v := newvarstring(length(s)-2);
     i := 1;
     while true do (
	  if s.i == '\"' then break;
	  if s.i == '\\' then (
	       i = i+1;
	       c := s.i;
	       if c == 'n' then v << '\n'
	       else if c == '"' then v << '"'
	       else if c == 'r' then v << '\r'
	       else if c == 'b' then v << '\b'
	       else if c == 't' then v << '\t'
	       else if c == 'f' then v << '\f'
	       else if c == '\\' then v << '\\'
	       else if c == 'u' then (
		    i = i+4;
		    utf8(v, ((hexvalue(s.(i-3)) * 16 + hexvalue(s.(i-2))) * 16 + hexvalue(s.(i-1))) * 16 + hexvalue(s.i)))
	       else if '0' <= c && c < '8' then (
		    j := c - '0';
		    c = s.(i+1);
		    if '0' <= c && c < '8' then (
			 i = i+1;
			 j = 8 * j +  (c - '0');
			 c = s.(i+1);
			 if '0' <= c && c < '8' then (
			      i = i+1;
			      j = 8 * j +  (c - '0');
			      );
			 );
		    v << char(j)
		    )
	       else (
		    parseError = true;
		    parseMessage = "unknown escape sequence \\" + c;
		    v << c
		    )
	       )
	  else v << s.i;
	  i = i+1;
	  );
     tostring(v)
     );

export thenW := Word("{*dummy word: then*}",TCnone,0,newParseinfo());		  -- filled in by binding.d
export whenW := Word("{*dummy word: when*}",TCnone,0,newParseinfo());		  -- filled in by binding.d
export elseW := Word("{*dummy word: else*}",TCnone,0,newParseinfo());		  -- filled in by binding.d
export ofW := Word("{*dummy word: of*}",TCnone,0,newParseinfo());		  -- filled in by binding.d
export doW := Word("{*dummy word: do*}",TCnone,0,newParseinfo());		  -- filled in by binding.d
export listW := Word("{*dummy word: list*}",TCnone,0,newParseinfo());		  -- filled in by binding.d
export fromW := Word("{*dummy word: from*}",TCnone,0,newParseinfo());		  -- filled in by binding.d
export inW := Word("{*dummy word: in*}",TCnone,0,newParseinfo());		  -- filled in by binding.d
export toW := Word("{*dummy word: to*}",TCnone,0,newParseinfo());		  -- filled in by binding.d
export debug := false;
export tracefile := dummyfile;
export openTokenFile(filename:string):(TokenFile or errmsg) := (
     when openPosIn(filename)
     is f:PosFile do (TokenFile or errmsg)(TokenFile(f,NULL))
     is s:errmsg  do (TokenFile or errmsg)(s)
     );
export setprompt(file:TokenFile,prompt:function():string):void := setprompt(file.posFile,prompt);
export unsetprompt(file:TokenFile):void := unsetprompt(file.posFile);
export gettoken(file:TokenFile,obeylines:bool):Token := (
     when file.nexttoken
     is null do gettoken(file.posFile,obeylines)
     is w:Token do (
	  file.nexttoken = NULL;
     	  w
	  )
     );
export peektoken(file:TokenFile,obeylines:bool):Token := (
     when file.nexttoken
     is null do (
	  w := gettoken(file,obeylines);
	  file.nexttoken = w;
	  w
	  )
     is w:Token do w
     );
level := 0;
export errorTree := ParseTree(dummy(dummyPosition));
skip(file:TokenFile,prec:int):void := (
     while peektoken(file,false).word.parse.precedence > prec 
     do gettoken(file,false)
     );
accumulate(e:ParseTree,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     if e == errorTree then return errorTree;
     ret := e;
     while true do (
	  token := peektoken(file,obeylines);
	  if token == errorToken then (
	       gettoken(file,obeylines);
	       ret = errorTree;
	       break;
	       );
	  if token.word.parse.precedence <= prec then break;
	  gettoken(file,obeylines);
	  ret = token.word.parse.funs.binary(ret,token,file,prec,obeylines);
	  if ret == errorTree then break;
	  );
     ret
     );
export errorunary(token1:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     printErrorMessage(token1,"syntax error at '" + token1.word.name + "'");
     errorTree
     );
export errorbinary(lhs:ParseTree, token2:Token, file:TokenFile, prec:int,obeylines:bool):ParseTree := (
     printErrorMessage(token2,"syntax error at '" + token2.word.name + "'");
     errorTree
     );
export defaultunary(token1:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     accumulate(ParseTree(token1),file,prec,obeylines)
     );
export parse(file:TokenFile,prec:int,obeylines:bool):ParseTree;
export nparse(file:TokenFile,prec:int,obeylines:bool):ParseTree;
export unaryop(token1:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     ret := parse(file,max(prec,token1.word.parse.unaryStrength),obeylines);
     if ret == errorTree then ret
     else accumulate(ParseTree(Unary(token1,ret)),file,prec,obeylines));
export nunaryop(token1:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     ret := nparse(file,token1.word.parse.unaryStrength,obeylines);
     if ret == errorTree then ret
     else accumulate(ParseTree(Unary(token1,ret)),file,prec,obeylines));
export nnunaryop(token1:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     if token1.word.parse.precedence <= prec
     then errorunary(token1,file,prec,obeylines)
     else (
	  ret := nparse(file,token1.word.parse.unaryStrength,obeylines);
	  if ret == errorTree then ret
	  else accumulate(ParseTree(Unary(token1,ret)),file,prec,obeylines)));
export precSpace := 0;		-- filled in later by binding.d
export defaultbinary(lhs:ParseTree, token2:Token, file:TokenFile, prec:int, obeylines:bool):ParseTree := (
     if token2.followsNewline then (
     	  printErrorMessage(token2,"missing semicolon or comma on previous line?");
     	  errorTree)
     else (
     	  ret := token2.word.parse.funs.unary(token2,file,precSpace-1,obeylines);
     	  if ret == errorTree then ret else ParseTree(Adjacent(lhs,ret))));
export postfixop(lhs:ParseTree, token2:Token, file:TokenFile, prec:int, obeylines:bool):ParseTree := (
     accumulate(ParseTree(Postfix(lhs,token2)),file,prec,obeylines));
export parse(file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     token := gettoken(file,false);
     if token == errorToken then return errorTree;
     ret := token.word.parse.funs.unary(token,file,prec,obeylines);
     if ret == errorTree then (
	  if isatty(file) || file.posFile.file.fulllines then flush(file) else skip(file,prec));
     ret
     );
export nparse(file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     token := peektoken(file,obeylines);
     if token == errorToken then return errorTree;
     ret := (
	  if token == errorToken
	  then errorTree
	  else if token.word.parse.precedence > prec
     	  then (
     	       token = gettoken(file,obeylines);
	       token.word.parse.funs.unary(token,file,prec,obeylines)
	       )
     	  else ParseTree(dummy(position(token)))
	  );
     if ret == errorTree then (
	  if isatty(file) then flush(file) else skip(file,prec));
     ret
     );
export binaryop(lhs:ParseTree, token2:Token, file:TokenFile, prec:int, obeylines:bool):ParseTree := (
     ret := parse(file,token2.word.parse.binaryStrength,obeylines);
     if ret == errorTree then ret 
     else ParseTree(Binary(lhs, token2, ret)));
export nbinaryop(lhs:ParseTree, token2:Token, file:TokenFile, prec:int, obeylines:bool):ParseTree := (
     ret := nparse(file,token2.word.parse.binaryStrength,obeylines);
     if ret == errorTree then ret else ParseTree(Binary(lhs, token2, ret)));
export arrowop(lhs:ParseTree, token2:Token, file:TokenFile, prec:int, obeylines:bool):ParseTree := (
     e := parse(file,token2.word.parse.binaryStrength,obeylines);
     if e == errorTree then e else ParseTree(Arrow(lhs, token2, e, dummyDesc)));
MatchPair := {left:string, right:string, next:(null or MatchPair)};
matchList := (null or MatchPair)(NULL);
export addmatch(left:string, right:string):void := (
     matchList = MatchPair(left,right,matchList);
     );
matcher(left:string):string := (
     rest := matchList;
     while true do
     when rest is null do break	    	 	-- should not happen
     is matchPair:MatchPair do (
	  if matchPair.left == left then return matchPair.right;
	  rest = matchPair.next;	  
	  );
     ""
     );
match(left:string,right:string):bool := (
     rest := matchList;
     while true do
     when rest
     is null do return false
     is matchPair:MatchPair do (
	  if matchPair.left == left
	  then if matchPair.right == right
	  then return true;
	  rest = matchPair.next;
	  ));
export varexprlist := {
     list:array(ParseTree),
     size:int
     };
export newvarexprlist(i:int):varexprlist := varexprlist(
     new array(ParseTree) len i do provide dummyTree, 
     0);
needatleast(i:int,v:varexprlist):void := (
     if length(v.list) < i then (
     	  v.list = new array(ParseTree) len 2*i do (
	       foreach e in v.list do provide e;
	       while true do provide dummyTree;
	       );
     	  );
     );
export (v:varexprlist) << (e:ParseTree) : varexprlist := (
     needatleast(v.size + 1,v);
     v.list.(v.size) = e;
     v.size = v.size + 1;
     v
     );
export toexprlist(v:varexprlist):ArrayParseTree := (
     new array(ParseTree) len v.size do foreach e in v.list do provide e
     );
export unaryparen(left:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     rightparen := matcher(left.word.name);
     if rightparen == peektoken(file,false).word.name
     then accumulate(ParseTree(EmptyParentheses(left,gettoken(file,false))),file,prec,obeylines)
     else (
	  e := parse(file,left.word.parse.unaryStrength,false);
	  if e == errorTree then return e;
	  right := gettoken(file,false);
	  if rightparen == right.word.name
	  then accumulate(ParseTree(Parentheses(left,e,right)),file,prec,obeylines)
	  else (
	       printErrorMessage(right, "expected \"" + rightparen + "\"");
	       printErrorMessage(left," ... to match this");
	       errorTree)));
export unarywhile(
     whileToken:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     predicate := parse(file,whileToken.word.parse.unaryStrength,false);
     if predicate == errorTree then return errorTree;
     token2 := gettoken(file,false);
     if token2 == errorToken then return errorTree;
     if token2.word == doW then (
	  doClause := parse(file,doW.parse.unaryStrength,obeylines);
	  if doClause == errorTree then return errorTree;
	  r := ParseTree(WhileDo(whileToken,predicate,token2,doClause));
	  accumulate(r,file,prec,obeylines))
     else if token2.word == listW then (
	  listClause := parse(file,listW.parse.unaryStrength,obeylines);
	  if listClause == errorTree then return errorTree;
	  if peektoken(file,obeylines).word == doW then (
	       doToken := gettoken(file,obeylines);
	       if doToken == errorToken then return errorTree;
	       doClause := parse(file,doW.parse.unaryStrength,obeylines);
	       if doClause == errorTree then return errorTree;
	       ret := ParseTree(WhileListDo(whileToken,predicate,token2,listClause,doToken,doClause));
	       accumulate(ret,file,prec,obeylines))
	  else (
	       ret := ParseTree(WhileList(whileToken,predicate,token2,listClause));
	       accumulate(ret,file,prec,obeylines)))
     else (
	  printErrorMessage(token2,"syntax error : expected 'do' or 'list'");
	  printErrorMessage(whileToken," ... to match this 'while'");
	  errorTree));

export unaryfor(
     forToken:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     var := parse(file,forToken.word.parse.unaryStrength,false);
     if var == errorTree then return errorTree;
     inClause := dummyTree;
     fromClause := dummyTree;
     toClause := dummyTree;
     whenClause := dummyTree;
     listClause := dummyTree;
     doClause := dummyTree;
     token2 := gettoken(file,false);
     if token2 == errorToken then return errorTree;
     if token2.word == inW then (
	  inClause = parse(file,inW.parse.unaryStrength,false);
	  if inClause == errorTree then return errorTree;
	  token2 = gettoken(file,false);
	  )
     else (
	  if token2.word == fromW then (
	       fromClause = parse(file,fromW.parse.unaryStrength,false);
	       if fromClause == errorTree then return errorTree;
	       token2 = gettoken(file,false);
	       );
	  if token2.word == toW then (
	       toClause = parse(file,toW.parse.unaryStrength,false);
	       if toClause == errorTree then return errorTree;
	       token2 = gettoken(file,false);
	       );
	  );
     if token2.word == whenW then (
	  whenClause = parse(file,whenW.parse.unaryStrength,false);
	  if whenClause == errorTree then return errorTree;
     	  token2 = gettoken(file,false);
	  );
     if token2.word == doW then (
	  doClause = parse(file,doW.parse.unaryStrength,obeylines);
	  if doClause == errorTree then return errorTree;
	  r := ParseTree(For( forToken, var, inClause, fromClause, toClause, whenClause, listClause,doClause, dummyDictionary ));
	  accumulate(r,file,prec,obeylines))
     else if token2.word == listW then (
	  listClause = parse(file,listW.parse.unaryStrength,obeylines);
	  if listClause == errorTree then return errorTree;
	  if peektoken(file,obeylines).word == doW then (
	       gettoken(file,obeylines);
	       doClause = parse(file,doW.parse.unaryStrength,obeylines);
	       if doClause == errorTree then return errorTree;
	       );
	  r := ParseTree(For(forToken, var, inClause, fromClause, toClause,whenClause, listClause, doClause, dummyDictionary));
	  accumulate(r,file,prec,obeylines))
     else (
	  printErrorMessage(token2,"syntax error : expected 'do' or 'list'");
	  printErrorMessage(forToken," ... to match this 'for'");
	  errorTree));

-- unstringToken(q:Token):Token := (
--      if q.word.typecode == TCstring 
--      then (
-- 	  p := parseString(q.word.name);
-- 	  if parseError then (
-- 	       printErrorMessage(q,parseMessage);
-- 	       errorToken)
-- 	  else Token(
-- 	       makeUniqueWord(p,q.word.parse),
-- 	       q.filename, q.line, q.column, q.loadDepth,	    -- q.position,
-- 	       q.dictionary,q.entry,q.followsNewline)
-- 	  )
--      else q);

export unarysymbol(
     quotetoken:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     arg := gettoken(file,false);
     if arg == errorToken then return errorTree;
     -- u := unstringToken(arg);
     -- if u == errorToken then return errorTree;
     if arg.word.typecode != TCid then ( printErrorMessage(arg, "syntax error: " + arg.word.name); return errorTree; );
     r := ParseTree(Quote(quotetoken,arg));
     accumulate(r,file,prec,obeylines));
export unaryglobal(
     quotetoken:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     arg := gettoken(file,false);
     if arg == errorToken then return errorTree;
     -- u := unstringToken(arg);
     -- if u == errorToken then return errorTree;
     if arg.word.typecode != TCid then ( printErrorMessage(arg, "syntax error: " + arg.word.name); return errorTree; );
     r := ParseTree(GlobalQuote(quotetoken,arg));
     accumulate(r,file,prec,obeylines));
export unarylocal(
     quotetoken:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     arg := gettoken(file,false);
     if arg == errorToken then return errorTree;
     -- u := unstringToken(arg);
     -- if u == errorToken then return errorTree;
     if arg.word.typecode != TCid then ( printErrorMessage(arg, "syntax error: " + arg.word.name); return errorTree; );
     r := ParseTree(LocalQuote(quotetoken,arg));
     accumulate(r,file,prec,obeylines));
export unaryif(ifToken:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     predicate := parse(file,ifToken.word.parse.unaryStrength,false);
     if predicate == errorTree then return predicate;
     thenToken := gettoken(file,false);
     if thenToken == errorToken then return errorTree;
     if thenToken.word != thenW then (
	  printErrorMessage(thenToken,"syntax error : expected 'then'");
	  printErrorMessage(ifToken," ... to match this 'if'");
	  return errorTree);
     thenClause := parse(file,thenW.parse.unaryStrength,obeylines);
     if thenClause == errorTree then return errorTree;
     if peektoken(file,obeylines).word == elseW then (
     	  elseToken := gettoken(file,obeylines);
	  if elseToken == errorToken then return errorTree;
	  elseClause := parse(file,elseW.parse.unaryStrength,obeylines);
     	  if elseClause == errorTree then return errorTree;
	  ret := ParseTree(IfThenElse(ifToken,predicate,thenClause,elseClause));
	  accumulate(ret,file,prec,obeylines))
     else (
	  ret := ParseTree(IfThen(ifToken,predicate,thenClause));
	  accumulate(ret,file,prec,obeylines))
     );
export unarytry(tryToken:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     primary := parse(file,tryToken.word.parse.unaryStrength,obeylines);
     if primary == errorTree then return primary;
     if peektoken(file,obeylines).word == elseW then (
	  elseToken := gettoken(file,false);
	  if elseToken == errorToken then return errorTree;
	  if elseToken.word != elseW then (
	       printErrorMessage(elseToken,"syntax error : expected 'else'");
	       printErrorMessage(tryToken," ... to match this 'try'");
	       return errorTree);
	  elseClause := parse(file,elseW.parse.unaryStrength,obeylines);
	  if elseClause == errorTree then return errorTree;
	  accumulate(ParseTree(TryElse(tryToken,primary,elseToken,elseClause)),file,prec,obeylines))
     else if peektoken(file,obeylines).word == thenW then (
	  thenToken := gettoken(file,false);
	  if thenToken == errorToken then return errorTree;
	  thenClause := parse(file,thenW.parse.unaryStrength,obeylines);
	  if thenClause == errorTree then return errorTree;
	  if peektoken(file,obeylines).word == elseW then (
	       elseToken := gettoken(file,false);
	       if elseToken == errorToken then return errorTree;
	       elseClause := parse(file,elseW.parse.unaryStrength,obeylines);
	       if elseClause == errorTree then return errorTree;
	       accumulate(ParseTree(TryThenElse(tryToken,primary,thenToken,thenClause,elseToken,elseClause)),file,prec,obeylines))
	  else (
	       printErrorMessage(tryToken,"syntax error : expected 'else' to match this 'try'");
	       return errorTree))
     else accumulate(ParseTree(Try(tryToken,primary)),file,prec,obeylines));
export unarycatch(catchToken:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     primary := parse(file,catchToken.word.parse.unaryStrength,obeylines);
     if primary == errorTree then return primary;
     accumulate(ParseTree(Catch(catchToken,primary)),file,prec,obeylines));
export unarynew(newtoken:Token,file:TokenFile,prec:int,obeylines:bool):ParseTree := (
     newclass := parse(file,newtoken.word.parse.unaryStrength,obeylines);
     if newclass == errorTree then return errorTree;
     ofToken := dummyToken;
     newparent := dummyTree;
     if peektoken(file,obeylines).word == ofW then (
	  ofToken = gettoken(file,obeylines);
	  newparent = parse(file,ofW.parse.unaryStrength,obeylines);
	  if newparent == errorTree then return errorTree;
	  );
     fromToken := dummyToken;
     newinitializer := dummyTree;
     if peektoken(file,obeylines).word == fromW then (
	  fromToken = gettoken(file,obeylines);
	  newinitializer = parse(file,fromW.parse.unaryStrength,obeylines);
	  if newinitializer == errorTree then return errorTree;
	  );
     accumulate(ParseTree(New(newtoken,newclass,newparent,newinitializer)),file,prec,obeylines));

export treePosition(e:ParseTree):Position := (
     while true do (
	  when e
	  is dummy do return dummyPosition
	  is token:Token do return position(token)
	  is adjacent:Adjacent do e = adjacent.lhs
	  is binary:Binary do return position(binary.operator)
	  is a:Arrow do return position(a.operator)
	  is unary:Unary do return position(unary.operator)
	  is postfix:Postfix do return position(postfix.operator)
	  is a:Quote do return position(a.operator)
	  is a:GlobalQuote do return position(a.operator)
	  is a:LocalQuote do return position(a.operator)
	  is ee:Parentheses do return position(ee.left)
	  is ee:EmptyParentheses do return position(ee.left)
     	  is i:IfThen do return position(i.ifToken)
	  is i:TryThenElse do return position(i.tryToken)
	  is i:TryElse do return position(i.tryToken)
	  is i:Try do return position(i.tryToken)
	  is i:Catch do return position(i.catchToken)
     	  is i:IfThenElse do return position(i.ifToken)
     	  is w:For do return position(w.forToken)
     	  is w:WhileDo do return position(w.whileToken)
     	  is w:WhileList do return position(w.whileToken)
     	  is w:WhileListDo do return position(w.whileToken)
     	  is s:StartDictionary do e = s.body
	  is n:New do return position(n.newtoken)
	  )
     );

-- Local Variables:
-- compile-command: "make -C $M2BUILDDIR/Macaulay2/d "
-- End:
