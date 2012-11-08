; VIC-20 MIDI Interface
; By David Viens and Leif Bloomquist

; --------------------------------------------------------------------------------------------------  

  processor 6502 ;  VIC-20
  
  ; Assume no memory expansion.   Compile as Cartridge ROM in Block 5.
  org $A000  ; Block 5
    
  include "macros.asm"
  include "equates.asm"

 ; ---- Startup Code ---------------------------------------------------
  dc.w START   ; Entry point for power up
  dc.w RESTORE ; Entry point for warm start (RESTORE)
  
  dc.b "A0",$C3,$C2,$CD  ; 'A0CBM' boot string

START:  
  ;Kernel Init
  jsr $fd8d ; RAMTAS - Initialise System Constants
  jsr $fd52 ; Init Vectors
  jsr $fdf9 ; Init I/O
  jsr $e518 ; Init I/O 
  
  ;BASIC Init (Partial)
  jsr $e45b ; Init Vectors  
  jsr $e3a4 ; BASIC RAM
  jsr $e404 ; INIT Message (needed (?) so keycheck routines work)  

entry:
  jsr titlescreen 
  jsr setup_pal 
  jsr setwavecopy
  jsr checkuart
  jsr setupirq
  jsr resetuart  
  
  ; Default to maximum volume
  lda #$0F
  jsr setvolume    

  ; Initial Values
  lda #$00
  sta midicounter  ; midicounter=0
  sta statusbyte   ; statusbyte=0
  sta mididata0    ; mididata0=0
  sta mididata1    ; mididata1=0
  sta mididata2    ; mididata2=0
  sta c0           ; no keys are pressed in 7F
  sta c1           ; no keys are pressed in BF
  sta c2           ; no keys are pressed in FD
  sta c3           ; no keys are pressed in FE
  sta lastnote+0   ; Clear
  sta lastnote+1   ;    last
  sta lastnote+2   ;      note
  sta poly_flags+0 ; Clear
  sta poly_flags+1 ;   poly
  sta poly_flags+2 ;     flags
  sta spin_color
  sta write_pointer
  sta read_pointer
  

  lda #$6C         
  sta spin_display
  
;;; ========================================================================
;;; main LOOP!
loop:
  inc spin_color   ; Prove we aren't 'frozen'
  ;jsr GetKey      ; create events from keyboard if needed - TODO
  
  lda read_pointer
  cmp write_pointer
  beq loop         ; Pointers match, no data
;;; ========================================================================

  ; We have data!
  ; Advance pointer for next read  
  inc read_pointer
  
  ; Read current byte
  tax            ; Since A still contains the unincremented pointer
  lda buffer,x
  
  ; If Bit 7 is set, it means it's a status byte and we need to prepare for a new message
  bpl data  ; Not a status byte
  
  ; Store the status byte
  sta statusbyte
  
  ; Reset the midi counter to 0
  ldx #$00
  stx midicounter
  
  ; Also, check how many bytes we'll need - Normally 3, but 2 for Program Change
  and #$F0      ; Get the upper nybble
  cmp #$C0      ; Program change
  bne bytes2
  
bytes1:
  ldy #$01
  jmp setbytes

bytes2:
  ldy #$02

setbytes:
  sty bytesexpected
  jmp loop   ; Wait for next byte

; --------------------------------------------------------------------------------------------------  
; Store data byte

data:
  ldx midicounter    ; What byte are we at?
  sta mididata0,x    ; Store received midi data pointed by x
  
  inx                ; x++
  stx midicounter    ; and store x
  
  cpx bytesexpected  ; Number of data bytes expected in this MIDI message (i.e. 2)
  beq messageproc    ; Complete MIDI message received.     
  
  ; Not complete, wait for more bytes. 
  jmp loop

; --------------------------------------------------------------------------------------------------  
; Process a complete MIDI message

messageproc:
  ; Reset midicounter back to 0 for next message - this might be redundant (see above line 100)
  lda #$00         
  sta midicounter
  
  ; Display received message bytes
  HEXPOKE (midi_display+0),statusbyte
  HEXPOKE (midi_display+3),mididata0
  HEXPOKE (midi_display+6),mididata1
  
  ; Save channel
  lda statusbyte
  and #$0F
  sta channel
  
  ; Determine Command
  lda statusbyte ; Status Byte
  and #$F0       ; Get the upper nybble
  
m8
  cmp #$80       ; Note Off
  bne m9 
  jsr noteoff
  jmp loop

m9
  cmp #$90       ; Note On
  bne mb
  jsr noteon
  jmp loop 

mb
  cmp #$B0       ; Control Change
  bne mc
  jsr controlchange
  jmp loop

mc
  cmp #$C0       ; Program Change
  bne mx 
  jsr programchange 
  ; Drop through
mx
  ; All others (Aftertouch, etc.) ignored.
  jmp loop


;******************************************************************************
;*************************  MIDI Processing  **********************************
;******************************************************************************  

; ---- Note On ---------------------------------------------------
; 9c nn vv

noteon:
  ; Special Case: Treat Velocity=0 as Note Off.  Velocity ignored otherwise.
  lda mididata1
  beq noteoff

  ldy channel    ; Y now contains Channel # (0-offset)  
  ldx mididata0  ; X now contains MIDI Note #
  
  ; Special Case: Channel 5 used for Poly mode
  cpy #$04
  bne savenote  
  jsr get_poly_voice
  
savenote:
  ; Save the note# so that later Note Offs only apply to this note.
  txa
  sta lastnote,y

  ; Perform a table lookup of MIDI Note# to VIC Register
  ; Table to use depends on voice/channel
  cpy #$00 
  beq vl1
  
  cpy #$01
  beq vl2
  
  cpy #$02
  beq vl3
  
  cpy #$03
  beq vl4
  
  ; Ignore all other channels
  rts

vl1
  lda voice1lookup,x
  jmp setvoice

vl2
  lda voice2lookup,x
  jmp setvoice
  
vl3
  lda voice3lookup,x
  jmp setvoice 

vl4
  lda voice4lookup,x
  jmp setvoice  


; ---- Note Off ---------------------------------------------------
; 8c nn vv

noteoff:
  ldy channel   ; Y now contains channel #
  
  ; Special Case: Channel 5 used for Poly mode
  cpy #$04
  bne noteoff_check
    
  jsr get_poly_voice_off
  jmp noteoff_off

noteoff_check:  
  ;For Channels 1-4
  ;Check if it matches the last.  If not, ignore. 
  lda lastnote,y
  cmp mididata0
  bne noteoff_x 

noteoff_off:  
  lda #$00      ; Off
  jmp setvoice

noteoff_x:
  rts
  
; ---- Control Change ---------------------------------------------------
; Bc CC vv

controlchange:
  ldy channel    ; Y now contains channel #
  
  lda mididata0  ; Controller number
cc1
  cmp #01       ; Modulation Wheel (coarse) - decimal
  bne cc7
  jmp modwheel
  
cc7
  cmp #07       ; Volume (coarse) - decimal
  bne cc74
  jmp volume
  
cc74
  cmp #74       ; Brightness - decimal
  bne cc120
  jmp screencolors

cc120
  cmp #120       ; All Sound Off - decimal
  bne cc123
  jmp soundoff

cc123
  cmp #123       ; All Notes Off - decimal
  bne ccx
  jmp soundoff

ccx ; Ignore all the rest
  rts
  
  
; ---- MOD Wheel Controller --------------------------------------------
; Bc 01 vv
  
; Poke the data directly to the register, after OR'ing with $80
modwheel:
  lda mididata1
  ora #$80
  jmp setvoice
  

; ---- Volume Controller ------------------------------------------------
; Bc 07 vv

volume:
  lda mididata1
  lsr
  lsr
  lsr
  
setvolume:
  sta sound_volume
  HEXPOKE (voice_display+110),sound_volume
  rts

; ---- Brightness Controller (used for screen color)-------------------------
; Bc 4a vv  

screencolors:
  clc
  lda mididata1    ; 7-bit

  and #%00000111   ; Get border
  sta temp1

  lda mididata1
  and #%01111000   ; Get background
  asl              ; Shift 1 bit left

  ora temp1        ; Put border back in
  ora #%00001000   ; No Reverse Mode
  
  sta screen_colors
  rts

; ---- Sound Off / All Notes Off Controller------------------------------------
; Bc 78 xx
; Bc 7B xx

soundoff:
  lda #$00      ; Off
  jmp setvoice


; ---- Program Change ---------------------------------------------------
; Cc pn  <NOTE 2 bytes!>

programchange:
  ;Blank the unused MIDI byte
  lda #45  ; -
  sta midi_display+6
  sta midi_display+7
  
  ldy channel    ; Y now contains channel #

pc_0:
  cpy #$00
  bne pc_1 
  HEXPOKE (voice_display+5),mididata0 
  jmp pc_do

pc_1:
  cpy #$01
  bne pc_2
  HEXPOKE (voice_display+27),mididata0
  jmp pc_do
  
pc_2:
  cpy #$02
  bne pc_3
  HEXPOKE (voice_display+49),mididata0
  jmp pc_do
  
pc_3:
  cpy #$03
  bne pc_rts
  HEXPOKE (voice_display+71),mididata0
  jmp pc_do
  
  ;Ignore all other channels
pc_rts:  
  rts


pc_do:
  ldy channel    ; Y now contains channel # (0-3) (temp)
  
  lda sound_voice1,y
  sta tempx  ; See below 
 
  lda voice_to_register,y
  tay             ; Y Now contains low byte of register
  
  lda mididata0
  and #$0f        ; Get low nybble, since there are only 16 viznut waveforms
  tax
  lda viznutwaveforms,x  ; A now contains the desired shift register contents

  ldx tempx              ; X now contains initial frequency of selected channel
  
  ; X,Y,A are set - Set the waveform.
  jsr setwave
  rts    


;***************************************************************************
;*******************  Set/Display Functions  *******************************
;***************************************************************************  

; Dispatcher for setting the appropriate voice.
; Channel# in Y (Channel 0 = Voice 1, etc) 
; Value to set it to in A.

setvoice:
  cpy #$00 
  beq v1
  
  cpy #$01
  beq v2
  
  cpy #$02
  beq v3
  
  cpy #$03
  beq v4
  
  ; Ignore all other channels
  rts

; ---- Voice 1 -------
v1 
  sta sound_voice1
  HEXPOKE (voice_display+00),sound_voice1
  rts

; ---- Voice 2 -------
v2
  sta sound_voice2
  HEXPOKE (voice_display+22),sound_voice2
  rts

; ---- Voice 3 -------
v3
  sta sound_voice3
  HEXPOKE (voice_display+44),sound_voice3
  rts

; ---- Voice 4 -------
v4
  sta sound_noise
  HEXPOKE (voice_display+66),sound_noise
  rts

;***************************************************************************
;*******************    Hardware Functions   *******************************
;***************************************************************************  

; ----------------------------------------------------------------------------
; Confirm the presence of the ST16C450 UART  
checkuart:
  lda #$55
  sta UART_SCRATCHPAD
  
  lda UART_SCRATCHPAD
  cmp #$55
  beq checkuart_ok 

  ; Not found!
  PLOT 0,20
  PRINTSTRING "**uart NOT FOUND! ***"

uloop:
  inc screen_colors
  jmp uloop 
   
checkuart_ok:
  rts        
 
; ----------------------------------------------------------------------------  
; Set up the UART
  
resetuart:
  ; Expose the divisor latch.
  lda #%10000000
  sta UART_LCR
  
  ; Set the MIDI baud rate.
  ; The ST16C450 datasheet says that it divides the input clock rate by
  ; 16, so with a 2Mhz crystal on board, that gives
  ; 2000000 * (1/16) * (1/x) = 31250.  Solving gives x=4 for the low
  ; byte of the divisor, and 0 for the high byte.  
      
  ldx #$00 
  ldy #$04
  stx UART_DIVISOR_MSB
  sty UART_DIVISOR_LSB
  
  ; Set to MIDI: Word length 8, Stop bits 1, no parity (also hides divisor latch)
  lda #%00000011
  sta UART_LCR
  
  ; Enable the interrupt when data is received
  lda #%00000001
  sta UART_IER
  rts        

; ----------------------------------------------------------------------------  
; Set up the IRQ for reading bytes from the UART
  
setupirq:
  sei 
  
  ; Point to my interrupt vector
  lda #<theirq 
  sta $0314 
  lda #>theirq 
  sta $0315 
  
  ; Disable timer interrupts
  
  lda #%01100000
  sta $912e     ; disable and acknowledge interrupts
  sta $912d
  ;sta $911e     ; disable NMIs (Restore key) 
  
  cli 
  rts 

; ----------------------------------------------------------------------------
; The IRQ.  

theirq: 
  ; Fetch the received byte
  lda UART_RXTX    ;get data
  ldy write_pointer
  sta buffer,y
  inc write_pointer

  ; Clear the interrupt from the UART by reading the status register
  lda UART_ISR
   
  jmp $ff56  ; Use this in place of rti because it restores the A,X,Y registers from the stack
  ;jmp $eabf     ; return to normal IRQ  (scans keyboard and stuff)

; ----------------------------------------------------------------------------  
  
setcolors:
  ldx #$00
  lda #$00  
setcolorsloop:
  sta $9600,x
  sta $9700,x  
  inx  
  cpx #$00
  bne setcolorsloop
  rts    

; ----------------------------------------------------------------------------  
; Draw Title Screen

titlescreen:
  jsr CLRSCREEN
  lda #$06   ; Blue
  sta $0286  ; Cursor Color
  PRINTSTRING maintext
  rts

; ---------------------------------------------------------------------------- 
; Handle the RESTORE key  

RESTORE:
  jmp $fec7   ; Continue as if no cartridge installed

; ----------------------------------------------------------------------------  
; More includes  

  include "utils.asm"
  include "polymode.asm"
  include "keyboard.asm"     
setwaveorg:
  include "setwave.asm"
  byte 0,0,0,0   

; setwave needs to start on a page and is self-modifying, 
; so it is copied to RAM here
  
setwavecopy:  
  ldx #$00
copyloop:
  lda setwaveorg,x
  sta setwave,x
  inx
  bne copyloop
  rts
  
  
; ----------------------------------------------------------------------------
; Strings

maintext:
  byte CG_LCS, CG_DCS 
  byte "*vic20 midi iNTERFACE*", CRLF
  byte CRLF
  byte "midi dATA: --:--:--", CRLF  
  byte CRLF                       
  byte "vOICE 1: -- / --", CRLF
  byte "vOICE 2: -- / --", CRLF
  byte "vOICE 3: -- / --", CRLF
  byte "vOICE 4: -- / --", CRLF
  byte CRLF
  byte "vOLUME : --", CRLF
  byte "bANK   : --", CRLF
  byte CRLF
  byte "sYSTEM : tbd", CRLF
  
  byte 0
  
; ----------------------------------------------------------------------------  
; Lookup table between voice #(0-3) and low byte of register# ($0A-$0D)

voice_to_register:
  byte $0A,$0B,$0C,$0D

  include "lookup-ntsc.asm"
  ;include "lookup-pal.asm"
  ;include "lookup-ntsc-alt.asm"
  ;include "lookup-pal-alt.asm"
  
; EOF!