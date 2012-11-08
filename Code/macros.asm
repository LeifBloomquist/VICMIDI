
; ==============================================================
; Macro wrapping the fast hex poke
; ==============================================================

  MAC HEXPOKE
  lda #<{1}  ; Low byte
  sta $22
  lda #>{1}  ; High byte
  sta $23
  
  lda {2}   ; Note - address
  jsr hexstr  
  ENDM

; ==============================================================
; Macro to position the cursor
; ==============================================================

  MAC PLOT
  ldy #{1}
  ldx #{2}
  clc
  jsr $E50A  ; PLOT - same on 64 and VIC
  ENDM

; ==============================================================
; Macro to print a string
; ==============================================================

  MAC PRINTSTRING
  ldy #>{0}
  lda #<{0}
  jsr STROUT
  ENDM

; ==============================================================
; Macro to print a byte (Hex)
; ==============================================================

	MAC PRINTBYTE
  ldx #$00
  ldy #$0F
  lda {0}
  jsr printnum
  ENDM
