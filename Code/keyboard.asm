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
  
  
  
; --------------------------------------------------------------------------- 
; Quick hack using KERNAL routines to read the keyboard

ReadKey:
    lda $C5  ; Current key
    sta screen_start
    cmp #$40  ;None
    bne keypressed
    
    ; No key was pressed.  But was one pressed previously?
    lda  midinoteout
    beq key_x   ; No
    
    ; Yes, so turn that note off.
    jsr sendnoteoff
    
key_x:
    rts
    
    
keypressed:   ; A contains key code
    tax
    lda notelookup,x
    beq key_x             ; Note was 0, in this context meaning no note
    
    sta midinoteout
    jsr sendnoteon        

    rts
    


; ---------------------------------------------------------------------------     
; Send a NOTE ON MIDI Message.

sendnoteon:  
    jsr wait_tx 
    lda noteonval    ; Note on
    sta UART_RXTX
    
    jsr wait_tx
    lda midinoteout
    sta UART_RXTX
    
    jsr wait_tx
    lda defaultvelocity   
    sta UART_RXTX
    
    ; Display
    HEXPOKE (midi_display+0),noteonval
    HEXPOKE (midi_display+3),midinoteout
    HEXPOKE (midi_display+6),defaultvelocity
    
    rts


; ---------------------------------------------------------------------------     
; Send a NOTE OFF MIDI Message.

sendnoteoff:  
    jsr wait_tx 
    lda noteoffval    ; Note off
    sta UART_RXTX
    
    jsr wait_tx
    lda midinoteout
    sta UART_RXTX
    
    jsr wait_tx
    lda defaultvelocity   ; Decimal - convention for velocity when velocity not supported.
    sta UART_RXTX
    
    ; Display
    HEXPOKE (midi_display+0),noteoffval
    HEXPOKE (midi_display+3),midinoteout
    HEXPOKE (midi_display+6),defaultvelocity
    
    rts


; --------------------------------------------------------------------------- 
; Quick hack to wait for THR to be empty.  Ideally sending would be
; interrupt-driven with a ring buffer.

wait_tx: 
    lda UART_LSR
    and #32
    beq wait_tx
    rts

noteonval:
    byte $90    

noteoffval:
    byte $80 
    
defaultvelocity:
    byte 64  ; Decimal - convention for velocity when velocity not supported.   

notelookup:
				
	;	MIDI Note#		Comments
	byte	0	;	
	byte	63	;	
	byte	66	;	
	byte	70	;	
	byte	73	;	
	byte	0	;	
	byte	80	;	
	byte	83	;	
	byte	0	;	
	byte	62	;	
	byte	65	;	
	byte	69	;	
	byte	72	;	
	byte	76	;	
	byte	79	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	60	;	Middle C (C5)
	byte	64	;	
	byte	67	;	
	byte	71	;	
	byte	74	;	
	byte	77	;	
	byte	81	;	
	byte	0	;	
	byte	61	;	
	byte	0	;	
	byte	68	;	
	byte	0	;	
	byte	75	;	
	byte	78	;	
	byte	82	;	
	byte	0	;	
	byte	0	;	No key Pressed
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
	byte	0	;	
