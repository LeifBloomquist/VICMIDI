; VIC Version by Schema/AIC (Leif Bloomquist)
; Original by Six/Style (Oliver VieBrooks)

; Fast POKE of hex value to screen
; also see HEXPOKE macro
; print hex  char $ of number in a at location referenced by screen_temp

hexstr
  ldy #$00
	pha
	and #$f0
	clc
	lsr
	lsr
	lsr
	lsr
	tax
	lda hexstring,x
	sta ($22),y

  iny
	pla
	and #$0f
	tax
	lda hexstring,x  	
	sta ($22),y
	rts


; print hex  char $ of number in a    SLOW!
hexx	dc.b $00

printhexstr:
	stx hexx
	pha
	and #$f0
	clc
	lsr
	lsr
	lsr
	lsr
	tax
	lda hexstring,x
	jsr $ffd2

	pla
	and #$0f
	tax
	lda hexstring,x
	jsr $ffd2
	ldx hexx
	rts

hexstring
	.byte "0123456789ABCDEF"


; ==============================================================
; Most defaults are NTSC.  This code overrides for PAL.
; ==============================================================

setup_pal:
  ;PLOT 13,9
  
  lda $EDE4
  cmp #$0C
  beq DOPAL 
  
  ; NTSC System detected
  ;PRINTSTRING "ntsc"
  lda #$00
  sta bank
  rts
  
  ; PAL System detected, make changes
DOPAL        
  ;PRINTSTRING "pal"
  lda #$01 
  sta bank  
  rts