
;***************************************************************************
;***************  Determine next Channel in Poly Mode (set Y) **************
;***************************************************************************
get_poly_voice:
  ldy #$00

get_poly_voice_loop:
  lda poly_flags,y                          ; 0=not in use, 1=in use
  beq get_poly_voice_x
  iny
  cpy #$04    ; Note that we're only checking the first 3 voices - n/a to noise voice.
  bne get_poly_voice_loop
  
  ; No free voices, ignore
  ldy #$04  ; Invalid channel, will be ignored by Note On code
  rts
  
get_poly_voice_x:
  lda #$01
  sta poly_flags,y
  rts
	

;***************************************************************************
;********  Determine Channel to turn off in Poly Mode (set Y) **************
;***************************************************************************
get_poly_voice_off:
  
  ldy #$00
  
get_poly_voice_off_loop:
  lda poly_flags,y         ; Is the channel in use?
  beq poly_next            ; No, so skip it

  lda lastnote,y           ; Get last note on this voice
  cmp mididata0            ; Compare to note received
  beq get_poly_voice_off_x ; Matched!
  
poly_next:
  iny          ; Next channel
  cpy #$04     ; Note that we're only checking the first 3 voices - n/a to noise voice.
  bne get_poly_voice_off_loop
  
  ; No match to the note to turn off, ignore
  ldy #$04          ; Invalid channel, will be ignored by Note Off code
  inc screen_colors ; DEBUG
  rts
  
get_poly_voice_off_x:
  lda #$00
  sta poly_flags,y  
  rts
	