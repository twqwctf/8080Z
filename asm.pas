{$X+}
program asm;

(*********************************************************************************

 Program asm 
 CS 2504 Programming assignment ^ (MAC II)
 Greg Fudala
 xxx-xx-xxxx
 Joerg Weimar
 3:30

 Purpose: This is the main driver of the final 8080z assembler project. 

 ********************************************************************************)

USES itab,scanunit,treeunit,pass1unit,pass2unit;

var listsuff,tempsuff:string5;
    tempfilename:string256;

begin    {main driver}

   writeln('8080Z Assembler. Written by Greg Fudala. Joerg Weimar - 3:30');
   writeln('------------------------------------------------------------');
   getfile;						{get source filename an open}
   listsuff:='.lst ';
   listsuff[5]:=chr0;
   tempsuff[1]:=chr0;
   tempfilename:=rootfilename;
   append(rootfilename,tempsuff,infilelen);
   append(tempfilename,listsuff,infilelen);
   rewrite(pass2lst,tempfilename);
   writeln('Assembling "',infile,'" with listing in "',rootfilename,'.lst"');
   writeln('   and object code in "',rootfilename,'.obj"');
   while (not eof(sourcefile)) do			{while not eof, process lines}
      begin
      readln(sourcefile, inline);
      inline[MAXLINELEN]:=endline;                      {to insure end of line}
      processline(linect);
      parseline;
      clrdata(labelfield,mnemfield);
      end;
   checkglobalundef(symboltable);
   linetype:=-10;
   opct:=0;
   printtempfile;
   writeln;
   close(tempfile);
   close(sourcefile);
   close(listfile);
   outglobalinfo;
   outline;
   writeln(pass2lst,'Symbol     Type         Value   Scope');
   writeln(pass2lst,'---------  -----------  -----   -----');
   inorder(pass2lst,symboltable);
   writeln(pass2lst);
   writeln(pass2lst,'There were ',errct,' errors.');
   writeln('There were ',errct,' errors.');
   printrelocations;
   printexternals;


end.   {main driver}

