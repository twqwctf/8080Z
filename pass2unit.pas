{$X+}
unit pass2unit;

(**********************************************************************************

 unit pass2unit  (part III of III of final assembler project)

 Purpose: This unit is responsible for taking the information provided by pass1-
	  being the output file 'asmtemp' and using it tp produce two new output
	  files, <infile>.lst and <infile>.obj. The first, the listing file is
	  a file consisting of each line of the source file accompanied with
	  the location counter of the beginning of a line and its first three bytes
	  of machine code for a line. At the end of the listing file is a display
	  of the symbol table and number of found errors. The second file, the
	  object file is the actual object that would be used for linking to produce
	  a final executable image. It is a file of byte type. The specific contents 
	  of the object file are explained in the pass2 assignment sheet. 
	     NOTES: If an error is found in a line, the program will generate zeros
		    where the code was intended to be written. 
		  **  BUG: the source file cannot contain any leading blank lines. The
			   problem is expected to be in the parsing procedure, 
			   parseline in pass1unit. 

 **********************************************************************************)

INTERFACE

uses itab, scanunit, treeunit, pass1unit;

type
   reloclisttype=^reloclistrec;			{'calls to relocatables' linked list} 

   reloclistrec = record
      info:symbolrec;
      next:reloclisttype;
   end;

   externallisttype=^externalrec;		{'calls to externals' linked list}

   externalrec = record
      name:tokenstring;
      byteref:boolean;
      value:integer;
      next:externallisttype;
   end;

   pass2outfile=text;				{output file type for listing file}

var 
   pass2lst:pass2outfile;			{output file for listing file}		
   firstop,secondop,oplab:tokenstring;		{operand identifiers}
   sourceline,					{entire input line from source file}
   opstr:constring;				{used to read a string(arbit. length)}			
   bytenum,					{a number represt'd as word-reversed}
   code,					{integer word of code}
   opvalue,					{an operand value}	
   encoding1,encoding2,				{register encodings ('E'=011)}
   lctr,stlen,numop:integer;
   numglobals,					{num of references to globals}
   numrelocations,				{num of references to relocatables}
   numexternals:integer;			{num of references to externals}

   opkind,opkind1,opkind2:char;			{an operand kind ('N','V'...)}
   nocode:boolean;				{produce no code boolean flag}
   reloclist,					{ptrs to ref. to relocatables link list}
   firstreloclist:reloclisttype;
   externallist,				{ptrs to ref. to externals linked list}
   firstexternallist:externallisttype;

procedure outline; 
procedure outglobalinfo;
procedure printrelocations;
procedure printexternals;

IMPLEMENTATION

procedure pass2error(index:integer);

(*********************************************************************************

 procedure pass2error
 Purpose: This procedure outputs an error message to the listing file found by
	  pass2 given a unique index.

 *********************************************************************************)

   begin
   errct:=errct+1;
   case index of
 1:writeln(pass2lst,'Error- DB operand too large to fit in byte (or neg). Ignoring op.');
 2:writeln(pass2lst,'Error- operand label never defined. Ignoring operand.');
 3:writeln(pass2lst,'Error- operand cannot be expressed in one byte. Ignoring op.');
 6:writeln(pass2lst,'Error- data operand must be of byte size. Ignoring line.');
 7:writeln(pass2lst,'Error- operand label not defined. Ignoring line.');
 8:writeln(pass2lst,'Error- illegal operand in line. Ignoring line.');
 9:writeln(pass2lst,'Error- too many operands in line. Ignoring line.');
 10: writeln(pass2lst,'Error- not enough operands in line. Ignoring line.');
 11: writeln(pass2lst,'Error- operand must fit in (signed) 4 bits. Ignoring line.');
 12: writeln(pass2lst,'Error- operand cannot be expressed in one word. Ignoring line.');
 13: writeln(pass2lst,'Error- DB operand cannot be relocatable. Ignoring operand.');
 14: writeln(pass2lst,'Error- DS: missing operand. Ignoring line.');
 15: writeln(pass2lst,'Error- DS: operand is >word or <0. Ignoring line.');
20: writeln(pass2lst,'Error- register not allowed for instruction. Ignoring line.');
21: writeln(pass2lst,'Error- reloc. operand label not allowed for inst. Ignoring line.');
22: writeln(pass2lst,'Error- operand label cannot be external. Ignoring line.');
   end;
   if (index>5) then
      nocode:=TRUE;
   end;

procedure addrelocation(var list: reloclisttype;elem:symbolrec);

(*********************************************************************************

 procedure addrelocation
 Purpose: This procedure adds a new node, elem to the relocatables linked list and
	  increments numrelocations.

 *********************************************************************************)

var ptrrec:reloclisttype;
   begin
   numrelocations:=numrelocations+1;
   new(ptrrec);					{assign to ptrrec, to be pointed to}
   ptrrec^.info:=elem;				{by the linked list eventually}
   ptrrec^.next:=NIL;
   if (list = NIL) then
      list:=ptrrec
   else  
      begin
      firstreloclist:=list;			{find next available position}
      while (firstreloclist^.next <> NIL) do
	 firstreloclist:=firstreloclist^.next;
      firstreloclist^.next:=ptrrec;
      end;

   end;

procedure addexternal(var list :externallisttype;name:tokenstring;                                             byteref:boolean;value:integer);

(*********************************************************************************

 procedure addexternal
 Purpose: This procedure adds a new node to the linked list of references to 
	  externals. It also traverses the linked list to determine if a new node
	  is being added to determine the actual number of unique externals.

 *********************************************************************************)

var ptrrec,ptr:externallisttype;
    notnew:boolean;
   begin
   notnew:=FALSE;
   ptr:=externallist;
   while (ptr<>NIL) do				{traverse list to help compute the}  
      begin					{numexternals}
      if (ptr^.name = name) then
	 notnew:=TRUE;
      ptr:=ptr^.next;
      end;
     
   new(ptrrec);
   ptrrec^.name:=name;				{assign to local ptr- will be pointed}
   ptrrec^.byteref:=byteref;			{to by list eventually}
   ptrrec^.value:=value;
   ptrrec^.next:=NIL;
   if (list = NIL) then
      list:=ptrrec
   else
      begin
      firstexternallist:=list;
      while (firstexternallist^.next <> NIL) do
	 firstexternallist:=firstexternallist^.next;
      firstexternallist^.next:=ptrrec;
      end;

   if (not(notnew)) then numexternals:=numexternals+1;
   end;

procedure checkthelabel(whichop:tokenstring);

(**********************************************************************************

 procedure checkthelabel
 Purpose: This procedure takes an operand label and determines whether it is a ref.
	  to a relocatable label or external label and then inserts into the 
	  appropriate list if so.

 **********************************************************************************)

var byteref:boolean;
   begin
   globalfound:=FALSE;
   elem.symboltext:=whichop;
   foundnode(symboltable,elem);
   if (globalfound) then
      begin
      copynode(symboltable,whichop,elem);
      if (elem.isreloc) then			{found relocatable}
	 begin
	 elem.value:=lctr+1;
	 addrelocation(reloclist,elem);
	 end;
      if (elem.scope = 1) then			{found external}
	 begin
	 if (linetype>0) then
	    case instruction_table[linetype].itype of	{compute byte or word reference}
	       9,12: byteref:=FALSE;
	       ELSE byteref:=TRUE;
               end
         else
	    case linetype of
	       -1,-3: byteref:=TRUE;
	       -2: byteref:=FALSE;
            end;
	 addexternal(externallist,elem.symboltext,byteref,lctr+1);
	 end;

      end
   else                     {not found - not external but assume to be relocatable}
      begin
      elem.value:=lctr+1;
      elem.symboltext:=whichop;
      {elem.isrec:=TRUE; 
      elem.scope:=4;}  
      addrelocation(reloclist,elem);
      end;
   end;
	 
procedure printhexbyte(var fileptr:text;num:integer);

(**********************************************************************************

 procedure printhexbyte
 Purpose: This procedure, given a file ptr and a num, outputs the hex byte to the file
	  pointed to by fileptr.

 **********************************************************************************)

var numarray:packed array[1..2] of char;
base,worknum,closeto,rem,i:integer;
   begin
   for i:=1 to 2 do
      numarray[i]:='0';
   while (num<>0) do
      begin
      worknum:=num;
      num:=num div 16;
      closeto:=16*num;
      rem:=worknum-closeto;
      if (rem>9) then
	 numarray[i]:=chr(rem+55) 
      else
	 numarray[i]:=chr(rem+48);
      i:=i-1;
      end;
   write(fileptr,numarray,' ');
   end;

procedure computedb(var code:integer);

(************************************************************************************

 procedure computedb
 Purpose: This procedure computes the object code for a DB directive and outputs it
	  to the listing and objext files.  

*************************************************************************************)

var size,i:integer;
   begin
   printhex(pass2lst,lctr);
   for i:=1 to numop do			
      begin
      code:=0;
      read(tempfile,opkind);
      if (opkind = 'N') then				        {operand is number}
         begin
         readln(tempfile,opvalue);
         if (opvalue>255) or (opvalue<0) then
	    pass2error(1)
         else
	    code:=code+opvalue;
         end
      else
      if (opkind = 'L') then
         begin							{operand is label}
	 readln(tempfile,oplab);
	 checkthelabel(oplab);
	 globalfound:=FALSE;
	 elem.symboltext:=oplab;
	 foundnode(symboltable,elem);
	 if (globalfound) then				{label found in symbol table}
	    begin
	    copynode(symboltable,oplab,elem);
	    if (elem.scope = 2) or (elem.scope = 5) then    {op not defined}
	       pass2error(2) else
            if (elem.isreloc) and (elem.scope <> 1) then
	       pass2error(13) else
	    if (elem.value>255) or (elem.value < 0) then
	       pass2error(1) 
            else
	       code:=code+elem.value;
            end
         else
	    pass2error(7);
         end
      else
      if (opkind = 'S') then				{operand is string}
         begin
         readln(tempfile,opstr);   
         stringsize(opstr,size);
         code:=code+(8*(size-1));
         end
      else
         pass2error(2);
      if (nocode) then
	 code:=0;
      if (i<4) then
         printhexbyte(pass2lst,code);
      write(bytefile,code);

      end; {for loop}
   end;

procedure computedw(var code:integer); 

(**********************************************************************************

 procedure computedw
 Purpose: This procedure computes the object code for a DW directive and outputs the
	  code to the listing and object files.

 **********************************************************************************)

var i,j,rev1,rev2:integer;
   bytearray:array[1..32] of integer;
   begin
   j:=1;
   for i:=1 to numop do
      begin
      code:=0;
      read(tempfile,opkind);
      if (opkind = 'N') then				{operand is number}
	 begin
	 readln(tempfile,opvalue);
	 if (opvalue>MAXINT) or (opvalue<MININT) then
	    pass2error(3) 
         else
	    code:=code+(2*opvalue);
	 end
      else    {= 'L'}					{operand is label}
	 if (opkind = 'L') then
	 begin
	 readln(tempfile,oplab);
	 checkthelabel(oplab);
	 globalfound:=FALSE;
	 elem.symboltext:=oplab;
	 foundnode(symboltable,elem);
	 if (globalfound) then				{op. found in symbol table}
	    begin
	    copynode(symboltable,oplab,elem);
	    if (elem.scope = 2) or (elem.scope = 5) then  {op. not defined}
	       pass2error(2) else
	    if (elem.value>MAXINT) or (elem.value < MININT) then
	       pass2error(3) 
            else
	       code:=code+(2*elem.value);
            end
         else
	    pass2error(7);
         end
      else
	 pass2error(8);
      if (nocode) then
	 code:=0;
      rev1:=code mod 256;				{compute & print object code}
      write(bytefile,rev1);				{in word-reversed}
      rev2:=code div 256;
      write(bytefile,rev2);
      bytearray[j]:=rev1;
      bytearray[j+1]:=rev2;
      j:=j+2;
      end; {for}
      printhex(pass2lst,lctr);

      if (numop>1) then
	 for i:=1 to 3 do
            printhexbyte(pass2lst,bytearray[i])
      else
	 for i:=1 to 2 do
            printhexbyte(pass2lst,bytearray[i]);
   end;
 
procedure computeds(var code:integer);

(**********************************************************************************

 procedure computeds
 Purpose: This procedure computes the object code for the DS directive and outputs it
	  to the listing and object files.

 **********************************************************************************)

var i:integer;
   begin
   if (numop>1) then
      begin
      pass2error(9);
      for i:=1 to numop do
	 readln(tempfile);
      end else
   if (numop<1) then
      pass2error(14) else
   begin
   read(tempfile,opkind1);
   if (opkind1<>'N') and (opkind1<>'L') then		
      pass2error(8) else
   if (opkind1 = 'L') then				{operand is label}
      begin
      readln(tempfile,firstop);
      checkthelabel(firstop);
      globalfound:=FALSE;
      elem.symboltext:=firstop;
      foundnode(symboltable,elem);
      if (globalfound) then				{operand found in symbol table}
	 begin
	 copynode(symboltable,elem.symboltext,elem);
	 if (elem.scope = 2) or (elem.scope = 5) then
	    pass2error(2);
	 opvalue:=elem.value;
	 end 
      else
	 pass2error(7);
      end
   else
      readln(tempfile,opvalue);
	 
   if (opvalue>MAXINT) or (opvalue<0) then
      pass2error(15) else
   begin
   printhex(pass2lst,lctr);
   for i:=1 to opvalue do				{compute & print object code}
      begin
      if (i<4) then
	 printhexbyte(pass2lst,0);
      write(bytefile,0);
      end;
   end;
   end;
   end;

procedure getencoding(register:tokenstring;var encoding:integer);

(**********************************************************************************

 procedure getencoding
 Purpose: This procedure takes a register and returns its numeric value to compute
	  the object code of an instruction.

 **********************************************************************************)

   begin
   if (ord(register[2])=0) then
      case register[1] of
	 'B':encoding:=0;
	 'C':encoding:=1;
	 'D':encoding:=2;
	 'E':encoding:=3;
	 'H':encoding:=4;
	 'L':encoding:=5;
      end
   else
   case register[2] of
      'C':encoding:=0;
      'E':encoding:=1;
      'P','F':encoding:=3;
   end;
   end;
 
procedure computetype2;

(*********************************************************************************

 procedure computetype2
 Purpose: This procedure computes and prints the object code for an instruction of
	  type 2.

 *********************************************************************************)

   begin
   printhex(pass2lst,lctr);
   if (numop<2) then
      pass2error(10)
   else
      begin
      getencoding(firstop,encoding1);
      getencoding(secondop,encoding2);
      code:=instruction_table[linetype].base+(8*encoding1)+(encoding2);
      end;
   if ((nocode)) then
      code:=0;
   printhexbyte(pass2lst,code);
   write(bytefile,code);
   end;

procedure computetype3;

(*********************************************************************************

 procedure computetype3;
 Purpose: This procedure computes and outputs the object code for an instruction of
	  type 3.

 *********************************************************************************)

   begin
   printhex(pass2lst,lctr);
   if (numop<2) then
      pass2error(10)
   else
      begin
      getencoding(firstop,encoding1);
      if (opkind2 = 'N') then				{operand is number}
         begin
         bytenum:=opvalue;
         if (opvalue>255) or (opvalue< -127) then
	    pass2error(6);
         end
      else		{='L'}				{operand is label}
         begin
         globalfound:=FALSE;
         elem.symboltext:=secondop;
         foundnode(symboltable,elem);
         if (globalfound) then			{operand label found in sym. table}
            begin
            copynode(symboltable,secondop,elem);
            bytenum:=elem.value;
            if (elem.value>255) or (elem.value< -12) then
	       pass2error(6)
            else if (elem.isreloc) then pass2error(21) else
            if (elem.scope=2) or (elem.scope=5) then
	       pass2error(7)
         else
            pass2error(7);
         end; 
      end;
   code:=instruction_table[linetype].base+(8*encoding1);
   end;

   if (nocode) then begin
      code:=0;
      bytenum:=0;
      end;
   printhexbyte(pass2lst,code);				{output object code}
   write(bytefile,code);				{word reversed}
   write(bytefile,bytenum mod 256);
   printhexbyte(pass2lst,bytenum mod 256);
   end;

procedure computetype4;

(**********************************************************************************

 procedure computetype4
 Purpose: This procedure computes and outputs the object code for an instruction of
	  type 4.

 **********************************************************************************)

   begin
   printhex(pass2lst,lctr);
   getencoding(firstop,encoding1);
   code:=instruction_table[linetype].base+(8*encoding1);
   printhexbyte(pass2lst,code);
   write(bytefile,code);
   end;

procedure computetype5;

(**********************************************************************************

 procedure computetype5
 Purpose: This procedure computes and outputs the object code for an instruction of
	  type5.

 **********************************************************************************)

   begin
   printhex(pass2lst,lctr);
   if (numop>1) then
      pass2error(9)
   else
   begin
   if (opkind1='N') then				{operand is number}
      if (opvalue<0) or (opvalue>7) then
	 pass2error(11);
   if (opkind1='L') then				{operand is label}
      begin
      globalfound:=FALSE;
      elem.symboltext:=firstop;
      foundnode(symboltable,elem);
      if (globalfound) then			     {operand label found in sym. table}
         if (elem.value<0) or (elem.value>7) then
	    pass2error(11) else                         {check reloc}{externals illegal}
         if (elem.scope = 1) then pass2error(22) else	{if external}
	 if (elem.isreloc) then pass2error(21) 		{if relocatable}
         else
	    opvalue:=elem.value
      else
         pass2error(7);
      end;
   end;
   code:=instruction_table[linetype].base + (8*opvalue);
   if (nocode) then code:=0;
   printhexbyte(pass2lst,code);
   write(bytefile,code);
   end;

procedure computetype6;

(**********************************************************************************

 procedure computetype6 
 Purpose: This procedure computes and outputs the object code for an instruction of
	  type 6.

 **********************************************************************************)

   begin
   printhex(pass2lst,lctr);
   if (instruction_table[linetype].reg_op_num = 2) then
	 if (secondop[2]='F') then			{'AF' register- illegal}
	    pass2error(20) else
         begin
         getencoding(secondop,encoding2);
	 code:=instruction_table[linetype].base + (16*encoding2);
	 end
   else
	 if (firstop[2]='F') then			{'AF' register- illegal}
	    pass2error(20) else
         begin 
         getencoding(firstop,encoding1);
	 code:=instruction_table[linetype].base + (16*encoding1);
	 end;
   if (nocode) then code:=0;     
   printhexbyte(pass2lst,code);
   write(bytefile,code);
   end; 

procedure computetype7;

(***********************************************************************************

 procedure computetype7
 Purpose: This procedure computes and outputs the object code for an instruction of
	  type 7.

 ***********************************************************************************)

   begin
   printhex(pass2lst,lctr);
   if (firstop[2]='P') then			{'SP' register illegal}
      pass2error(20) else
   begin 
   getencoding(firstop,encoding1);
   code:=instruction_table[linetype].base + (16*encoding1);
   if (nocode) then code:=0;     
   printhexbyte(pass2lst,code);
   write(bytefile,code);
   end;
   end;

procedure computetype8;

(***********************************************************************************

 procedure computetype8
 Purpose: This procedure computes and outputs the object code for an instruction of
	  type8.

 ***********************************************************************************)

   begin
   printhex(pass2lst,lctr);
   if (instruction_table[linetype].reg_op_num = 2) then
      if (secondop[2]='P') or (secondop[2]='F') then	   {'SP','AF' illegal}
	 pass2error(20) else
      begin 
      getencoding(secondop,encoding2);
      code:=instruction_table[linetype].base + (16*encoding2);
      end
   else
      if (firstop[2]='P') or (firstop[2]='F') then	   {'SP','AF' illegal}
	 pass2error(20) else
      begin
      getencoding(firstop,encoding1);
      code:=instruction_table[linetype].base + (16*encoding2);
      end;
   if (nocode) then code:=0;     
   printhexbyte(pass2lst,code);
   write(bytefile,code);
   end;

procedure computetype131415;

(***********************************************************************************

 procedure computetype131415;
 Purpose: This procedure computes and outputs the object code for an instruction of
	  type 13, 14 or 15.

 ***********************************************************************************)

   begin
   printhex(pass2lst,lctr);
   if (instruction_table[linetype].reg_op_num = 2) then
      case instruction_table[linetype].itype of
	 13,15: if (secondop[2] <> 'P') then pass2error(20); {all 16reg but 'SP' illegal}
	 14: if (secondop[2] <> 'E') then pass2error(20);    {all 16reg but 'DE' illegal}
      end
   else
      case instruction_table[linetype].itype of
	 13,15: if (firstop[2] <> 'P') then pass2error(20);  {same as above}
	 14: if (firstop[2] <> 'E') then pass2error(20);
      end;

   if (nocode) then code:=0;     
   code:=instruction_table[linetype].base;
   printhexbyte(pass2lst,code);
   write(bytefile,code);
   end;

procedure computetype9;

(**********************************************************************************
  
 procedure computetype9
 Purpose: This procedure computes and outputs object code for an instruction of 
	  type 9.

 **********************************************************************************)

   begin
   printhex(pass2lst,lctr);
   if (opkind2 = 'N') then					{op is number}
      bytenum:=opvalue
   else
      begin							{op is label}
      globalfound:=FALSE;
      elem.symboltext:=secondop;
      foundnode(symboltable,elem);
      if (globalfound) then
	 begin
	 copynode(symboltable,secondop,elem);
	 bytenum:=elem.value;
	 end
      else
	 pass2error(7); 
      end;
   if (bytenum>MAXINT) or (bytenum<MININT) then pass2error(12); 
   if (firstop[2] = 'F') then pass2error(20);			{register 'AF' illegal}
   getencoding(firstop,encoding1);
   code:=instruction_table[linetype].base + (16*encoding1);
   if (nocode) then begin
      code:=0;
      bytenum:=0;
      end;
   printhexbyte(pass2lst,code);					{output word reversed}
   write(bytefile,code);
   write(bytefile,bytenum mod 256);
   printhexbyte(pass2lst,bytenum mod 256);
   write(bytefile,bytenum div 256);
   printhexbyte(pass2lst,bytenum div 256)
   end;

procedure computetype1012;

(**********************************************************************************

 procedure computetype1012
 Purpose: This procedure computes and outputs the ocject code for an instruction of
	  type 10 or 12.

 **********************************************************************************)

   begin
   printhex(pass2lst,lctr);
   code:=instruction_table[linetype].base;
   if (instruction_table[linetype].data_op_num = 2) then
      if (opkind2 = 'N') or (opkind2 = 'D') then	{num or num in paren}
         bytenum:=opvalue
      else						{op is label}
	 begin
	 globalfound:=FALSE;
	 elem.symboltext:=secondop;
	 foundnode(symboltable,elem);
	 if (globalfound) then begin			{op label in symbol table}
	    copynode(symboltable,secondop,elem);
	    bytenum:=elem.value;
	    end
         else
	    begin
	    pass2error(7);
	    bytenum:=0;
	    end;
         end
   else
      if (opkind1 = 'N') or (opkind1 = 'D') then	{nearly identical to above}
	 bytenum:=opvalue
      else
	 begin
	 globalfound:=FALSE;
	 elem.symboltext:=firstop;
	 foundnode(symboltable,elem);
	 if (globalfound) then begin
	    copynode(symboltable,firstop,elem);
	    bytenum:=elem.value;
	    end
         else
	    begin
	    pass2error(7);
	    bytenum:=0;
	    end;
         end;

   if (instruction_table[linetype].itype = 10) then	{check limits of op value}
      if (bytenum>255) or (bytenum<-127) then pass2error(6)
   else
      if (bytenum>MAXINT) or (bytenum<MININT) then pass2error(6);
   if (nocode) then begin
      code:=0;
      bytenum:=0;
      end;

   printhexbyte(pass2lst,code);				{output object code}
   write(bytefile,code);
   printhexbyte(pass2lst,bytenum mod 256);
   write(bytefile,bytenum mod 256);
   if (instruction_table[linetype].itype = 12) then begin
      printhexbyte(pass2lst,bytenum div 256);
      write(bytefile,bytenum div 256);
      end;
   end;

procedure computetype11;

(**********************************************************************************

 procedure computetype11
 Purpose: This procedure computes and outputs the object code for an instruction of
	  type 11.

 **********************************************************************************)

   begin
   printhex(pass2lst,lctr);
   getencoding(secondop,encoding2);			{get encoding for register}
   code:=instruction_table[linetype].base + encoding2;
   printhexbyte(pass2lst,code);
   write(bytefile,code);
   end;

procedure readoperand(opkind:char; var whichop:tokenstring);

(**********************************************************************************

 procedure readoperand
 Purpose: This procedure, based on a unique operand kind, reads in the appropriate
	  operand.

 **********************************************************************************)

   begin
   case opkind of
      'N','D': readln(tempfile,opvalue);
      'S':     readln(tempfile,opstr);
      'L','V','8','6','i': readln(tempfile,whichop);
   ELSE readln(tempfile);
   end;
   end;

procedure printrelocations;

(**********************************************************************************

 procedure printrelocations
 Purpose: This procedure prints the number of references to relocatables and the
	  address of each as stored in the relocations linked list.

 **********************************************************************************)

var ptr:reloclisttype;
   begin
   write(bytefile,numrelocations mod 256); {# relocations}
   write(bytefile,numrelocations div 256);
   ptr:=reloclist;
   while (ptr<>nil) do 
      begin
      write(bytefile,ptr^.info.value mod 256);
      write(bytefile,ptr^.info.value div 256);
      ptr:=ptr^.next;
      end;
   end;

procedure outexternalrefinfo(name:tokenstring);

(**********************************************************************************

 procedure outexternalrefinfo 
 Purpose: This procedure computes & prints the number of references to the external 
	  label passed in, and for each reference, outputs its reference size
	  (byte or word) and its address.

 **********************************************************************************)

var ptr:externallisttype;
numref:integer;
   begin
   ptr:=externallist;
   while (ptr<>NIL) do					{traverse externals list to} 
      begin						{find number of refer to <name>}
      if (ptr^.name = name) then
	 numref:=numref+1;
      ptr:=ptr^.next;
      end;
   write(bytefile,numref mod 256);                      {output # of references}
   write(bytefile,numref div 256);
   ptr:=externallist;
   while (ptr<>NIL) do		                        {traverse externals list again}	
      begin
      if (ptr^.name = name) then			{if name matches with node}
	 begin
	 if (ptr^.byteref) then
	    write(bytefile,0)
	 else  			                        {write reference size}
	    write(bytefile,255);
         write(bytefile,ptr^.value mod 256);            {reference address}
         write(bytefile,ptr^.value div 256);            {reference address}
	 end;
      ptr:=ptr^.next;
      end;
   end;

function exterinlist(var list:externallisttype;name:tokenstring):boolean;

(**********************************************************************************

 function exterinlist;
 Purpose: This function returns TRUE if the name passed in is found in the externals
	  linked list.

 **********************************************************************************)

var ptr:externallisttype;
   begin
   exterinlist:=FALSE;
   ptr:=externallist;
   while (ptr<>NIL) do
      begin
      if (ptr^.name = name) then
	 exterinlist:=TRUE;
      ptr:=ptr^.next;
      end;
   end;
 
      
procedure outeachexternal(bintree:treetype);

(**********************************************************************************

 procedure outeachexternal 
 Purpose: This procedure traverses the symbol table looking for labels that might be
	  in the externals linked list. If so, the procedure outputs the name
	  of the external and then calls outexternalrefinfo to output further
	  information.

 **********************************************************************************)

var i:integer;
   begin
   if (bintree<>NIL) then
      begin
      outeachexternal(bintree^.left);
      if (bintree^.scope = 1) then		{if is external}
	 begin
	 if (exterinlist(externallist,bintree^.symboltext)) then
            for i:=1 to 8 do
	       write(bytefile,ord(bintree^.symboltext[i]));
         outexternalrefinfo(bintree^.symboltext);
	 end;
      outeachexternal(bintree^.right);
      end;
   end;

procedure printexternals;

(**********************************************************************************

 procedure printexternals
 Purpose: This procedure is the 'driver' of the handling of outputing info on the
	  externals. It outputs to the object file the number of externals and
	  then calls the other external routines for more output.

 **********************************************************************************)

   begin
   write(bytefile,numexternals mod 256);
   write(bytefile,numexternals div 256);
   outeachexternal(symboltable);
   end;

procedure outglobalinfo;

(***********************************************************************************

 procedure outglobalinfo
 Purpose: This procedure outputs to the object file the number of global labels and
	  then calls outeachglobal to output more information to the object file. 
	  Next, the # of bytes of machine code is outputed to the object file.
	  The actual object code will follow.

 ***********************************************************************************)

var objsuff:string5;
    newfile:string256;
   begin
   objsuff:='.obj ';
   objsuff[5]:=chr0;
   newfile:=rootfilename;
   append(newfile,objsuff,infilelen);
   rewrite(bytefile,newfile);				{open object file for writing}
   getnumglobals(symboltable,numglobals);
   write(bytefile,numglobals mod 256);			{output num of globals}
   write(bytefile,numglobals div 256);

   outeachglobal(symboltable,bytefile);
   write(bytefile,locctr mod 256);    	       	        {# bytes machine code}
   write(bytefile,locctr div 256);
   end;
   

procedure outline;

(***********************************************************************************

 procedure outline
 Purpose: This procedure is the 'driver' of pass2. It reads from 'asmtemp' to retrieve
	  the information about a line. Then, depending on the type of instruction,
	  the appropriate object code of a line is produced(if the line is legal).
	  Then, the actual source line is outputed to the listing file.

 ***********************************************************************************)

var linectr,i:integer;
   begin
   reset(tempfile,'asmtemp');
   reset(sourcefile,infile);
   reloclist:=NIL;
   externallist:=NIL;
   while (not(eof(tempfile))) do		{while not eof in asmtemp, do}
      begin
      code:=0;
      nocode:=FALSE;
      readln(tempfile,inline);
      while(inline[1] <> '*') and (not(eof(tempfile))) do    {HAVE ERRORS} 
	 begin
         writeln(pass2lst,inline);
         readln(tempfile,inline);
	 nocode:=TRUE;
	 end;
      if (not(eof(sourcefile))) then
         readln(sourcefile,sourceline);
      linectr:=linectr+1;
      readln(tempfile,lctr);				{read the location counter} 
      readln(tempfile,linetype);			{read the linetype}
      readln(tempfile,numop);				{read the num of ops}
      if (linetype = 0) then				{no code produced}
	 begin
         printhex(pass2lst,lctr);
	 for i:=1 to numop do
	    readln(tempfile);
         end
      else
      if (linetype = -1) then   	{DB}
	 computedb(code) else
      if (linetype = -2) then		{DW}
	 computedw(code) else
      if (linetype = -3) then		{DS}
	 computeds(code) else
      if (linetype = -10) then		{at end of file}
	 else

      if (numop>2) then
	 pass2error(9)
      else
      begin
      if (numop>0) then					{read appropriate operands}
	 begin
         read(tempfile,opkind1);
         readoperand(opkind1,firstop);
         if (numop>1) then
	    begin
	    read(tempfile,opkind2);
            readoperand(opkind2,secondop);
	    end;
         end;

      if (numop>0) then		                    {if necessary, call checkthelabel}
         if (opkind1='L') or (opkind1='V') then
	    checkthelabel(firstop);
      if (numop>1) then
         if (opkind2='L') or (opkind2='V') then
	    checkthelabel(secondop);

      case instruction_table[linetype].itype of
	 1: begin
            printhex(pass2lst,lctr);
	    write(pass2lst,' ');
	    code:=instruction_table[linetype].base;
            printhexbyte(pass2lst,code);
	    write(bytefile,code);
	    end;
	 2: computetype2;              {additional object code}
	 3: computetype3;		  {ll}
         4: computetype4;
	 5: computetype5;
	 6: computetype6;
	 7: computetype7;
	 8: computetype8;
	 9: computetype9;		  {ll hh}
	 10,12: computetype1012;	  {10- ll    12- ll hh}
	 11: computetype11;
	 13,14,15: computetype131415;
      end;
      end; 

      if (linetype <> -10) then
         writeln(pass2lst, linectr,': ', sourceline);

      end;
   end;

begin
end.   {unit pass2unit}
