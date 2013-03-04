;A short generic routine for setting any shift register value for any pulse
;channel in about 150 cpu clocks. Use it freely.

	; USAGE: y = channel ($0a..$0c)
	;        x = initial frequency
	;        a = shift register contents
	;
	; WARNING for purists: self-modifying code, illegal opcodes.
	;
	; code align assertion: make sure that the loop is within a page.
	; oscillator assertion: make sure that the channel has been at $7e
	; for some time before calling this function.
	; put TMP and TMP2 in the zero page.

    stx initfreq	; 4
    
    sty ch0	; 4
    sty ch1	; 4
    ldx ldfqmasks-$a,y ; 4
    sta TMP		; 3
    
    ora #$7f	; 2
    
    .byte $8f,$0C,$90    ; axs $900c  ; 4  [$900c] = a AND x         *ILLEGAL OPCODE*
    
ch0 = *-2
    sty TMP2	; 3
    ldy #7		; 2

l0:
    lda #$7f	; 2
    .byte $07,TMP       ; aso TMP		 ; 5  asl tmp; a = [tmp] OR $7f  *ILLEGAL OPCODE*
    .byte $8F,$0C,$90   ; axs $900c	 ; 4  [$900c] = a AND x          *ILLEGAL OPCODE*
ch1 = *-2
    dey		     ; 2
    bne l0		 ; 3
    
    lda #128	 ; 2
initfreq = *-1
    nop		     ; 2
    ldy TMP2	 ; 3
noset:	
    sta $9000,y	; 5

	rts		; 6	total clocks 11+4+3+2+16*7+16+6 eq 154

ldfqmasks:
  .byte $fe	 ; $900a - 1 x 16 clocks/bit
  .byte $fd  ; $900b - 2 x  8 clocks/bit
  .byte $fb  ; $900c - 4 x  4 clocks/bit


viznutwaveforms:
  .byte 0     ; MIDI Program #1      default  0000000011111111 
  .byte 2     ; MIDI Program #2      "10"     0000001011111101 
  .byte 4     ; MIDI Program #3      "100"    0000010011111011 
  .byte 6     ; MIDI Program #4      "110"    0000011011111001 
  .byte 8     ; MIDI Program #5      "1000"   0000100011110111 
  .byte 10    ; MIDI Program #6      "1010"   0000101011110101 
  .byte 11    ; MIDI Program #7      "1011"   0000110011110011 
  .byte 14    ; MIDI Program #8      "1110"   0000111011110001 
  .byte 18    ; MIDI Program #9      "10010"  0001001011101101 
  .byte 20    ; MIDI Program #10     "10100"  0001010011101011 
  .byte 22    ; MIDI Program #11     "10110"  0001011011101001 
  .byte 24    ; MIDI Program #12     "11000"  0001100011100111 
  .byte 26    ; MIDI Program #13     "11010"  0001101011100101 
  .byte 36    ; MIDI Program #14     "100100" 0010010011011011 
  .byte 42    ; MIDI Program #15     "101010" 0010101011010101 
  .byte 44    ; MIDI Program #16     "101100" 0010110011010011