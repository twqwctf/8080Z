{$X+}
unit treeunit;

(*******************************************************************************

 unit treeunit
 Contents: This unit contains all the basic binary search tree operations. 
           It also contains the declarations for the binary search tree
           accessed by pointers. 

 *******************************************************************************)

interface

type
   pointertype=^symbolrec;

   text8=packed array[1..8] of char;
   symbolrec=record			{symbol table node type}
      symboltext:text8;
      value,scope:integer;
      isreloc:boolean;
      left,right:pointertype;
   end;
 
   treetype=pointertype;

   byte=0..255;
   bytetype=file of byte;

var symboltable:treetype;
    elem,elem2:symbolrec;
    globalfound:boolean;
    listfile:text;
    bytefile:bytetype;


function lessthan    (elem:symbolrec;bintree:treetype):boolean;
function greaterthan (elem:symbolrec;bintree:treetype):boolean;

procedure createbintree(bintree:treetype);
procedure insert(var bintree:treetype;elem:symbolrec);
procedure replace(bintree:treetype;elem:symbolrec);
procedure foundnode(bintree:treetype;elem:symbolrec);
procedure copynode(bintree:treetype;txt:text8;var changeelem:symbolrec);
procedure printhex(var fileptr:text;num:integer);
procedure inorder(var fileptr:text;bintree:treetype);
procedure getnumglobals(bintree:treetype;var numglobals:integer);
procedure outeachglobal(bintree:treetype;var fileptr:bytetype);

implementation

function lessthan;

(******************************************************************************

 Function lessthan
 Purpose: returns boolean variable if the passed in elem is less than the
          current binary tree element based on the upc field.

 Called by: insert, delete

 ******************************************************************************)

   begin
   lessthan:=elem.symboltext<bintree^.symboltext;
   end;

function greaterthan;

(******************************************************************************

 Function greaterthan
 Purpose: returns boolean variable if the passed in elem is greater than the
          current binary tree element based on the upc field.   

 ******************************************************************************)

   begin
   greaterthan:=elem.symboltext>bintree^.symboltext;
   end;

procedure createbintree;

(******************************************************************************

 Procedure createbintree
 Purpose: This procedure creates a binary tree by setting it to NIL.

 Parameters: a binary tree
 Called by: reqandoperate
 Calls: none

 ******************************************************************************)
 
   begin
   bintree:=nil;
   end;

procedure replace;

(*******************************************************************************

 procedure replace
 Purpose: This procedure given an element of the type of elements in the symbol
	  table will replace the contents in the symbol table with the new elem.
	  Assume the elem is to be found in table.

 *******************************************************************************)

   begin
   if (bintree <> nil) then
      begin
      replace(bintree^.left,elem);
      if (bintree^.symboltext = elem.symboltext) then
         bintree^:=elem;
      replace(bintree^.right,elem);
      end;
   end;

procedure insert;

(******************************************************************************

 Procedure insert
 Purpose: This is a recursive procedure which inserts a passed in element
          in a binary tree.

 Parameters: a binary tree and an element.
 Calls: itself (recursive), lessthan, greaterthan, and the predefined new
        module.

 ******************************************************************************)
 
   begin
   if (bintree=nil)
      then
      begin
      new(bintree); 
      bintree^:=elem;
      bintree^.left:=nil;
      bintree^.right:=nil;
      end

      else
      if lessthan(elem,bintree)
         then
         insert(bintree^.left,elem)
         else 
         if greaterthan(elem,bintree)
            then
            insert(bintree^.right,elem);
   end;


procedure foundnode;

(********************************************************************************

 procedure foundnode
 Purpose: This procedure takes an elem(type symbolrec) and the binary tree and if
          the element is found in the tree, the global var globalfound is
          assigned TRUE.

 ********************************************************************************)

   begin
   if (bintree<>nil) then
      begin
      foundnode(bintree^.left,elem);
      if (bintree^.symboltext=elem.symboltext) then
         globalfound:=TRUE; 
      foundnode(bintree^.right,elem);
      end;
   end;

procedure copynode;

(********************************************************************************

 procedure copynode
 Purpose: This procedure accepts a string of type tokenstring. If its field 'symboltext'
          is found in the field in one of the nodes in the tree, the node's records
          is copied to the element 'elem' passed in.

 ********************************************************************************)
 
   begin
   if (bintree<>nil) then
      begin
      copynode(bintree^.left,txt,changeelem);
      if (bintree^.symboltext=txt) then
         changeelem:=bintree^;
      copynode(bintree^.right,txt,changeelem);
      end;
   end;

procedure printhex;

(********************************************************************************

 procedure printhex
 Purpose: This procedure, given a number, prints the number to the temporary file
          in hex.

 ********************************************************************************)

var numarray:packed array[1..4] of char;
base,worknum,closeto,rem,i:integer;
   begin
   for i:=1 to 4 do
      numarray[i]:='0';
   if (num<0) then
      begin
      num:=num*(-1);
      write(listfile,'-');
      end;
   while(num<>0) do
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
   write(fileptr,numarray);  (**)
   write(fileptr,' ');
   end;

procedure getnumglobals;

(**********************************************************************************

 procedure getnumglobals
 Purpose: This procedure determines the # of globals presently in the symbol table.

 **********************************************************************************)

   begin
   if (bintree<>nil) then
      begin
      getnumglobals(bintree^.left,numglobals);
      if (bintree^.scope = 3) then			{have global}
	 numglobals:=numglobals+1;
      getnumglobals(bintree^.right,numglobals);
      end;
   end;

procedure outeachglobal;

(**********************************************************************************

 procedure outeachglobal
 Purpose: This procedure traverses the symbol table searching for globals. If on a
	  global, its name, relocation flag(absolute or reloc) and its value are
	  outputed to the object file.

 **********************************************************************************)

var i:integer;
   begin
   if (bintree<>nil) then
      begin
      outeachglobal(bintree^.left,fileptr);
      if (bintree^.scope = 3) then			{have global}
	 begin
	 for i:=1 to 8 do				{output name}
	    write(fileptr,ord(bintree^.symboltext[i]));
	 if (bintree^.isreloc) then			{output relocation flag}
	    write(fileptr,255)
         else
	    write(fileptr,0);
         i:=bintree^.value mod 256;			{output value}
	 write(fileptr,i);   
	 i:=bintree^.value div 256;
	 write(fileptr,i);
	 end;
      outeachglobal(bintree^.right,fileptr);
      end;
   end;


procedure inorder;

(********************************************************************************

 procedure inorder
 Purpose: This procedure prints, inorder, the fields of the nodes of the binary
          tree.

 ********************************************************************************)

   begin
   if (bintree<>nil) then
      begin
      inorder(fileptr,bintree^.left);
      write(fileptr,bintree^.symboltext,'   ');
      if (bintree^.scope=1) or (bintree^.scope=2) or (bintree^.scope=5) then
	 write(fileptr,'                   ')
      else
	 begin
         if (bintree^.isreloc) then
            write(fileptr,'Relocatable   ') 
         else
            write(fileptr,'Absolute      ');
         printhex(fileptr,bintree^.value);
	 end;
      case (bintree^.scope) of
	 1: writeln(fileptr,'  external');
	 2: writeln(fileptr,'  global undefined');
	 3: writeln(fileptr,'  global defined');
	 4: writeln(fileptr,'  local');
	 5: writeln(fileptr,'  undefined.');
      end;
      inorder(fileptr,bintree^.right);
      end;
   end; 

begin
end.    (* unit treeunit *)
