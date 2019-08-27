{$X+}
unit scanunit;

(*********************************************************************************

 unit scanner (Part I of III of final assembler project)
 CS 2504 Programming assignment 5 (MAC II)
 Greg Fudala
 xxx-xx-xxxx
 Joerg Weimar
 3:30

 SCANNER ONLY:
 Purpose: This program is part I of III of the final 8080Z assembler. The program
          is a lexical analyser of the 8080Z assembly language. Upon execution, the
          user enters the source file to be scanned. The scanner will scan each line
          and return the tokens found. Token specification is explained in the 
          assignment sheet, but several ambiguities but be noted:

             1- A label/mnemonic must begin with a letter, or the remainder will
                be ingored. Any other characters except white-space characters
                in the remainder are accepted but told to be an error.
             2- A label found as an operand must also begin with a letter or
                the remainder is ignored. The label terminates with a white-space
                character, left and right parenthesis, comma, and single and
                double quotes. Digits are a part of a operand label.
             3- Hex numbers, A-F may be lowercase.

      **  NOTE: The implementation of this program is reasonable. The given test
                data results may be slightly different. 

          This program only returns the tokens found on a line. Further error
          checking will be included in the later additions.

          NOTE: ELSE in case statement is non-standard Pascal: compile w/ -x option.

 ********************************************************************************)

INTERFACE

const
   MAXLABEL = 30;			{max number of operand labels}
   MAXLINELEN = 81;			{max input line length ([81] init. to eoln)} 
   LABLEN = 8;				{label/mnemonic/operand label max length}
   NUMREGS = 12;			{number of registers}
   FILENAMELEN = 256;		        {max filename length}	
   SUFFLEN = 5;				{suffix to be appended length}
   MININT = -32768;			{minimum integer allowed}
   MAXINT = 65535; 			{maximum integer allowed}
   DQUOTE = '"';			{character constants}			
   SQUOTE = '''';
   COM = ',';
   BLANK = ' ';
   SCOLON = ';';

type
   tokentype=(lparen,rparen,reg16,reg8,comma,number,string,lable,accum,hl,null);
   tokenstring=packed array[1..LABLEN] of char;		
   regarray=array[1..NUMREGS]of tokenstring;
   constring=packed array[1..MAXLINELEN] of char;
   tokenrecord = record
      token: tokentype;
      value:integer;
      string:constring;
      text:tokenstring;
      direct:boolean;
   end;
   tabletype=array[1..MAXLABEL] of tokenrecord;
   string256=packed array[1..FILENAMELEN] of char;
   string5=packed array[1..SUFFLEN] of char;
   setchar=set of char;

 
var			(* GLOBAL *)
   table :tabletype;				{operand table}
   sourcefile,
   tempfile :text;				{input file}
   infile,rootfilename:string256;
   cchar, 					{current character from line}
   tab,						{control characters}
   endline,
   chr0
      :char;					{null character}
   inline:constring;	      		 	{input line fron file}
   numtok, 					{num tokens found}
   linect,					{line counter}
   infilelen,
   curr, 					{current index pos. to inline array}
   errct					{error counter}
      :integer;
   regtable:regarray;				{array of registers}
   skipset,lowlettset,uplettset,endset,decset,hexset   {global sets}
      :setchar;
   labelfield,mnemfield:tokenstring;

{NOTE- the above variables are all GLOBAL to avoid unwieldy parameter passing}

procedure append(var str256:string256;var str5:string5;index:integer);
procedure getfile;
function emptyst(st:tokenstring):boolean;
procedure clrdata(var labelfield,mnemfield:tokenstring);
procedure processline(var linect:integer);

IMPLEMENTATION

procedure append;

(*********************************************************************************

 procedure append
 Purpose: This procedure appends a string of length 5 to the end of a string of
          max length 256.
 Parameters: str256, str5 (to be appended to str256) and the index to append at.

 *********************************************************************************)

var i,j:integer;
   begin
   i:=0;
   repeat
      i:=i+1;
      str256[index+i-1]:=str5[i];
   until (str5[i]=chr0);
   for j:=index+i to 256 do
      str256[j]:=chr0;
   end;

procedure getfile;

(*********************************************************************************

 procedure getfile
 Purpose: This procedure gets the input source file, appends '.80z' to it, and
          opens the file for reading.

 *********************************************************************************)

var 
    i:integer;
    suffix:string5;

   begin
   suffix:='.80z ';
   suffix[5]:=chr0;
   i:=1;
   write('Source file: [.80z] ');
   readln(infile);
   while (infile[i]<>' ') or (i=FILENAMELEN) do
      i:=i+1;
   infile[i]:=chr0;
   infilelen:=i;
   rootfilename:=infile;
   append(infile,suffix,i);
   reset(sourcefile,infile);
   {write('Scanning file "');***
   writeln(infile,'"');***}
   end;

function retchar:char;

(********************************************************************************

 function retchar
 Purpose: this function returns the next character of the input line.

 ********************************************************************************)
          
   begin 
   curr:=curr+1;
   retchar:=inline[curr];
   end;

function endprocess:boolean;

(********************************************************************************

 function endprocess
 Purpose: this function returns TRUE if the current character is a white-space
          character or a terminating process char- endline or semicolon.

 ********************************************************************************) 

   begin
   if (cchar in skipset + endset) then
      endprocess:=TRUE
   else
      endprocess:=FALSE;
   end;

procedure getwhite;

(********************************************************************************

 procedure getwhite
 Purpose: This procedure simply skips over all white-space characters.

 ********************************************************************************)

   begin
   while (cchar in skipset) do
      cchar:=retchar;
   end;

procedure error(flag:integer);

(********************************************************************************

 procedure error
 Purpose: This procedure prints the appropriate error message given a unique
          flag parameter.
 Parameters: the unique error flag
 
 ********************************************************************************)

   begin
   errct:=errct+1;
   case flag of
0:writeln(tempfile,'Error: (op)label/mnemonic must begin with a letter. Ignoring remainder.');
1:writeln(tempfile,'Error: (op)label/mnemonic only contain letters, digits, & underscores');
     2:writeln(tempfile,'Error: number will not fit in 16 bits - reported as zero.');
     3:writeln(tempfile,'Error: bad character "',cchar,'"');
     4:writeln(tempfile,'Error: non legal digit in number');
     5:writeln(tempfile,'Error: expected end double quote for string');
     6:writeln(tempfile,'Error: expected endquote for character constant.');
   end;
   end;

procedure uppercase(var st:tokenstring;len:integer);

(********************************************************************************

 procedure uppercase
 Purpose: This procedure, given a string of tokenstring type and a length converts
          all lowercase letters to uppercase.
 Parameters: the string and length to convert up to.
 
 ********************************************************************************)

var i:integer;
   begin
   for i:=1 to len do
      if (st[i] in lowlettset) then 
         st[i]:=chr(ord(st[i])-32);
   end;

procedure getst(var lab:tokenstring;kind:integer);

(********************************************************************************

 procedure getst
 Purpose: This procedure fills the string lab of type tokenstring with characters
          until it reaches its max length or endprocedd returns TRUE. It also
          accepts parameter kind to distinguish between a label/mnemonic and
          an operand label. An operand label terminates under different 
          conditions.
 Parameters: the string and kind parameter.

 ********************************************************************************)
 
var i,j:integer;
    valid,					{valid characters within string}
    addset					{set used to distinguish between
						 label/mnemonic & operand label}
       :setchar;

   begin
   if (kind=0) then
      addset:=[]
   else
      addset:=['(',')',COM,SQUOTE,DQUOTE];
   valid:= lowlettset+uplettset+decset+['_'];
   i:=0;
   if not (cchar in lowlettset + uplettset) then
      error(0);

   repeat					{fill string}
      i:=i+1;
      lab[i]:=cchar;
      if (not (cchar in valid)) then
         error(1); 
      cchar:=retchar;
   until (i=LABLEN) or (endprocess) or (cchar in addset);

   if (i<LABLEN) then				{ fill remainder with blanks }
      for j:=i+1 to LABLEN do
         lab[j]:=BLANK;

   {check remainder of label if >8 characters for illegal characters}

   while not(endprocess) and not(cchar in addset) do 
         begin
         if not (cchar in valid) then
            error(1);
         cchar:=retchar;
         end;
   uppercase(lab,LABLEN);
   end;

function emptyst;

(********************************************************************************

 function emptyst
 Purpose: This function returns TRUE if the given string is empty([1]=chr0) and
          FALSE otherwise.
 Parameters: the string
 
 ********************************************************************************)

   begin
   if (st[1]=chr0) then
      emptyst:=TRUE
   else
      emptyst:=FALSE;
   end;

procedure clearlab;

(********************************************************************************

 procedure clearlab
 Purpose: this procedure skips over a label/mnemonic (if the first character
          is not a letter)

 ********************************************************************************)
          
   begin
   while not (endprocess) do
      cchar:=retchar;
   if not (cchar in endset) then
      getwhite;
   end;

procedure getnumber;

(********************************************************************************

 procedure getnumber
 Purpose: This procedure reads in a number(set off by a digit in the input line)
          and computes its value dependant on a base(hex, octal, binary, or dec).

 ********************************************************************************)

var i,j,
    divide,					{divisor-to compute num based on base}
    base,					{base of the number}
    num						{the numbers value}
      :integer;
    edig,					{the char before terminating char}
    digit					{a digit from the number}
       :char;
    negateflag:boolean;				{if the number if negative-TRUE}
    baseset:setchar;				{valid set of digits of unique base}

   begin
   baseset:=decset;
   base:=10;
   divide:=1;
   i:=0;
   negateflag:=FALSE;
   if (cchar = '-') then  			{if negative, negateflag = TRUE}  
      begin
      cchar:=retchar;
      negateflag:=TRUE;
      end;

   {look ahead until terminating character to determine length of number(digits)}

   repeat			
      digit:=inline[curr+i];
      i:=i+1;  
   until not(digit in hexset + decset);
   i:=i-1;
   if (digit in ['h','q','H','Q']) then		{if terminating digit was 'H' or 'Q'}
      edig:=inline[curr+i]
   else						{otherwise- adjust edig and next}
      edig:=inline[curr+i-1];
   if (edig in ['d','b','D','B']) then
      i:=i-1;
   
   case edig of					{if a base is specified, set base}
   'B','b':begin  				{and its valid digit set}
          base:=2;
          baseset:=['0','1'];
          end;
   'Q','q':begin
          base:=8;
          baseset:=['0'..'7'];
          end;
   'H','h':begin
          base:=16;
          baseset:=decset + hexset;
          end;
   ELSE   ;
   end;  {case}

   for j:=1 to i-1 do				{compute divide (multiple of base)}
      divide:=divide*base;
   for j:=1 to i do				{run thru number digit by digit}
      begin
      if not(cchar in baseset) then		{if invalid digit, num=0, report error}
         begin
         error(4);
         num:=0;
         divide:=0;
         cchar:=retchar;
         end
      else					{else-compute value}
         begin                                     
         if (cchar in ['A'..'F']) then          {if hex digits, must adjust}
            num:=num + (ord(cchar)-55)*divide
         else
         if (cchar in ['a'..'f']) then
            num:=num + (ord(cchar)-87)*divide
         else
            num:=num + (ord(cchar)-ord('0'))*divide;
         cchar:=retchar;
         divide:=divide div base;               {adjust divide to n-1 power of base}
         end;
      end;

   if (negateflag) then				{if negative, mult by -1}
      num:=num*(-1);

   if (num>MAXINT) or (num<MININT) then         {if number cannot fit in 16-bits}
      begin					{report error}
      error(2);
      num:=0;
      end;
   table[numtok].value:=num;			{put value in operand table}
   table[numtok].token:=number;
   numtok:=numtok+1;
   if (edig in ['d','b','h','q','D','B','H','Q']) and not(cchar in endset) then  
      cchar:=retchar;					{^ skip base char } 
   end; 

procedure fillst;

(*******************************************************************************

 procedure fillst
 Purpose: This procedure fills a label string. If the terminating end double
          quote is not seen, an error is reported.

 *******************************************************************************)

var stringlabel:constring;			{the label string to be filled}
    i:integer;
   begin
   i:=1;
      cchar:=retchar; 			           {skip first double quote }
   while (cchar<>endline) and (cchar<>DQUOTE) do   {fill label string} 
      begin
      stringlabel[i]:=cchar;
      cchar:=retchar;
      i:=i+1;
      end;
   {if (i<MAXLINELEN) then
      stringlabel[i]:=chr0;}
   if (cchar<>DQUOTE) then			{if terminator isn't double quote-}
      error(5)					{report error}
   else
      cchar:=retchar;				{skip over last double quote }
   getwhite;				
   table[numtok].string:=stringlabel;	        {put string in operand table}	
   table[numtok].token:=string;
   numtok:=numtok+1;
   end;

procedure initregtable;

(******************************************************************************

 procedure initregtable
 Purpose: This procedure initializes the array of register strings for comparison
          to determine if an operand label might be a register.

 ******************************************************************************)

   begin
   regtable[1]:='A       ';
   regtable[2]:='B       ';
   regtable[3]:='C       ';
   regtable[4]:='D       ';
   regtable[5]:='E       ';
   regtable[6]:='H       ';
   regtable[7]:='L       ';
   regtable[8]:='HL      ';
   regtable[9]:='AF      ';
   regtable[10]:='BC      ';
   regtable[11]:='DE      ';
   regtable[12]:='SP      ';
   end;

procedure checkreg(alabel:tokenstring);

(*******************************************************************************

 procedure checkreg
 Purpose: This procedure, given a operand label, determines whether it is actually
          a register or an operand label. It then makes the appropriate assignment
          in the table of operands.

 *******************************************************************************)
 
var reg:tokenstring;				{assigned to a register string
 						 if the operand label is a register}
    i,
    foundreg:integer; 				{the index to the array of registers}                       
   begin
   foundreg:=0;
   for i:=1 to NUMREGS do			{determine if operand label is in the}
      if (alabel=regtable[i]) then		{array of registers}
         begin
         foundreg:=i;
         reg:=regtable[foundreg];
         end;

   if (foundreg<LABLEN) and (foundreg<>0) then		{have 8reg or accum}
      begin
      reg[2]:=chr0;
      table[numtok].text:=reg;
      if (foundreg=1) then		   		{have accumulator}
         table[numtok].token:=accum 
      else						{have 8reg}
         table[numtok].token:=reg8;
      numtok:=numtok+1;
      end
   else
   if (foundreg>=LABLEN) then				{have reg16}
      begin
      reg[3]:=chr0;
      table[numtok].text:=reg;
      if (foundreg=LABLEN) then				{have hl}
         table[numtok].token:=hl
      else
         table[numtok].token:=reg16;
      numtok:=numtok+1;
      end
   else							{must have label}
      if (alabel[1] in uplettset + lowlettset) then
         begin
         table[numtok].token:=lable;			{assign to operand table}
         table[numtok].text:=alabel;
         numtok:=numtok+1;
         end;
   end;

procedure getcharconst;

(********************************************************************************
 
 procedure getcharconst
 Purpose: This procedure determines the ASCII value of the character constant. If
          the closing single quote is missing, an error is reported.

 ********************************************************************************)
 
var asciirep:integer;					{ASCII value of character}
   begin
   cchar:=retchar;
   asciirep:=ord(cchar);
   if (cchar<>endline) then				
      begin
      cchar:=retchar;					{ closing quote? }
      if (cchar<>SQUOTE) then
         error(6);
      table[numtok].value:=asciirep;			{assign to operand table}
      table[numtok].token:=number;
      numtok:=numtok+1; 
      if not(cchar in endset) and (cchar=SQUOTE) then	{if final character not eoln}
         cchar:=retchar;				{or semicolon, get next char}
      end;
   end;
   
procedure showtokens(labelfield,mnemfield:tokenstring);

(*********************************************************************************

 procedure showtokens
 Purpose: This procedure prints the tokens found in a line. 
 Parameters: label/mnemonic field

 *********************************************************************************)
 
var i:integer;
   begin
   if not (emptyst(labelfield)) then
      writeln('Label field contains "', labelfield,'".')
   else 
      writeln('No label field.');
   if not (emptyst(mnemfield)) then
      writeln('Mnemonic field contains "', mnemfield,'".')
   else
      writeln('No mnemonic field.');

   writeln('The scanner found ',numtok-1, ' tokens:');
   for i:=1 to numtok-1 do
      case (table[i].token) of
         number: writeln('   Number ',table[i].value);
         string: writeln('   String "', table[i].string,'"');
         reg8:   writeln('   8-bit register ', table[i].text);
         accum:  writeln('   Accumulator');
         reg16:  writeln('   16-bit register ',table[i].text);
         hl:     writeln('   Register HL');
         lable:  writeln('   Label "',table[i].text,'"');
         lparen: writeln('   Left parenthesis');
         rparen: writeln('   Right parenthesis');
         comma:  writeln('   Comma');
      end; 
   writeln;
   end;

procedure clrdata;

(*********************************************************************************

 procedure clrdata
 Purpose: This procedure clears the tokens found in a line by setting the label and 
          mnemonic fields to null and clearing the operand table by setting all
          indexes.token to null.
 Parameters: label/mnemonic fields

 *********************************************************************************)
 
var i:integer;
   begin
   labelfield[1]:=chr0;
   mnemfield[1]:=chr0;
   numtok:=1;
   for i:=1 to MAXLABEL do
         table[i].token:=null;
   end;


procedure processline;

(*********************************************************************************

 procedure processline
 Purpose: This procedure is the supervisor of the scanner. It first determines the
          label & mnemonic fields (if any) and then collects the operand tokens
          (max 30).  
 Parameters: line counter

 *********************************************************************************)

var
    alabel					{operand label}
       :tokenstring;
    letters:setchar;				{set of letters}

   begin
   curr:=0;
   letters:=uplettset + lowlettset;
   labelfield[1]:=chr0;				{set label/mnemonic fields to null}
   mnemfield[1]:=chr0;
   {writeln(linect:1,': ', inline);***}
   cchar:=retchar;
   if not(endprocess) then   	                {might have legal label }
      begin
      if (cchar in letters) then		{have label field}
         begin
         getst(labelfield,0);
         uppercase(labelfield,LABLEN);
         end
      else					{non-letter in first column}
         begin					{report error & ignore remainder}
         error(0);
         clearlab;
         end;
      end;
   getwhite;
 
   if not(cchar in endset) then                 {might have legal mnemonic }
      begin
      if (cchar in letters) then		{have mnemonic}
         begin
         getst(mnemfield,0);
         uppercase(mnemfield,LABLEN);
         end
      else					{non-letter starting mnemonic}
         begin					{report error & ignore remainder}
         error(0);
         clearlab;
         end;
      getwhite;
      end;
         
   while not(cchar in endset) and (numtok<=MAXLABEL) do  {get ops until eoln or ; }
      begin
      if (cchar in decset + ['-']) then			 {get number}
         getnumber
      else
         if (cchar=DQUOTE) then				 {get string}
            fillst
      else
         if (cchar in letters) then			 {get operand label - }  
            begin 					 { (may be register) }
            getst(alabel,1);
            checkreg(alabel);
            end
      else
         if (cchar=SQUOTE) then				 {get character constant}
            getcharconst
      else
         if (cchar in ['(',')',COM]) then		 {have punctuation}
            begin
            case cchar of
            '(':   table[numtok].token:=lparen;		 {assign to operand table}
            ')':   table[numtok].token:=rparen;
            COM:   table[numtok].token:=comma;
            end;   {case}
            numtok:=numtok+1;
            cchar:=retchar;     		         {next char }
            end
         else			                         {illegal character -}  
            begin
            error(3);					 {report error}
            clearlab;                    		 {ignore remainder}
            end;

         if not(cchar in endset) then
            getwhite;   				 {read up to next non-white}
      end;    {end collecting tokens}
      
   {showtokens(labelfield,mnemfield); ***}		 {show tokens}
   linect:=linect+1;					 {increment line counter}
   {clrdata(labelfield,mnemfield);    ***}		 {clear results}
   
   end;	  {processline}


begin 

   tab:=chr(9);						{character variables}
   endline:=chr(10);
   linect:=1;
   numtok:=1;
   skipset:=[BLANK,tab];				{init. useful iglobal valid sets}
   lowlettset:=['a'..'z'];
   uplettset:=['A'..'Z'];
   endset:=[endline,SCOLON];
   decset:=['0'..'9'];
   hexset:=['A'..'F','a'..'f'];
   chr0:=chr(0);					{global null variable}

   initregtable;					{init. array of registers}

end.   {unit scanunit}

