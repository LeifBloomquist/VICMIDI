;*******************************************************************************************
;********************************  keyboard stuff  *****************************************
;*******************************************************************************************	

; --------------------------------------------------------------------------------------------------	
;;;;;;;;;;;;;;; keyboard stuff
;previous keyboard column bits
c0 = $4E  ; 2,4,6,8,(...)
c1 = $4F  ; q,e,t,u,(...)
c2 = $50  ; w,r,y,i,p,(...)
c3 = $51	; 1,3,5,7,(...)

kb_column = $9120
kb_row = $9121

; 9121   9120: (Write column value to this address)
;
;        7f      bf      df      ef      f7      fb      fd      fe
;
;  fe    2       q       CBM     Space   RunStop Control Lft_arr 1       
;  fd    4       e       s       z       Shift_L a       w       3       
;  fb    6       t       f       c       x       d       r       5       
;  f7    8       u       h       b       v       g       y       7       
;  ef    0       o       k       m       n       j       i       9
;  df    -       @       :       .       ,       l       p       +
;  bf    Home    Up_arr  =       Shift_R /       ;       *       GBP 
;  7f    F7      F5      F3      F1      Down    Right   Return  Del

GetKey:
       sei   
	   ; this should not be done, we want to compare the OLD recorded status with new one
	   ;lda #$0
	   ;sta kb_column
	   ;lda kb_row
	   ;cmp #$FF
	   ;beq NoKey      ; no key at all pressed
	   
Check7F:	   
	   ;now check for each column
	   lda #$7F	   
	   sta kb_column
	   lda kb_row
       eor #$FF ; inversed accumulator contains all bits in this column
	   cmp c0	
	   beq CheckBF ; these arent the droids you are looking for move along
	   sta c0
	   sta $1E00
	   jmp KeyDone
CheckBF:  
	   ;now check for each column
	   lda #$BF	   
	   sta kb_column
	   lda kb_row
       eor #$FF ; inversed accumulator contains all bits in this column
	   cmp c1	
	   beq CheckFD ; these arent the droids you are looking for move along
	   sta c1
	   sta $1E01
	   jmp KeyDone	   
CheckFD:  
	   ;now check for each column
	   lda #$FD	   
	   sta kb_column
	   lda kb_row
       eor #$FF ; inversed accumulator contains all bits in this column
	   cmp c2	
	   beq CheckFE ; these arent the droids you are looking for move along
	   sta c2
	   sta $1E02
	   jmp KeyDone	   
CheckFE:  
	   ;now check for each column
	   lda #$FE	   
	   sta kb_column
	   lda kb_row
       eor #$FF ; inversed accumulator contains all bits in this column
	   cmp c3	
	   beq KeyDone ; these arent the droids you are looking for move along
	   sta c3
	   sta $1E03   
KeyDone:  
	   cli
       rts		   

; ---------------------------------------------------------------------------  
  
setchars:
  ldx #$00
  lda #$51  
setcharsloop1:
  sta $1E00,x
  inx  
  cpx #$00
  bne setcharsloop1
  ldx #$00
  lda #$66  
setcharsloop2:  
  sta $1F00,x
  inx  
  cpx #$00
  bne setcharsloop2  
  rts