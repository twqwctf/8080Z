{$X+}
unit pass1unit;

(********************************************************************************

 unit pass1unit (part II of III of final assembler project)

 Purpose: This unit is responsible for converting the tokens returned by the scanner
          to logical operands in the 8080Z Assembly language. For part II of the  
          final assembly project, this section recieves the tokens from the scanner
          and produces two output files, later to be used by pass2. The first is
          a temporary file, 'asmtemp' which contains, line by line, a line's scanning
          and parsing errors, the current location counter, the instruction type -
          (from the instruction table if the instruction exists), the # of operands,
          and a list of those operands. The operands are divided into logical 
          catagories recognized by a special letter as explained in the assignment
          sheet. In addition, a symbol table is outputed to the root source file
          name with '.lst' appended. (source- fileinput.80z , symbol table is in
          fileinput.lst). 
             If a fatal error occurs in a line, the location counter will not be
          incremented and no machine code will be produced for that line. However,
          pass1 may ignore several less-fatal errors and continue processing the
          line as valid.

 ********************************************************************************) 

INTERFACE 

uses itab,scanunit,treeunit;

type
   {OPERAND TABLE}

   operandarray=array[1..11] of char;
   operandrec=record
      opkind:char;
      maininfo:tokenrecord;
   end;
   
var 
   optable:array[1..16] of operandrec;			{operand table}
   opct,						{number of operands in a line}
   linetype,						{line type}
   commact,						{comma counter}
   currtoken,						{counter upto # of total tokens}
   locctr,						{location counter}	
   templocctr						{a temporary location ctr}
      :integer;
   magiclist:operandarray;				{list of unique op. letters}
   mnemsuff:array[1..2] of char;			{appended to mnemonic for 
							 instruction search}
   notoperand,						{not operand flag}
   back,						{flag for indirection routine}
   ignoreflag						{ignore line flag}
      :boolean;
   instruct:mnem_ops_type;				{instruction string for search
							 in inst. table}
   magiclet:char;					{unique operand letter}

   {The above variables are GLOBAL to avoid unwieldy parameter passing}

procedure parseline;
procedure printtempfile;
procedure checkglobalundef(bintree:treetype);
procedure stringsize(st:constring;var size:integer);

IMPLEMENTATION

procedure initmagiclist;

(*********************************************************************************

 procedure initmagiclist
 Purpose: This procedure initializes the magiclist array to the unique operand letters.
          If any changes were to be made to the letters, they could be done here
          easily.

 *********************************************************************************)

   begin
   magiclist[1]:='A';
   magiclist[2]:='H';
   magiclist[3]:='I';
   magiclist[4]:='N';
   magiclist[5]:='D';
   magiclist[6]:='L';
   magiclist[7]:='V';
   magiclist[8]:='S';
   magiclist[9]:='8';
   magiclist[10]:='6';
   magiclist[11]:='i';
   end;

procedure printtempfile;

(*********************************************************************************

 procedure printtempfile;
 Purpose: This procedure outputs the appropriate information of a line to the 
          temporary file. ('end errors', location ctr, linetype, # operands &
	  the operands. 

 *********************************************************************************)

var i:integer;
   begin
   writeln(tempfile,'* end errors');
   writeln(tempfile,locctr,' lc');
   writeln(tempfile,linetype,' linetype');
   writeln(tempfile,opct,' operands');
   for i:=1 to opct do
      begin
      write(tempfile,optable[i].opkind);
      case optable[i].opkind of
         'A','H','I':writeln(tempfile);
         'N','D':writeln(tempfile,optable[i].maininfo.value);
         'L','V','8','6','i':writeln(tempfile,optable[i].maininfo.text);
         'S':writeln(tempfile,'"',optable[i].maininfo.string,'"');
      ELSE ;
      end;
   end;
   end;

procedure parseerror(index:integer);

(********************************************************************************
 
 procedure parseerror
 Purpose: This procedure outputs an error message to the tempfile given a unique
          number. If the number is >=10, it is a fatal error and the ignore line
          flag is raised.

 ********************************************************************************)
 
   begin
   if not ignoreflag then
   begin
   errct:=errct+1;
   case index of
      0:writeln(tempfile,'Warning- leading right parenthesis.');
      1:writeln(tempfile,'Warning- trailing left parenthesis.');
      2:writeln(tempfile,'Warning- missing closing right parenthesis.');
      3:writeln(tempfile,'Warning- leading commas before operand list.');
      4:writeln(tempfile,'Warning- extra comma(s).');
      5:writeln(tempfile,'Warning- missing comma between operands.');

      10:writeln(tempfile,'Error- operand label not defined. Ignoring line');
      11:writeln(tempfile,'Error- indirection error. Ignoring line.');
      13:writeln(tempfile,'Error- too many operands for instruction. Ignoring line.'); 
      14:writeln(tempfile,'Error- no operand found. Ignoring line.');
      15:writeln(tempfile,'Error- illegal instruction. ignoring line.');
      20:writeln(tempfile,'Error- no label field for EQU directive. Ignoring line.');
      22:writeln(tempfile,'Error- labelfield = operand label for EQU. Ignoring EQU.');
 31:writeln(tempfile,'Error- number too large or small for instruction. Ignoring line.');
     32:writeln(tempfile,'Error- label not absolute for DS instruction. Ignoring line.');
      33:writeln(tempfile,'Error- illegal operand for instruction. Ignoring line.');
     40:writeln(tempfile,'Error- label field not allowed for directive. Ignoring line.');
     41:writeln(tempfile,'Error- XREF operand already defined. Ignoring operand.');
    42:writeln(tempfile,'Error- XDEF operand already XDEFd or XREFd. Ignoring operand');
    43:writeln(tempfile,'Error- label field was previously XREFd. Ignoring line.');
    50:writeln(tempfile,'Error- label field already defined locally. Ignoring line.');
    51:writeln(tempfile,'Error- EQU operand was XREFd. Ignoring line.');

   end;
   end;
   if (index>=10) then
      begin
      linetype:=0;
      ignoreflag:=TRUE;
      end;
   end;

procedure skipcommas;

(********************************************************************************

 procedure skipcommas
 Purpose: This procedure counts and skips commas and returns the currtoken 'pointer'
          to the next non-comma token.

 ********************************************************************************)

   begin
   commact:=0;
   while(table[currtoken].token=comma) do
      begin
      currtoken:=currtoken+1;
      commact:=commact+1;
      end;
   end;

procedure processlabel;

(********************************************************************************

 procedure processlabel
 Purpose: This procedure processes the label by assigning the correct op. letter
          to the current index in the operand table. It also sets the boolean
          'direct' variable. (a label is understood as a number or number in
          parenthesis to the instruction table, so a boolean field is set)

 ********************************************************************************)

   begin
   if (currtoken>1) then
      begin
      if (table[currtoken-1].token=lparen) then		{label direct}
         begin
         magiclet:=magiclist[7];
         table[currtoken-1].direct:=FALSE;
         end
      else 						{label direct}
         begin
         magiclet:=magiclist[6];			
         table[currtoken].direct:=TRUE;
         end;
      end 
   else							{label direct}
      begin
      magiclet:=magiclist[6];
      table[currtoken].direct:=TRUE;
      end;
   end;

procedure processind; 

(********************************************************************************

 procedure processind
 Purpose: This procedure processes an indirection by assigning the appropriate op.    
	  letter to the operand table. 

 ********************************************************************************)
 
   begin
   currtoken:=currtoken+1;
   if (currtoken>numtok-1) then				{trailing left paren}
      begin
      parseerror(1);
      notoperand:=TRUE;
      end
   else
      case table[currtoken].token of
         number: magiclet:=magiclist[5];  
         lable:magiclet:=magiclist[7];
         hl:magiclet:=magiclist[3];
         reg16:magiclet:=magiclist[11];
      ELSE						{illegal indirection}
         begin
         parseerror(11);
         notoperand:=TRUE;
         end;
      end;
   currtoken:=currtoken+1;
   if (table[currtoken].token<>rparen) then		{missing right paren} 
      begin
      parseerror(2);				        {EXIT AT 2 CHAR AFTER LPAREN}
      notoperand:=TRUE;
      end;
   if not(notoperand) then				{legal operand- make sure} 
      back:=TRUE;					{assign to op table correct}
   end;							{operand by raising flag}

procedure filloptable;

(*******************************************************************************

 procedure filloptable
 Purpose: This procedure goes through the tokens and collects the logical operands
          and then puts them in the operand table. 

 *******************************************************************************)

var i:integer;
   begin
   currtoken:=1;
   skipcommas;
   if (currtoken>1) then				{leading commas}
      parseerror(3);
   commact:=1;
   while(currtoken<=numtok-1) do			{go thru tokens found and}
      begin						{collect operands}
      back:=FALSE;
      notoperand:=FALSE;
      ignoreflag:=FALSE;
      if (commact>1) then				{extra commas}
         parseerror(4);
      if (commact=0) then				{missing comma}
         parseerror(5);
     						        {HAVE OP BESIDES COMMA}
      case table[currtoken].token of
         lparen:processind;
         rparen:begin
                parseerror(0);
                notoperand:=TRUE;
                end;
         number:magiclet:=magiclist[4];
         string:magiclet:=magiclist[8];
         lable:processlabel;
         accum:magiclet:=magiclist[1];
         hl:magiclet:=magiclist[2];
         reg8:magiclet:=magiclist[9];
         reg16:magiclet:=magiclist[10];
      end;
   							{PUT IN OP TABLE}
      if not(notoperand) then
         begin
         opct:=opct+1;					{HAVE OPERAND}
         optable[opct].opkind:=magiclet;
         if (back) then					{account for indirection} 
            optable[opct].maininfo:=table[currtoken-1]  {confusion}
         else
            optable[opct].maininfo:=table[currtoken];
         end;
      currtoken:=currtoken+1;
      skipcommas;
      end;	{WHILE}

   if (commact>0) then
      parseerror(4);					{extra commas}
      
   end;
      
   
procedure processequ;

(********************************************************************************

 procedure processequ	'equate'
 Purpose: This procedure handles the EQU directive. Only one operand is legal. That
          operand can be a number or label( not in paren). If it is a label, it
          must exist already in the symbol table (so the value can be copied to the
          label field(which must be on this line)). 

 ********************************************************************************)
 
   begin
   if (emptyst(labelfield)) then
      parseerror(20)
   else							{Exists a labelfield}
   if (opct>1) then
      parseerror(13)
   else
   if (opct=0) then
      parseerror(14)					{no operands}
   else							{1 operand}
      if (optable[opct].opkind='N') then		{operand is number}
         begin
         elem.value:=optable[opct].maininfo.value;
         elem.isreloc:=FALSE;
	 elem.symboltext:=labelfield;
         replace(symboltable,elem);
         end
      else
      if (optable[opct].opkind='L') then		{operand is label}
         if (labelfield=table[opct].text) then		{labelfield cannot equal the}
            parseerror(22)				{label.}
         else
            begin
             				    {SEE IF OPERAND LABEL IS IN SYMBOL TABLE}
            elem.symboltext:=optable[opct].maininfo.text;
            globalfound:=FALSE;
            foundnode(symboltable,elem);
	    if (globalfound) then
               begin					{operand found in symbol table}
	       {copy its value from table to the label field and re-insert the label
		field into the symbol table}

               copynode(symboltable,optable[opct].maininfo.text,elem);
               copynode(symboltable,labelfield,elem2);
	       elem:=elem2;
               elem.isreloc:=FALSE;
               elem.symboltext:=labelfield;

	       if (elem.scope = 1) then
		  parseerror(51)
               else
	          replace(symboltable,elem);
               end
            else
	       begin
	       elem.isreloc:=FALSE;
               elem.symboltext:=labelfield;
	       elem.scope:=5;
	       elem.value:=0;
	       replace(symboltable,elem);
	       end;
            end;
   if (elem.scope = 5) and not(ignoreflag) then
      opct:=1
   else
      opct:=0;
   printtempfile;
   end;

procedure processds;

(*********************************************************************************
 
 procedure processds	'define space'
 Purpose: This procedure processes the DS directive. Only 1 operand is legal. 
          A number or label (not in paren) is allowed. If it is a label, it must
          be defined(found in the symbol table) and ABSOLUTE. The label's value
          or if the operand is a number must be >=0 and <= (2^15)-1. -(the maximum
          value to fit in a word.  

 ********************************************************************************)

 
   begin
   linetype:=-3;
   if (opct>1) then					{too many operands}
      parseerror(13)
   else
   if (opct<1) then					{no operand}
      parseerror(14) 
   else
   if (optable[opct].opkind='N') then			{have a number}
      begin
      if (optable[opct].maininfo.value<0) or (optable[opct].maininfo.value>MAXINT) then
         parseerror(31)					{number too large or small}
      else
         elem.value:=optable[opct].maininfo.value;
      end
   else
   if (optable[opct].opkind='L') then			{have a label}
      begin
							{search symbol table}
      globalfound:=FALSE;
      elem.symboltext:=optable[opct].maininfo.text;
      foundnode(symboltable,elem);
     { if not(globalfound) then
	 parseerror(10)
      else
         begin}						{found label in symbol table}
	 {get label's value from symbol table}

         copynode(symboltable,optable[opct].maininfo.text,elem);
         if (elem.value<0) or (elem.value>MAXINT) then
            parseerror(31)
         else
         if (elem.isreloc) then				{IS ABSOLUTE?}
            parseerror(32)
       {  end;}
      end  
   else
      parseerror(33);
   printtempfile;
   if not (ignoreflag) then				{update location ctr}
      locctr:=locctr+elem.value; 
   end;

procedure stringsize;

(*******************************************************************************

 procedure stringsize
 Purpose: This procedure returns the length of a string given of type constring.

 *******************************************************************************)
 
var i:integer;
   begin
   size:=0;
   i:=1;
   while (st[i]<>chr0) do
      begin
      size:=size+1;
      i:=i+1;
      end;
   end;
   
      
procedure processdb;

(*********************************************************************************

 procedure processdb   'define byte'
 Purpose: This procedure handles the DB directive. The location ctr is incremented
	  by the number of numbers and labels and the number of characters in a
	  string.

 *********************************************************************************)

var size,i:integer;
   begin
   templocctr:=locctr;
   linetype:=-1;
   if (opct<1) then					{no operands}
      parseerror(14)
   else
   for i:=1 to opct do					{update location ctr}
      case optable[i].opkind of 
         'N','L':templocctr:=templocctr+1;
         'S':begin
             stringsize(optable[i].maininfo.string,size);
             templocctr:=templocctr+size;
             end;
         ELSE
             parseerror(33);
      end;
   printtempfile;
   locctr:=templocctr;
   end;

procedure processdw;

(**********************************************************************************

 procedure processdw	'define word'
 Purpose: This procedure handles the DW directive by updating the location ctr by
	  two times the number of numbers ot labels in the operand list.

 **********************************************************************************)

var i:integer;
   begin
   templocctr:=locctr;
   linetype:=-2;
   if (opct<1) then					{no operands}
      parseerror(14) 
   else
   for i:=1 to opct do
      case optable[i].opkind of
         'N','L':templocctr:=templocctr+2;
      ELSE
         parseerror(33);
      end;
   printtempfile;
   locctr:=templocctr;
   end;

procedure processxref;

(*********************************************************************************

 procedure processxref
 Purpose: This procedure processes an XREF directive. The operands for the directive
	  must be inserted into the symbol table for later use. 

 *********************************************************************************)

var i:integer;
   begin
   linetype:=0;
   if (not(emptyst(labelfield))) then			{must be no label field}
      parseerror(40)
   else
   if (opct<1) then					{must be operands}
      parseerror(14)
   else
   for i:=1 to opct do					{do for all operands}
      if (optable[i].opkind = 'L') then
	 begin
	 {search to see if exists already}
	 globalfound:=FALSE;
	 elem.symboltext:=optable[i].maininfo.text;
	 foundnode(symboltable,elem);
	 if (globalfound) then				 {already defined}
	    parseerror(41)
         else
	    begin
            elem.scope:=1;				{insert an external}
	    elem.isreloc:=FALSE;
	    insert(symboltable,elem);
	    end;
	 end
      else
	 parseerror(33);
   printtempfile;
   end;

procedure processxdef;

(*********************************************************************************

 procedure processxdef
 Purpose: This procedure processes an XDEF directive. Like the XREF, the operand
	  label (if one or more) must be inserted into the symbol table for later
	  use.

 *********************************************************************************)

var i:integer;
   begin
   linetype:=0;
   if (not(emptyst(labelfield))) then			{must be no label field}
      parseerror(40)
   else
   if (opct<1) then					{must be operands}
      parseerror(14)
   else
   for i:=1 to opct do					{do for all operands}
      if (optable[i].opkind = 'L') then
	 begin
	 {search to see if exists already}
	 globalfound:=FALSE;
	 elem.symboltext:=optable[i].maininfo.text;
	 foundnode(symboltable,elem);
	 if (globalfound) then
	    begin
            copynode(symboltable,elem.symboltext,elem);
	    if (elem.scope <> 4) then			{not local}
	       parseerror(42)
            else
	    begin
	    elem.scope:=3;				{replace with global defined}
            replace(symboltable,elem);
	    end;
	    end
         else
	    begin
	    elem.scope:=2;				{insert a global undefined}
	    elem.symboltext:=optable[i].maininfo.text;
	    insert(symboltable,elem);
            end;
         end
      else
	 parseerror(33);
   printtempfile;
   end;

procedure checkglobalundef;

(*********************************************************************************

 procedure checkglobalundef
 Purpose: This procedure, called at the and of pass1, searches the symboltable for
	  undefined (non external) labels and outputs to the listing file the error.

 *********************************************************************************)

   begin
   if (bintree<>nil) then
      begin
      checkglobalundef(bintree^.left);
      if (bintree^.scope = 2) or (bintree^.scope = 5) then
	 begin
	 errct:=errct+1;
	 if (bintree^.scope = 2) then
            writeln(tempfile,'Error- global undefined label ',bintree^.symboltext)
         else
            writeln(tempfile,'Error- undefined label ',bintree^.symboltext);
	 end;
      checkglobalundef(bintree^.right);
      end;
   end;
	 
	 
procedure parseline;

(**********************************************************************************

 procedure parseline
 Purpose: This procedure is the driver of pass1. First, it puts a labelfield in the
          symbol table. Then, it calls filloptable to collect the operands. It then
          , if the mnemonic is not one of the four special directives, constructs
          the appropriate instruction string to search against in the instruction
          table. Is it is found, the location counter is updated accordingly. If
          the mnemonic is one of the special four directives, those routines are
          called. This routine is called line by line until EOF. 

 *********************************************************************************)

var i, 
    location:integer;
   begin
   globalfound:=FALSE;
   ignoreflag:=FALSE;
   currtoken:=1;
   opct:=0;
   linetype:=0;
   optable[1].opkind:=BLANK;
   optable[2].opkind:=BLANK; 

   if ((numtok-1)>0) then
      filloptable;				{FILL OPERAND TABLE}

  if (not(emptyst(labelfield))) and (not(ignoreflag)) then {put in symbol table} 
     begin 				
     globalfound:=FALSE;
     elem.symboltext:=labelfield;
     foundnode(symboltable,elem);
     if (globalfound) then   {already in symbol table}
	begin
        copynode(symboltable,labelfield,elem);
	case (elem.scope) of
	   1: parseerror(43);
	   4: parseerror(50);
	   ELSE begin				{replace with new attributes} 
                elem.scope:=3;
                elem.isreloc:=TRUE;
                elem.value:=locctr;
	        replace(symboltable,elem);
	        end;
	   end;
        end;
     if (not(ignoreflag)) then
	begin
	if not(globalfound) then		{will insert into symbol table}
	   begin
           elem.scope:=4;
           elem.isreloc:=TRUE;
           elem.value:=locctr;
           insert(symboltable,elem);
	   end;
	end;
     end;

  if (not(ignoreflag)) then
  if (mnemfield='DW      ') then		{special directive calls}
     processdw else
  if (mnemfield='DB      ') then
     processdb else
  if (mnemfield='DS      ') then
     processds else
  if (mnemfield='EQU     ') then
     processequ else
  if (mnemfield='XREF    ') then
     processxref else
  if (mnemfield='XDEF    ') then
     processxdef else

  begin						{have non-special directive instr.}
  if (opct>2) then
     parseerror(13);
  if not(ignoreflag) and not(emptyst(mnemfield)) then
     begin
     for i:=1 to 8 do				{construct instruction string}
        instruct[i]:=mnemfield[i];
     instruct[9]:=optable[1].opkind;
     instruct[10]:=optable[2].opkind;

     {if any of the operands is a label or a label in parenthesis, adjust the 
      unique letter for the instruction search.}

     for i:=1 to opct do				
        if (optable[i].maininfo.token=lable) then
           if optable[i].maininfo.direct then 
              instruct[i+8]:='N'
           else
              instruct[i+8]:='D';

     find_instruction(instruct,linetype);	{search for instruction}
     if (linetype=0) then			{instruction not found}
        parseerror(15)
     end
  else
     for i:=1 to 10 do				{clear instruction string}
        instruct[i]:=BLANK;
    
   printtempfile;
   if (linetype<>0) then			{if instruction found, update locctr}
      case instruction_table[linetype].itype of
         3,10:locctr:=locctr+2;
         9,12:locctr:=locctr+3;
         ELSE
              locctr:=locctr+1;
      end;
   end;
   optable[1].opkind:=BLANK;			{clear first and second opkinds}
   optable[2].opkind:=BLANK;
      
   end;

      
   
begin
initmagiclist;
rewrite(tempfile,'asmtemp');
end.		{unit pass1unit}
   
