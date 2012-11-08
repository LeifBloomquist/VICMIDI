; VIC Version by Schema/AIC (Leif Bloomquist)
; Original by Six/Style (Oliver VieBrooks)

; Kernal/BASIC Routines
CHROUT      = $f27a
CLRSCREEN   = $e55f
HOME        = $E581
STROUT      = $CB1E   ; Print string pointed to by (A/Y) until zero byte.

CG_DCS = 8  ;disable shift+C=
CG_ECS = 9  ;enable shift+C=

CG_LCS = 14 ;switch to lowercase
CG_UCS = 142 ;switch to uppercase

;cursor movement
CS_HOM = 19
CS_U   = 145
CS_D   = 17
CS_L   = 157
CS_R   = 29

CRLF   = 13

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
; All defaults are NTSC.  This code overrides for PAL.
; ==============================================================

setup_pal:
  ;PLOT 13,9
  
  lda $EDE4
  cmp #$0C
  beq DOPAL 
  
  ; NTSC System detected, don't change anything
  ;PRINTSTRING "ntsc"
  rts
  
  ; PAL System detected, make changes
DOPAL
  
  ;PRINTSTRING "pal"
  ; TODO, set default bank
  
  rts