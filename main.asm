; This program displays a text message in frame on screen by changing bytes in
; video memory. Frame is centered in the middle of screen, text is defined as
; command line argument.
;
; TODO: define frame style, multiple lines, if line is too long split it
;
; by LMD
;----------------------File Contents Start After This Line----------------------

.model tiny
.code
org 100h

locals @@

color_attr = 70h			; black text on white bg
frame_sym  = 2ah			; symbol of a frame
max_width  = 76				; max text width


LoadES		macro
		mov ax, 0b800h
		mov es, ax
		endm
	
NewL		macro
		add FrameOffset, 160
		mov di, FrameOffset
		endm


Start:
		LoadES
		call ClearScreen

		call GetTextWidth
		mov TextWidth, ax	
		mov TotalSymbols, bx 
		mov TotalLines, cx

		cmp bx, 0
		jz EndProg

		call CalcFrameOffset
		mov FrameOffset, ax
		
		call DrawFrame







EndProg:
		mov ax, 0100h		; waits for any key to be pressed
		int 21h

		mov ax, 4c00h		; quits the program
		int 21h

FrameOffset	dw 0			; frame beginning pos
TextWidth	dw 0			; number of symbols in text
TotalSymbols	dw 0			; number of symbols in text
TotalLines	dw 0			; number of lines in the text
;===============================================================================
; ClearScreen
; 
; Dumps empty chars in video memory page
; Entry:     ES -> video mem segment
; Exit:      -
; Expected:  -
; Destroyed: AX, CX, DI (all regs saved)
;-------------------------------------------------------------------------------

ClearScreen	proc

		push ax			; saves all used registers
		push cx
		push di

		xor di, di		; of video memory
		mov ax, 0		; blank symbol on black bg
		mov cx, 80 * 25		; symbols in video page
		rep stosw 

		pop di			; restores used registers values
		pop cx
		pop ax

		ret
		endp

;===============================================================================
; GetTextWidth
;
; Reads number of symbols in text from cs:80h, calculates width and line amount 
; Entry:     CS -> code segment
; Exit:      AX <- text width
;	     BX <- number of symbols
;	     CX <- number of lines
; Expected:  -
; Destroyed: AX, BX, CX
;-------------------------------------------------------------------------------

GetTextWidth	proc

		xor ax, ax
		xor bx, bx
		mov bl, 80h		; len is located at 80h
		mov bl, cs:[bx]		; bx = number of symbols

		cmp bx, 0		; if no text given
		jnz @@ParseLines
		xor ax, ax
		xor bx, bx
		xor cx, cx
		ret

@@ParseLines:
		dec bx			; skip leading space
		mov ax, bx
		mov cx, max_width	; assumed that max_width < 128
		div cl
		mov cl, al 		; cx = num of sym div max_width

		cmp ah, 0	
		jz @@Rounded		
		add cx, 1		; if ah != 0 cx += 1

@@Rounded:
		cmp al, 0
		jnz @@Allign
		mov al, ah
		xor ah, ah 
		jmp @@Ret

@@Allign:	mov ax, max_width

@@Ret:		ret
		endp

;===============================================================================
; CalcFrameOffset
;
; Calculates line offset for frame beginning and puts value in ax
; Entry:     -
; Exit:      AX <- frame offset
; Expected:  -
; Destroyed: AX, BX, DX
;-------------------------------------------------------------------------------

CalcFrameOffset	proc

		mov bx, TextWidth
		and bx, 0feh		; 1111 1110 mask to make odd number even

		mov dx, TotalLines
		shr dx, 1		; dx = dx div 2
		neg dx
		add dx, 11		; dx = 12 - dx
		mov ax, dx
		mov dx, 160		; dx - bytes in line
		mul dx			; whole value should be stored in ax		
		add ax, 40 * 2		; 80 - mid offset (40 words)
		sub ax, bx
		sub ax, 2 * 2		; -2 words for boarder and space

		ret
		endp

;===============================================================================
; DrawFrame
;
; Draws in video memory frame with given text 
; Entry:     ES -> video mem segment
;	     CS -> code segment
; Exit:      -
; Expected:  -
; Destroyed: AX, BX, CX, DI, SI
;-------------------------------------------------------------------------------

DrawFrame	proc

		call DrawHBorder
		;call DrawEmptyLine

		mov ah, color_attr
		mov cx, TotalLines

@@Center:
		mov al, frame_sym
		stosw			; draws part of left vert border
		mov al, 00h
		stosw			; draws blank space

		push cx
		mov cx, TextWidth
		cmp cx, max_width	; if cx <= max_width
		jbe @@CallFunc

		mov bx, TextWidth
		sub bx, max_width
		mov TextWidth, bx	; TextWidth -= max_width

		mov cx, max_width

@@CallFunc:	call DisplayStr		
		pop cx

		mov al, 00h
		stosw			; draws blank space
		mov al, frame_sym
		stosw			; draws part of right vert border
		NewL

		loop @@Center

		; call DrawEmptyLine
		call DrawHBorder

		ret
		endp

;===============================================================================
; DrawHBorder
;
; Draws horizontal border in video mem
; Entry:     ES -> video mem segment
;	     CS -> code segment
; Exit:      -
; Expected:  -
; Destroyed: AX, CX, DI
;-------------------------------------------------------------------------------

DrawHBorder	proc
		
		mov cx, TextWidth 
		add cx, 4
		mov di, FrameOffset
		mov al, frame_sym
		mov ah, color_attr

		rep stosw		; draws upper hor border

		NewL

		ret
		endp

;===============================================================================
; DrawEmptyLine
;
; Draws empty line in frame
; Entry:     ES -> video mem segment
;	     DI -> line offset for frame border
;	     AL -> frame symbol
;	     CS -> code segment
; Exit:      -
; Expected:  -
; Destroyed: AX, CX
;-------------------------------------------------------------------------------

DrawEmptyLine	proc

		stosw			; draws part of left vert border
		mov al, 00h
		mov cx, TextWidth
		add cx, 2
		rep stosw		; fills with blank spaces
		mov al, frame_sym
		stosw			; draws part of right vert border

		NewL

		ret
		endp

;===============================================================================
; DisplayStr
;
; Displays command line argumnet in video mem 
; Entry:     ES -> video mem segment
;	     CS -> code segment
;	     DI -> line offset for text 
;	     CX -> number of symbols
; Exit:      -
; Expected:  -
; Destroyed: AX, CX, DI, SI
;-------------------------------------------------------------------------------

DisplayStr	proc

		push ds			; saves DS
		push cs
		pop ds			; ds = cs

		mov si, 82h		; si = string beginning after space
		;mov cx, TextWidth

@@MoveStr:
		lodsb			; puts char in al
		mov ah, color_attr
		stosw			; puts char in video mem
		loop @@MoveStr

		pop ds
		ret
		endp



end 		Start
