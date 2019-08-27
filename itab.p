
{$X+}

unit itab;

interface

const
	NUM_INSTRUCTIONS = 117;

type
	mnem_ops_type = packed array [1..10] of char;
	instruction_rec = record
		mnem_ops : mnem_ops_type;
		itype, reg_op_num, data_op_num, base : integer;
		used : boolean;
	end; { record }

var
	instruction_table : array [1..NUM_INSTRUCTIONS] of instruction_rec;

procedure find_instruction (target : mnem_ops_type; var posn : integer);

implementation

procedure find_instruction { target : mnem_ops_type; var posn : integer } ;

(********************************************************************************

 Procedure find_instruction
 Purpose: This procedure searches the instruction table given a unique string. If
          the instruction is found, its position in the instruction table array is
          returned, else, 0 is returned.

 ********************************************************************************)

var here:boolean;
midpt,first,last:integer;
	begin { procedure find_instruction }
        here:=FALSE;
        first:=1;
        last:=NUM_INSTRUCTIONS;
        while(first<=last) and not here do
           begin
           midpt:=(first+last)div 2;
           if (instruction_table[midpt].mnem_ops=target) then
              here:=TRUE 
           else
              if (instruction_table[midpt].mnem_ops>target) then
                 last:=midpt-1
              else
                 first:=midpt+1;
           end;
        if here then
           posn:=midpt
        else
           posn:=0;

		{ YOU fill this in! }
	end;  { procedure find_instruction }

procedure init_table;

	type
		string8 = packed array [1..8] of char;

	var
		inum : integer;

	procedure add_instruction (mnem : string8; op1, op2 : char;
			new_itype, new_reg_op, new_data_op : integer; new_base : string8);

		var
			i : integer;

		begin { procedure add_instruction }
			inum := inum + 1;
			with instruction_table[inum] do begin
				for i := 1 to 8 do
					mnem_ops[i] := mnem[i];
				mnem_ops[ 9] := op1;
				mnem_ops[10] := op2;
				if inum > 1 then
					if mnem_ops < instruction_table[inum - 1].mnem_ops then
						writeln ('Order error in entry ', inum : 1);
				itype := new_itype;
				reg_op_num := new_reg_op;
				data_op_num := new_data_op;
				base := 0;
				for i := 1 to 8 do
					if new_base[i] = '1' then
						base := 2 * base + 1
					else
						base := 2 * base;
				used := FALSE;
			end; { with }
		end;  { procedure add_instruction }

	begin { procedure init_table }
		inum := 0;
		{-----------------------------------------------------------}
		add_instruction ('ADC     ', 'A', '8', 11, 2, 0, '10001xxx'); { ADC r8 }
		add_instruction ('ADC     ', 'A', 'A',  1, 0, 0, '10001111'); { ADC A }
		add_instruction ('ADC     ', 'A', 'I',  1, 0, 0, '10001110'); { ADC M }
		add_instruction ('ADC     ', 'A', 'N', 10, 0, 2, '11001110'); { ACI n }
		add_instruction ('ADC     ', 'H', '6',  6, 2, 0, '00xx1001'); { DAD rp }
		add_instruction ('ADC     ', 'H', 'H',  1, 0, 0, '00101001'); { DAD H }
		{-----------------------------------------------------------}
		add_instruction ('ADD     ', 'A', '8', 11, 2, 0, '10000xxx'); { ADD r8 }
		add_instruction ('ADD     ', 'A', 'A',  1, 0, 0, '10000111'); { ADD A }
		add_instruction ('ADD     ', 'A', 'I',  1, 0, 0, '10000110'); { ADD M }
		add_instruction ('ADD     ', 'A', 'N', 10, 0, 2, '11000110'); { ADI n }
		{-----------------------------------------------------------}
		add_instruction ('AND     ', 'A', '8', 11, 2, 0, '10100xxx'); { ANA r8 }
		add_instruction ('AND     ', 'A', 'A',  1, 0, 0, '10100111'); { ANA A }
		add_instruction ('AND     ', 'A', 'I',  1, 0, 0, '10100110'); { ANA M }
		add_instruction ('AND     ', 'A', 'N', 10, 0, 2, '11100110'); { ANI n }
		{-----------------------------------------------------------}
		add_instruction ('CALL    ', 'N', ' ', 12, 0, 1, '11001101'); { CALL n }
		add_instruction ('CALLC   ', 'N', ' ', 12, 0, 1, '11011100'); { CC n }
		add_instruction ('CALLM   ', 'N', ' ', 12, 0, 1, '11111100'); { CM n }
		add_instruction ('CALLNC  ', 'N', ' ', 12, 0, 1, '11010100'); { CNC n }
		add_instruction ('CALLNZ  ', 'N', ' ', 12, 0, 1, '11000100'); { CNZ n }
		add_instruction ('CALLP   ', 'N', ' ', 12, 0, 1, '11110100'); { CP n }
		add_instruction ('CALLPE  ', 'N', ' ', 12, 0, 1, '11101100'); { CPE n }
		add_instruction ('CALLPO  ', 'N', ' ', 12, 0, 1, '11100100'); { CPO n }
		add_instruction ('CALLZ   ', 'N', ' ', 12, 0, 1, '11001100'); { CZ n }
		{-----------------------------------------------------------}
		add_instruction ('CCF     ', ' ', ' ',  1, 0, 0, '00111111'); { CMC }
		{-----------------------------------------------------------}
		add_instruction ('CP      ', 'A', '8', 11, 2, 0, '10111xxx'); { CMP r8 }
		add_instruction ('CP      ', 'A', 'A',  1, 0, 0, '10111111'); { CMP A }
		add_instruction ('CP      ', 'A', 'I',  1, 0, 0, '10111110'); { CMP M }
		add_instruction ('CP      ', 'A', 'N', 10, 0, 2, '11111110'); { CPI n }
		{-----------------------------------------------------------}
		add_instruction ('CPL     ', 'A', ' ',  1, 0, 0, '00101111'); { CMA }
		{-----------------------------------------------------------}
		add_instruction ('DAA     ', ' ', ' ',  1, 0, 0, '00100111'); { DAA }
		{-----------------------------------------------------------}
		add_instruction ('DEC     ', '6', ' ',  6, 1, 0, '00xx1011'); { DCX rp }
		add_instruction ('DEC     ', '8', ' ',  4, 1, 0, '00xxx101'); { DCR r8 }
		add_instruction ('DEC     ', 'A', ' ',  1, 0, 0, '00111101'); { DCR A }
		add_instruction ('DEC     ', 'H', ' ',  1, 0, 0, '00101011'); { DCX H }
		add_instruction ('DEC     ', 'I', ' ',  1, 0, 0, '00110101'); { DCR M }
		{-----------------------------------------------------------}
		add_instruction ('DI      ', ' ', ' ',  1, 0, 0, '11110011'); { DI }
		{-----------------------------------------------------------}
		add_instruction ('EI      ', ' ', ' ',  1, 0, 0, '11111011'); { EI }
		{-----------------------------------------------------------}
		add_instruction ('EX      ', '6', 'H', 14, 1, 0, '11101011'); { XCHG }
		add_instruction ('EX      ', 'H', '6', 14, 2, 0, '11101011'); { XCHG }
		add_instruction ('EX      ', 'H', 'i', 13, 2, 0, '11100011'); { XTHL }
		add_instruction ('EX      ', 'i', 'H', 13, 1, 0, '11100011'); { XTHL }
		{-----------------------------------------------------------}
		add_instruction ('HALT    ', ' ', ' ',  1, 0, 0, '01110110'); { HLT }
		{-----------------------------------------------------------}
		add_instruction ('IN      ', 'A', 'D', 10, 0, 2, '11011011'); { IN n }
		{-----------------------------------------------------------}
		add_instruction ('INC     ', '6', ' ',  6, 1, 0, '00xx0011'); { INX rp }
		add_instruction ('INC     ', '8', ' ',  4, 1, 0, '00xxx100'); { INR r8 }
		add_instruction ('INC     ', 'A', ' ',  1, 0, 0, '00111100'); { INR A }
		add_instruction ('INC     ', 'H', ' ',  1, 0, 0, '00100011'); { INX H }
		add_instruction ('INC     ', 'I', ' ',  1, 0, 0, '00110100'); { INR M }
		{-----------------------------------------------------------}
		add_instruction ('JP      ', 'I', ' ',  1, 0, 0, '11101001'); { PCHL }
		add_instruction ('JP      ', 'N', ' ', 12, 0, 1, '11000011'); { JMP n }
		add_instruction ('JPC     ', 'N', ' ', 12, 0, 1, '11011010'); { JC n }
		add_instruction ('JPM     ', 'N', ' ', 12, 0, 1, '11111010'); { JM n }
		add_instruction ('JPNC    ', 'N', ' ', 12, 0, 1, '11010010'); { JNC n }
		add_instruction ('JPNZ    ', 'N', ' ', 12, 0, 1, '11000010'); { JNZ n }
		add_instruction ('JPP     ', 'N', ' ', 12, 0, 1, '11110010'); { JP n }
		add_instruction ('JPPE    ', 'N', ' ', 12, 0, 1, '11101010'); { JPE n }
		add_instruction ('JPPO    ', 'N', ' ', 12, 0, 1, '11100010'); { JPO n }
		add_instruction ('JPZ     ', 'N', ' ', 12, 0, 1, '11001010'); { JZ n }
		{-----------------------------------------------------------}
		add_instruction ('LD      ', '6', 'H', 15, 1, 0, '11111001'); { SPHL }
		add_instruction ('LD      ', '6', 'N',  9, 1, 2, '00xx0001'); { LXI rp,n }
		add_instruction ('LD      ', '8', '8',  2, 0, 0, '01dddsss'); { MOV r8,r8 }
		add_instruction ('LD      ', '8', 'A',  4, 1, 0, '01xxx111'); { MOV r8,A }
		add_instruction ('LD      ', '8', 'I',  4, 1, 0, '01xxx110'); { MOV r8,M }
		add_instruction ('LD      ', '8', 'N',  3, 1, 2, '00xxx110'); { MVI r8,n }
		add_instruction ('LD      ', 'A', '8', 11, 2, 0, '01111xxx'); { MOV A,r8 }
		add_instruction ('LD      ', 'A', 'A',  1, 0, 0, '01111111'); { MOV A,A }
		add_instruction ('LD      ', 'A', 'D', 12, 0, 2, '00111010'); { LDA n }
		add_instruction ('LD      ', 'A', 'I',  1, 0, 0, '01111110'); { MOV A,M }
		add_instruction ('LD      ', 'A', 'N', 10, 0, 2, '00111110'); { MVI A,n }
		add_instruction ('LD      ', 'A', 'i',  8, 2, 0, '000x1010'); { LDAX pr }
		add_instruction ('LD      ', 'D', 'A', 12, 0, 1, '00110010'); { STA n }
		add_instruction ('LD      ', 'D', 'H', 12, 0, 1, '00100010'); { SHLD n }
		add_instruction ('LD      ', 'H', 'D', 12, 0, 2, '00101010'); { LHLD n }
		add_instruction ('LD      ', 'H', 'N', 12, 0, 2, '00100001'); { LXI H,n }
		add_instruction ('LD      ', 'I', '8', 11, 2, 0, '01110xxx'); { MOV M,r8 }
		add_instruction ('LD      ', 'I', 'A',  1, 0, 0, '01110111'); { MOV M,A }
		add_instruction ('LD      ', 'I', 'N', 10, 0, 2, '00110110'); { MVI M,n }
		add_instruction ('LD      ', 'i', 'A',  8, 1, 0, '000x0010'); { STAX pr }
		{-----------------------------------------------------------}
		add_instruction ('NOP     ', ' ', ' ',  1, 0, 0, '00000000'); { NOP }
		{-----------------------------------------------------------}
		add_instruction ('OR      ', 'A', '8', 11, 2, 0, '10110xxx'); { ORA r8 }
		add_instruction ('OR      ', 'A', 'A',  1, 0, 0, '10110111'); { ORA A }
		add_instruction ('OR      ', 'A', 'I',  1, 0, 0, '10110110'); { ORA M }
		add_instruction ('OR      ', 'A', 'N', 10, 0, 2, '11110110'); { ORI n }
		{-----------------------------------------------------------}
		add_instruction ('OUT     ', 'D', 'A', 10, 0, 1, '11010011'); { OUT n }
		{-----------------------------------------------------------}
		add_instruction ('POP     ', '6', ' ',  7, 1, 0, '11xx0001'); { POP rp }
		add_instruction ('POP     ', 'H', ' ',  1, 0, 0, '11100001'); { POP H }
		{-----------------------------------------------------------}
		add_instruction ('PUSH    ', '6', ' ',  7, 1, 0, '11xx0101'); { PUSH rp }
		add_instruction ('PUSH    ', 'H', ' ',  1, 0, 0, '11100101'); { PUSH H }
		{-----------------------------------------------------------}
		add_instruction ('RET     ', ' ', ' ',  1, 0, 0, '11001001'); { RET }
		add_instruction ('RETC    ', ' ', ' ',  1, 0, 0, '11011000'); { RC }
		add_instruction ('RETM    ', ' ', ' ',  1, 0, 0, '11111000'); { RM }
		add_instruction ('RETNC   ', ' ', ' ',  1, 0, 0, '11010000'); { RNC }
		add_instruction ('RETNZ   ', ' ', ' ',  1, 0, 0, '11000000'); { RNZ }
		add_instruction ('RETP    ', ' ', ' ',  1, 0, 0, '11110000'); { RP }
		add_instruction ('RETPE   ', ' ', ' ',  1, 0, 0, '11101000'); { RPE }
		add_instruction ('RETPO   ', ' ', ' ',  1, 0, 0, '11100000'); { RPO }
		add_instruction ('RETZ    ', ' ', ' ',  1, 0, 0, '11001000'); { RZ }
		{-----------------------------------------------------------}
		add_instruction ('RIM     ', ' ', ' ',  1, 0, 0, '00100000'); { RIM }
		{-----------------------------------------------------------}
		add_instruction ('RL      ', 'A', ' ',  1, 0, 0, '00010111'); { RAL }
		add_instruction ('RLC     ', 'A', ' ',  1, 0, 0, '00000111'); { RLC }
		add_instruction ('RR      ', 'A', ' ',  1, 0, 0, '00011111'); { RAR }
		add_instruction ('RRC     ', 'A', ' ',  1, 0, 0, '00001111'); { RRC }
		{-----------------------------------------------------------}
		add_instruction ('RST     ', 'N', ' ',  5, 0, 1, '11nnn111'); { RST n }
		{-----------------------------------------------------------}
		add_instruction ('SBB     ', 'A', '8', 11, 2, 0, '10011xxx'); { SBB r8 }
		add_instruction ('SBB     ', 'A', 'A',  1, 0, 0, '10011111'); { SBB A }
		add_instruction ('SBB     ', 'A', 'I',  1, 0, 0, '10011110'); { SBB M }
		add_instruction ('SBB     ', 'A', 'N', 10, 0, 2, '11011110'); { SBI n }
		{-----------------------------------------------------------}
		add_instruction ('SCF     ', ' ', ' ',  1, 0, 0, '00110111'); { STC }
		{-----------------------------------------------------------}
		add_instruction ('SIM     ', ' ', ' ',  1, 0, 0, '00110000'); { SIM }
		{-----------------------------------------------------------}
		add_instruction ('SUB     ', 'A', '8', 11, 2, 0, '10010xxx'); { SUB r8 }
		add_instruction ('SUB     ', 'A', 'A',  1, 0, 0, '10010111'); { SUB A }
		add_instruction ('SUB     ', 'A', 'I',  1, 0, 0, '10010110'); { SUB M }
		add_instruction ('SUB     ', 'A', 'N', 10, 0, 2, '11010110'); { SUI n }
		{-----------------------------------------------------------}
		add_instruction ('XOR     ', 'A', '8', 11, 2, 0, '10101xxx'); { XRA r8 }
		add_instruction ('XOR     ', 'A', 'A',  1, 0, 0, '10101111'); { XRA A }
		add_instruction ('XOR     ', 'A', 'I',  1, 0, 0, '10101110'); { XRA M }
		add_instruction ('XOR     ', 'A', 'N', 10, 0, 2, '11101110'); { XRI n }
		{-----------------------------------------------------------}
	end;  { procedure init_table }

begin { unit itab }
	init_table;
end.  { unit itab }
		
{ Emacs settings }

{ Local Variables:	}
{ tab-width: 4		}
{ End:				}
