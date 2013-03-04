; --------------------------------------------------------------------------------------------------	
;;free zero page (to use as vars)
;INDEX1: $0022-$0023, First utility pointer                   used by HEXPOKE
;INDEX2: $0024-$0025, Second utility pointer                  bytesexpected, midicounter
;FORNAM: $0049-$004A, Pointer to FOR/NEXT index variable etc  channel
;TEMPF3: $004E-$0052, Temporary FLPT storage                  Used by keyboard routines
;TEMPF1: $0057-$005B, Temporary FLPT storage                  Used by setwave
;TEMPF2: $005C-$0060: Temporary FLPT storage                  FIFO pointers
;FAC:    $0061-$0066, Floating-point Accumulator (FAC)        Flags for Poly mode
;AFAC:   $0069-$006E, Alternative/Auxilary FAC                69=last note

; ---- Zero Page Addresses -------------------------------------------------

midicounter   = $24
bytesexpected = $25

channel       = $49
bank          = $4A   ; 0=NTSC Normal, 1=PAL Normal, 2=NTSC Alt., 3=PAL Alt.

; Previous keyboard column bits.
c0 = $4E  ; 2,4,6,8,(...)
c1 = $4F  ; q,e,t,u,(...)
c2 = $50  ; w,r,y,i,p,(...)
c3 = $51  ; 1,3,5,7,(...)

; Used by setwave
TMP  = $57
TMP2 = $58 

write_pointer = $5C   ; FIFO current write pointer - incremented on byte received
read_pointer  = $5D   ; FIFO current read pointer - incremented on byte removed

currentvalue  = $5E   ; Current value for voice settings

poly_flags    = $61   ; Flags for polymode
                      ; Also 62,63,64

lastnote      = $69   ; Remembers last note, so Note Off applies to that note only
                      ; Also 69,6A,6B             

temp1         = $6C   ; Used for screen colors
tempx         = $6D   ; Used by program change
                  
;*00FB-00FE  251-254  Operating system free zero page space
statusbyte    = $FB
mididata0     = $FC
mididata1     = $FD
mididata2     = $FE     ; If needed

; ---- Non Zero Page Addresses -----------------------------------------------	

; Setwave Target
setwave            = $1000  ; This is right at the start of BASIC space.  Setwave code has to all be on one page.

; Store viznut waveform being used per voice 
waveform1          = $1100
waveform2          = $1101
waveform3          = $1102
waveform4          = $1103 

; Input Buffer
buffer             = $1200

; ST16C450 Registers
UART_RXTX          = $9C00
UART_IER           = $9C01
UART_ISR           = $9C02
UART_LCR           = $9C03
UART_LSR           = $9C05
UART_SCRATCHPAD    = $9C07
UART_DIVISOR_LSB   = $9C00  ; Yes, same as UART_RXTX
UART_DIVISOR_MSB   = $9C01

;Sound and Video Registers
sound_voice1       = $900A  ; Frequency for oscillator 1 (low)    (on: 128-255) 
sound_voice2       = $900B  ; Frequency for oscillator 2 (medium) (on: 128-255) 
sound_voice3       = $900C  ; Frequency for oscillator 3 (high)   (on: 128-255) 
sound_noise        = $900D  ; Frequency of noise source           (on: 128-255) 
sound_volume       = $900E  ; Bits 0-3 sets volume of all sound.  Bits 4-7 are auxiliary color information (not used)
screen_colors      = $900F 

;Screen locations
screen_start       = $1E00
midi_display       = $1E4D
voice_display      = $1E77
spin_display       = $1FF9  ; Lower-right corner
spin_color         = spin_display + $7800


; Kernal/BASIC Routines
CHROUT      = $f27a
CLRSCREEN   = $e55f
HOME        = $E581
STROUT      = $CB1E   ; Print string pointed to by (A/Y) until zero byte.

CG_DCS = 8   ;disable shift+C=
CG_ECS = 9   ;enable shift+C=

CG_LCS = 14  ;switch to lowercase
CG_UCS = 142 ;switch to uppercase

;cursor movement
CS_HOM = 19
CS_U   = 145
CS_D   = 17
CS_L   = 157
CS_R   = 29

CRLF   = 13

; EOF!