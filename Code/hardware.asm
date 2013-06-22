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
  PRINTSTRING nouart

uloop:
  lda #24
  sta screen_colors
  lda #26
  sta screen_colors
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
  ; 16, so with a 2MHz crystal on board, that gives
  ; 2000000 * (1/16) * (1/x) = 31250.  Solving gives x=4 for the low
  ; byte of the divisor, and 0 for the high byte.  
      
  ldx #$00 
  ldy #$04  ; For 2MHz crystal   (Original protype from Francois) 
  ;ldy #$08  ; For 4MHz crystal 
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
; Handle the RESTORE key  

RESTORE:
  jmp $fec7   ; Continue as if no cartridge installed
  

; ---------------------------------------------------------------------------- 
; Strings
  
nouart:
   byte 127,127, " uart NOT FOUND! ", 127,127
   byte 0
  
; EOF!