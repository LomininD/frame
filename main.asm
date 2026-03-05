; This program displays a text message in frame on screen by changing bytes in
; video memory. Frame is centered in the middle of screen, text is defined as
; command line argument.
;
; TODO: multiple lines
;
; by LMD
;----------------------File Contents Start After This Line----------------------

.model tiny
.code
org 100h

locals @@

frame_sym  = 2ah			; symbol of a frame
max_width  = 76				; max text width

arg_len_pos = 80h			; location of arg len in cs
arg_text_start = 82h			; location of arg text in cs
					; first space skipped


LoadES		macro
		mov ax, 0b800h
		mov es, ax
		endm

NewL		macro
		add FrameOffset, 160
		mov di, FrameOffset
		endm

CalcSArgLen	macro
		mov ax, StyleArgNum
		mov cx, 3
		mul cx
		sub ax, 2
		mov StyleArgLen, ax
		endm


Start:
		CalcSArgLen

		LoadES
		call ClearScreen

		call GetArgLen
		mov bx, StyleArgLen
		add bx, 3
		cmp ax, bx		; 1 + args + 1 + 1 
		jb EndProg
		dec ax			; remove first space

		mov TotalSymbols, ax
		mov CurPos, arg_text_start

		lea bx, [FrameStyle]
		call ParseFrameStyle

		call GetTextWidth
		mov TextWidth, ax
		mov TotalLines, cx

		call CalcFrameOffset
		mov FrameOffset, ax

		call DrawFrame

EndProg:
		mov ax, 0100h		; waits for any key to be pressed
		int 21h

		mov ax, 4c00h		; quits the program
		int 21h

StyleArgNum 	dw 2			; number of style args
StyleArgLen 	dw 0			; bytes in frame style info
FrameOffset	dw 0			; frame beginning pos
TextWidth	dw 0			; number of symbols in text
TotalSymbols	dw 0			; number of symbols in text
TotalLines	dw 0			; number of lines in the text
CurPos		dw 0			; cur pos in cs
FrameStyle	db 6 dup (0)		; frame style arr
Color_Attr	db 0			; color of frame

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
; Gets frame style info (8 hex numbers)
; 0: frame color attr
; 1: Frame style (0 - custom, 1 - simple, 2 - double)
; If custom frame style:
; 2: horizontal border
; 3: vertical border
; 4: top left corner
; 5: top right corner
; 6: bottom left corner
; 7: bottom right corner
; Entry:     CS -> code segment
;	     BX -> style arr address
; Exit:      -
; Expected:  -
; Destroyed: AX, BX, CX, SI, DL
;-------------------------------------------------------------------------------

ParseFrameStyle	proc

		push ds			; save ds
		push es			; save es

		push ds
		pop es			; es = ds
		push cs
		pop ds			; ds = cs

		mov si, CurPos

		lodsw			; reads color attr
		call AtoIW
		mov Color_Attr, al
		inc si

		lodsb 			; read preset style
		call AtoIB
		inc si
		cmp al, 0		; checks if style is preset or custom
		jz @@CustomFrame

		call SetPresetStyle
		jmp @@Ret

@@CustomFrame:
		mov StyleArgNum, 8
		CalcSArgLen
		mov cx, StyleArgNum
		sub cx, 2
		
@@NextArg:				; load style arg in array
		lodsw

		call AtoIW

		mov byte ptr es:[bx], al
		inc bx
		inc si
		loop @@NextArg

@@Ret:
		pop es			; restore es
		pop ds			; restore cs

		mov bx, TotalSymbols
		sub bx, StyleArgLen
		dec bx
		mov TotalSymbols, bx	; TotalSymbols -= style_arg_len + 1

		mov bx, CurPos
		add bx, StyleArgLen
		inc bx
		mov CurPos, bx		; CurPos += style_arg_len + 1

		ret
		endp

;===============================================================================
; SetPresetStyle
;
; Sets style attrs in according to defined preset style
; 1 - simple frame
; 2 - double frame
; 3 - ...
; Entry:     AL -> number of preset style 
; Exit:      -
; Expected:  -
; Destroyed: -
;-------------------------------------------------------------------------------

SetPresetStyle	proc

		cmp al, 1
		je @@SimpleFrame
		cmp al, 2
		je @@DoubleFrame
		cmp al, 3
		je @@DontUseThisFrame

@@SimpleFrame:	
		mov [FrameStyle], 0c4h		; horizontal border
		mov [FrameStyle + 1], 0b3h	; vertical border
		mov [FrameStyle + 2], 0dah	; top left corner
		mov [FrameStyle + 3], 0bfh	; top right corner
		mov [FrameStyle + 4], 0c0h	; bottom left corner
		mov [FrameStyle + 5], 0d9h	; bottom right corner
		jmp @@Ret

@@DoubleFrame:
		mov [FrameStyle], 0cdh		; horizontal border
		mov [FrameStyle + 1], 0bah	; vertical border
		mov [FrameStyle + 2], 0c9h	; top left corner
		mov [FrameStyle + 3], 0bbh	; top right corner
		mov [FrameStyle + 4], 0c8h	; bottom left corner
		mov [FrameStyle + 5], 0bch	; bottom right corner
		jmp @@Ret

@@DontUseThisFrame:
		mov [FrameStyle], 0bh		; horizontal border
		mov [FrameStyle + 1], 0bh	; vertical border
		mov [FrameStyle + 2], 6h	; top left corner
		mov [FrameStyle + 3], 6h	; top right corner
		mov [FrameStyle + 4], 6h	; bottom left corner
		mov [FrameStyle + 5], 6h	; bottom right corner


@@Ret:		ret
		endp

;===============================================================================
; AtoIB
;
; Converts byte string A to hex number A 
; Entry:     AL -> number as string 
; Exit:      AL <- number as hex 
; Expected:  -
; Destroyed: -
;-------------------------------------------------------------------------------

AtoIB		proc

		cmp al, 'a'
		jb @@ConvertDigital
		jmp @@ConvertAlpha

@@ConvertDigital:
		sub al, '0'
		jmp @@Ret

@@ConvertAlpha:
		sub al, 'a'
		add al, 0ah

@@Ret:		ret
		endp
		
;===============================================================================
; AtoIW
;
; Converts word string A to hex number A 
; Entry:     AX -> number as string 
; Exit:      AL <- number as hex 
; Expected:  -
; Destroyed: DL
;-------------------------------------------------------------------------------

AtoIW		proc

		call AtoIB		; converts AL to hex number
		mov dl, al
		shl dl, 4
		mov al, ah
		call AtoIB		; converts AH to hex number
		add dl, al
		mov al, dl

		ret
		endp

;===============================================================================
; GetTextWidth !!!
;
; Reads number of symbols in text from cs:80h, calculates width and line amount
; Entry:     CS -> code segment
; Exit:      AX <- text width
;	     CX <- number of lines
; Expected:  -
; Destroyed: AX, CX
;-------------------------------------------------------------------------------

GetTextWidth	proc

		mov ax, TotalSymbols
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
; CalcFrameOffset !!!
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
		add dx, 11		; dx = 11 - dx
		mov ax, dx
		mov dx, 160		; dx - bytes in line
		mul dx			; whole value should be stored in ax
		add ax, 40 * 2		; 80 - mid offset (40 words)
		sub ax, bx
		sub ax, 2 * 2		; -2 words for border and space

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

		mov bx, 0		; bx = 0 for top border 
		call DrawHBorder

		mov ah, Color_Attr
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

		mov bx, 1		; bx = 1 for bottom border 
		call DrawHBorder

		ret
		endp

;===============================================================================
; DrawHBorder
;
; Draws horizontal border in video mem
; Entry:     ES -> video mem segment
;	     CS -> code segment
;	     BX -> 0 - top border, 1 - bottom border
; Exit:      -
; Expected:  -
; Destroyed: AX, BX, CX, DI
;-------------------------------------------------------------------------------

DrawHBorder	proc

		shl bx, 1		; modificates bx=0 -> bx=2  
		add bx, 2		; 	      bx=1 -> bx=4

		mov ah, Color_Attr

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

		mov ah, Color_Attr

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

		mov ah, Color_Attr
		xor al, al		; al - blank symbol

@@FillSpaces:
		stosw
		loop @@FillSpaces

		ret
		endp

end 		Start
