; This program displays a text message in frame on screen by changing bytes in
; video memory. Frame is centered in the middle of screen, text is defined as
; command line argument.
;
; TODO: define frame style, multiple lines
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
style_arg_len = 6			; bytes in frame style info 
arg_len_pos = 80h			; location of arg len in cs
arg_text_start = 82h			; location of  arg text in cs


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

		call GetArgLen
		cmp ax, style_arg_len + 3
		jb EndProg
		dec ax			; remove first space

		mov TotalSymbols, ax
		mov CurPos, arg_text_start

		lea bx, [FrameStyle]
		call ParseFrameStyle

		call GetTextWidth
		mov TextWidth, ax	
		mov TotalSymbols, bx 
		mov TotalLines, cx

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
CurPos		dw 0			; cur pos in cs
FrameStyle	db 6 dup (0)		; frame style arr 

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
; GetArgLen
;
; Gets arg text len in cs
; Entry:     CS -> code segment
; Exit:      AX <- total symbols
; Expected:  -
; Destroyed: AX, BX
;-------------------------------------------------------------------------------

GetArgLen 	proc

		xor ax, ax
		xor bx, bx
		mov bl, arg_len_pos	; len is located at 80h
		mov bl, cs:[bx]		; bx = number of symbols
		mov al, bl

		ret
		endp 

;===============================================================================
; ParseFrameStyle
;
; Gets frame style info (6 bytes)
; 0: horizontal border
; 1: vertical border
; 2: top left corner
; 3: top right corner
; 4: bottom left corner
; 5: bottom right corner 
; Entry:     CS -> code segment
;	     BX -> style arr address 
; Exit:      -
; Expected:  -
; Destroyed: AX, BX, CX, SI, 
;-------------------------------------------------------------------------------

ParseFrameStyle	proc

		mov cx, style_arg_len

		push ds			; save ds
		push es			; save es

		push ds
		pop es			; es = ds
		push cs
		pop ds			; ds = cs

		mov si, CurPos

@@NextArg:				; load style arg in array 
		lodsb
		mov byte ptr es:[bx], al
		inc bx
		loop @@NextArg

		pop es			; restore es
		pop ds			; restore cs

		mov bx, TotalSymbols
		sub bx, style_arg_len
		;dec bx
		mov TotalSymbols, bx	; TotalSymbols -= style_arg_len

		mov bx, CurPos
		add bx, style_arg_len + 1
		mov CurPos, bx		; CurPos += style_arg_len + 1

		ret
		endp

;===============================================================================
; GetTextWidth (UPDATE)
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

		mov bx, TotalSymbols

		cmp bx, 0		; if no text given
		jnz @@ParseLines

@@NoData:	xor ax, ax
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
; CalcFrameOffset (UPDATE)
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

		mov bx, 2
		call DrawHBorder
		;call DrawEmptyLine

		mov ah, color_attr
		mov cx, TotalLines
		mov si, CurPos		; si = string beginning after space

@@Center:
		mov al, [FrameStyle + 1]
		stosw			; draws part of left vert border
		mov al, 00h
		stosw			; draws blank space

		push cx
		mov cx, TotalSymbols
		cmp cx, max_width	; if cx <= max_width
		jbe @@CallFunc

		mov bx, TotalSymbols
		sub bx, max_width
		mov TotalSymbols, bx	; TotalSymbols -= max_width

		mov cx, max_width

@@CallFunc:	call DisplayStr		
		pop cx

		mov al, 00h
		stosw			; draws blank space
		mov al, [FrameStyle + 1]
		stosw			; draws part of right vert border
		NewL

		loop @@Center

		; call DrawEmptyLine
		mov bx, 4
		call DrawHBorder

		ret
		endp

;===============================================================================
; DrawHBorder
;
; Draws horizontal top border in video mem
; Entry:     ES -> video mem segment
;	     CS -> code segment
;	     BX -> 2 - top border, 4 - bottom border
; Exit:      -
; Expected:  -
; Destroyed: AX, BX, CX, DI
;-------------------------------------------------------------------------------

DrawHBorder	proc
		
		mov ah, color_attr

		mov di, FrameOffset
		mov al, [FrameStyle + bx]
		stosw

		mov cx, TextWidth 
		add cx, 2
		mov al, [FrameStyle]

		rep stosw		; draws mid part of upper hor border

		mov al, [FrameStyle + bx + 1]	
		stosw

		NewL

		ret
		endp

;===============================================================================
; DrawEmptyLine (not used)
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
; Displays command line argument in video mem 
; Entry:     ES -> video mem segment
;	     CS -> code segment
;	     DI -> line offset for text 
;	     CX -> number of symbols
;	     SI -> text beginning in cs
; Exit:      -
; Expected:  -
; Destroyed: AX, CX, DI, SI, DX
;-------------------------------------------------------------------------------

DisplayStr	proc

		xor dx, dx

		push ds			; saves DS
		push cs
		pop ds			; ds = cs

		cmp cx, TextWidth	; check if extra spaces required
		jae @@MoveStr
		mov dx, TextWidth
		sub dx, cx
		
		mov ah, color_attr

@@MoveStr:
		lodsb			; puts char in al
		stosw			; puts char in video mem
		loop @@MoveStr

		pop ds

		cmp dx, 0
		jz @@EndFunc
		mov cx, dx
		
		call FillWithSpaces

@@EndFunc:	ret
		endp

;===============================================================================
; FillWithSpaces
;
; Adds spaces after ES:DI CX times 
; Entry:     ES -> video mem segment
;	     CX -> number of spaces to fill
;	     DI -> start position for filling
; Exit:      -
; Expected:  -
; Destroyed: AX
;-------------------------------------------------------------------------------

FillWithSpaces	proc

		mov ah, color_attr
		xor al, al		; al - blank symbol 

@@FillSpaces:
		stosw
		loop @@FillSpaces

		ret
		endp

end 		Start
