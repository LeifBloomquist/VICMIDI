; VIC-20 MIDI Interface
; By David Viens and Leif Bloomquist, portions by 
; Michael Kircher and Viznut

; ----------------------------------------------------------------------------  

  processor 6502  ; VIC-20
  
  ; Assume no memory expansion.   Compile as Cartridge ROM in Block 5.
  org $A000  ; Block 5
  
  ; Macro and equate includes (must be at start)  
  include "macros.asm"
  include "equates.asm"

 ; ---- Startup Code ---------------------------------------------------------
  dc.w START   ; Entry point for power up
  dc.w RESTORE ; Entry point for warm start (RESTORE)
  
  dc.b "A0",$C3,$C2,$CD  ; 'A0CBM' boot string

START:  
  ; Kernel Init
  jsr $fd8d ; RAMTAS - Initialise System Constants
  jsr $fd52 ; Init Vectors
  jsr $fdf9 ; Init I/O
  jsr $e518 ; Init I/O 
  
  ; BASIC Init (Partial)
  jsr $e45b ; Init Vectors  
  jsr $e3a4 ; BASIC RAM
  jsr $e404 ; INIT Message (needed (?) so keycheck routines work)  

entry:
  jsr setupfont  
  jsr mainscreen 
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
  sta lastnote+3   ;        (including noise)
  sta poly_flags+0 ; Clear
  sta poly_flags+1 ;   poly
  sta poly_flags+2 ;     flags
  sta spin_color
  sta write_pointer
  sta read_pointer 
  sta waveform1
  sta waveform2
  sta waveform3
  sta waveform4
  sta midinoteout
  
;;; ==========================================================================
;;; main LOOP!
loop:
  inc spin_color   ; Prove we aren't 'frozen'
  jsr ReadKey      ; create events from keyboard if needed
  
  lda read_pointer
  cmp write_pointer
  beq loop         ; Pointers match, no data
;;; ==========================================================================

  ; We have data!   
  ; Advance pointer for next read  
  inc read_pointer
  
  ; Read current byte
  tax            ; Since A still contains the unincremented pointer
  lda buffer,x
  
  ; If Bit 7 is set, it means it's a status byte and we need to prepare for a new message
  bpl data  ; Not a status byte
  
; ----------------------------------------------------------------------------  
; Process a status byte  (Currently in A)
  
  ; Store the status byte temporarily
  sta tempstatusbyte
  
  ; Handle System Common / System Realtime messages
  and #$F0                     
  cmp #$F0
  bne normalmessage  
;  inc screen_colors
  jmp system_realtime_proc   ; Which goes back to loop
  
normalmessage:
  ; Everything else, split into Command and Channel
  lda tempstatusbyte
  sta statusbyte
  and #$F0             ; Get the upper nybble
  sta command
  
  lda statusbyte
  and #$0F             ; Get the lower nybble
  sta channel
  
  ; Also, check how many data bytes should follow.
  lda command

  ; 1 for Program Change
  cmp #$C0      ; Program change
  beq bytes1
  
  ; Assume 2 for all the rest
bytes2:
  ldy #$02
  jmp setbytes
  
bytes1:
  ldy #$01
  ; Drop through

setbytes:
  sty bytesexpected
  
  ; Reset the midi counter to 0
  ldx #$00
  stx midicounter
  
  jmp loop   ; Wait for next byte


; ----------------------------------------------------------------------------  
; Store data byte - in A.

data:
  ldx midicounter    ; What byte are we at?
  sta mididata0,x    ; Store received midi data pointed by x
  
  inx                ; x++
  stx midicounter    ; and store x
  
  cpx bytesexpected  ; Number of data bytes expected in this MIDI message (i.e. 2)
  beq messageproc    ; Complete MIDI message received.     
  
  ; Not complete, wait for more bytes. 
  jmp loop


; ----------------------------------------------------------------------------  
; Process a complete MIDI message   (All but System)

messageproc:
 
  ; Display received message bytes
  HEXPOKE (midi_display+0),statusbyte
  HEXPOKE (midi_display+3),mididata0
  HEXPOKE (midi_display+6),mididata1
  
  ; Reset the midi counter to 0 again, in case of running status
  ldx #$00
  stx midicounter

  ; Determine Command
  lda command          
   
  cmp #$80          ; Note Off
  beq donoteoff
  
  cmp #$90          ; Note On
  beq donoteon
  
  cmp #$B0          ; Control Change
  beq docontrolchange    
  
  cmp #$C0          ; Program Change
  beq doprogramchange

  ; All others (Aftertouch, etc.) ignored.
  jmp loop
 
donoteoff:
  jsr noteoff
  jmp loop

donoteon:  
  jsr noteon
  jmp loop 

docontrolchange:
  jsr controlchange
  jmp loop

doprogramchange:
  jsr programchange 
  jmp loop 


; ----------------------------------------------------------------------------  
; Process a MIDI System Realtime  (for future)

system_realtime_proc:
 
  ; Display received message bytes
  HEXPOKE (midi_display+0),tempstatusbyte
  
   ; Blank the unused MIDI bytes
  lda #45  ; -
  sta midi_display+3
  sta midi_display+4
  sta midi_display+6
  sta midi_display+7
  
  ; inc screen_colors
  
  ; Determine Command
  ;lda tempstatusbyte          
   
  ;cmp #$...
  ;beq ...
  
  ; All ignored.
  jmp loop
 



;*****************************************************************************
;*************************  MIDI Processing  *********************************
;*****************************************************************************  

; ---- Note On ---------------------------------------------------
; 9c nn vv

noteon:
  ; Special Case: Treat Velocity=0 as Note Off.  Velocity ignored otherwise.
  lda mididata1
  bne noteon_contd
  jmp noteoff

noteon_contd:
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
  ; Table to use depends on bank/voice/channel

  ; Check the bank
  lda bank
  
  cmp #$00
  beq lookups_ntsc 
  
  cmp #$01
  beq lookups_pal
  
  cmp #$02
  beq lookups_alt
  
  cmp #$03
  beq lookups_alt
  
  ; Ignore all other banks
  rts 


; ------ NTSC -------

lookups_ntsc:
  cpy #$00 
  beq vlook1_ntsc
  
  cpy #$01
  beq vlook2_ntsc
  
  cpy #$02
  beq vlook3_ntsc
  
  cpy #$03
  beq vlook4_ntsc
  
  ; Ignore all other channels
  rts
      
vlook1_ntsc:
  lda voice1lookup_ntsc,x
  jmp setvoice

vlook2_ntsc:
  lda voice2lookup_ntsc,x
  jmp setvoice
  
vlook3_ntsc:
  lda voice3lookup_ntsc,x
  jmp setvoice 

vlook4_ntsc:
  lda voice4lookup_ntsc,x
  jmp setvoice
    
; ------ PAL -------

lookups_pal:
  cpy #$00 
  beq vlook1_pal
  
  cpy #$01
  beq vlook2_pal
  
  cpy #$02
  beq vlook3_pal
  
  cpy #$03
  beq vlook4_pal
  
  ; Ignore all other channels
  rts
      
vlook1_pal:
  lda voice1lookup_pal,x
  jmp setvoice

vlook2_pal:
  lda voice2lookup_pal,x
  jmp setvoice
  
vlook3_pal:
  lda voice3lookup_pal,x
  jmp setvoice 

vlook4_pal:
  lda voice4lookup_pal,x
  jmp setvoice

; ------ Alternate -------

lookups_alt:
  cpy #$00 
  beq vlook1_alt
  
  cpy #$01
  beq vlook2_alt
  
  cpy #$02
  beq vlook3_alt
  
  cpy #$03
  beq vlook4_alt
  
  ; Ignore all other channels
  rts
      
vlook1_alt:
  lda voice1lookup_alt,x
  jmp setvoice

vlook2_alt:
  lda voice2lookup_alt,x
  jmp setvoice
  
vlook3_alt:
  lda voice3lookup_alt,x
  jmp setvoice 

vlook4_alt:
  lda voice4lookup_alt,x
  jmp setvoice

; ---- Note Off --------------------------------------------------------------
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
  
; ---- Control Change --------------------------------------------------------
; Bc CC vv

controlchange:
  ldy channel    ; Y now contains channel #      
  lda mididata0  ; Controller number

  cmp #00        ; Bank select - decimal
  beq bankselect

  cmp #01        ; Modulation Wheel (coarse) - decimal
  beq modwheel
  
  cmp #07        ; Volume (coarse) - decimal
  beq volume
  
  cmp #74        ; Brightness - decimal
  beq screencolors

  cmp #120       ; All Sound Off - decimal
  beq soundoff

  cmp #123       ; All Notes Off - decimal
  beq soundoff

  ; Ignore all the rest
  rts

; ---- Bank Select -----------------------------------------------------------
; Bc 00 vv

bankselect:
  lda mididata1  
  and #$03         ; A contains bank, 0-3
  sta bank
  
showbank:  
  HEXPOKE (voice_display+132),bank
  
  PLOT 9,13
  
  lda bank
  
  cmp #$00
  beq ntsc
  
  cmp #$01
  beq pal
  
  cmp #$02
  beq alt
  
  cmp #$03
  beq alt
  
  ; Ignore the rest
  rts
  
ntsc:
  PRINTSTRING ntscstring
  rts
    
pal:
  PRINTSTRING palstring
  rts

alt:
  PRINTSTRING altstring
  rts
   
; ---- MOD Wheel Controller --------------------------------------------------
; Bc 01 vv
  
; Poke the data directly to the register, after OR'ing with $80
modwheel:
  lda mididata1
  ora #$80
  jmp setvoice

; ---- Volume Controller -----------------------------------------------------
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

; ---- Brightness Controller (used for screen color)--------------------------
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

; ---- Sound Off / All Notes Off Controller-----------------------------------
; Bc 78 xx
; Bc 7B xx

soundoff:
  lda #$00        ; Off
  jmp setvoice


; ---- Program Change --------------------------------------------------------
; Cc pn  <NOTE 2 bytes!>

programchange:
  ; Blank the unused MIDI byte
  lda #45  ; -
  sta midi_display+6
  sta midi_display+7
  
  ; Get low nybble and replace, since there are only 16 viznut waveforms
  lda mididata0
  and #$0f     
  sta mididata0   ; Note that this is the waveform NUMBER, not the VALUE!      
  
  ldy channel      ; Y now contains channel #
  sta waveform1,y  ; Store waveform used 
  
  cpy #00
  beq pc_0
  
  cpy #01
  beq pc_1
  
  cpy #02
  beq pc_2
  
  cpy #03       ; Not sure if viznut's waveforms applies to the noise voice,
  beq pc_3      ; but keep it in away.

  ; Ignore all other channels  
  rts

; Update the screen with Program# (viznut waveform code)
; Note that these are not actually used until setvoice is called below [1]

pc_0:
  HEXPOKE (voice_display+ 5),waveform1 
  rts

pc_1:
  HEXPOKE (voice_display+27),waveform2
  rts
  
pc_2:
  HEXPOKE (voice_display+49),waveform3
  rts
  
pc_3:
  HEXPOKE (voice_display+71),waveform4
  rts
  
  
;---------------------------------------------------------
; Set a voice using viznut's setwave function.
; If a sound is already playing, fine.  But if not, need a "short" delay.  TODO ***

viznut:
  ldy channel       ; Channel # (0-3)   
  lda voice_to_register,y
  sta setwavechannel
  
  lda currentvalue        ; X now contains initial frequency of selected channel
  sta setwavefrequency
  
  ldy channel
  lda waveform1,y         ; Retrieve the last desired waveform# for this channel
  tax
  lda viznutwaveforms,x   ; Retrieve the desired shift register contents for that waveform#  
  sta setwaveshiftreg  

  ; Set X,Y,A as required and set the waveform.
  ldy setwavechannel
  ldx setwavefrequency   
  lda setwaveshiftreg
  jsr setwave
  
  ; TODO, update the screen
  rts    


;***************************************************************************
;*******************  Set/Display Functions  *******************************
;***************************************************************************  

; Dispatcher for setting the appropriate voice and updating the screen
; Channel# in Y (Channel 0 = Voice 1, etc) 
; Value to set it to in A.

setvoice:
   sta currentvalue 
  
  ; Before setting the voice, check if a viznut waveform was selected previously [1]
  ; If so, handle that separately. 
  ;lda waveform1,y
  ;bne viznut

  ; Nope, carry on.
  lda currentvalue
  ldy channel   ; Y now contains channel #
  
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
; Draw Main Screen

mainscreen:
  jsr CLRSCREEN
  lda #26     ; Decimal, white and red
  sta screen_colors  
  lda #$06   ; Blue
  sta $0286  ; Cursor Color
  PRINTSTRING maintext  
  lda #$7F  ; was#$6C         
  sta spin_display
  rts


; ----------------------------------------------------------------------------  
; Draw Credits Screen

creditscreen:     
  jsr CLRSCREEN
  lda #30     ; Decimal, white and blue
  sta screen_colors  
  lda #$02   ; Red
  sta $0286  ; Cursor Color  
  PRINTSTRING credits
  rts


; ---------------------------------------------------------------------------- 
; setwave needs to start on a page and is self-modifying, 
; so it is copied to RAM here
  
setwavecopy:  
  ldx #$00
copy1:
  lda setwaveorg,x
  sta setwave,x
  inx
  bne copy1
  rts
  
  
; ---------------------------------------------------------------------------- 
; Set up the font 
; 
  
setupfont:  
  ldx #$00
copy2:
  lda fontorg,x
  sta font,x
  lda fontorg+$100,x
  sta font+$100,x
  lda fontorg+$200,x
  sta font+$200,x
  lda fontorg+$300,x
  sta font+$300,x
  inx
  bne copy2
  
  lda #254  ; Decimal  Points char. to 6144
  sta $9005
   
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
  byte "sYSTEM : ???", CRLF 
  byte 0


credits:
  byte CG_LCS, CG_DCS 
  byte " *vic20 midi cREDITS*", CRLF
  byte CRLF
  byte "hARDWARE:", CRLF
  byte CRLF             
  byte "  jIM bRAIN", CRLF
  byte "  fRANCOIS lEVEILLE", CRLF
  byte "  ld bALL", CRLF
  byte CRLF
  byte "sOFTWARE:", CRLF
  byte CRLF             
  byte " lEIF bLOOMQUIST", CRLF
  byte " dAVID vIENS", CRLF
  byte " mICHAEL kIRCHER", CRLF
  byte " vIZNUT", CRLF
  byte CRLF
  byte "tHANKS TO EVERYONE", CRLF
  byte "ON THE vic20 dENIAL", CRLF
  byte "FORUMS!", CRLF
  byte 0 

palstring:
  .byte "pal ",0
  
ntscstring:
  .byte "ntsc",0

altstring:
  .byte "alt ",0
  
; ----------------------------------------------------------------------------  
; Lookup table between voice #(0-3) and low byte of register# ($0A-$0D)

voice_to_register:
  byte $0A,$0B,$0C,$0D


; ----------------------------------------------------------------------------  
; Code includes  

  include "hardware.asm"   
  include "utils.asm"
  include "polymode.asm"
  include "keyboard.asm"     
setwaveorg:
  include "setwave.asm"   

  include "lookup-ntsc.asm"
  include "lookup-pal.asm"
  include "lookup-alt.asm"

; ----------------------------------------------------------------------------  
; Binary includes

fontorg:
   incbin "font.bin"  

; EOF!