.model tiny
.code
org 100h

LoadES		macro
		mov ax, 0b800h
		mov es, ax
		endm

locals @@

Start:
		call Main
		call Exit

;-------------------------------------------------------------------------------

Main 		proc
		mov di, offset MeowStr
		mov al, 's'
		call StrChr

		ret
		endp

StrChr		proc
		xor cx, cx
		dec cx

		cld
		repne scasb

		neg cx
		dec cx

		ret
		endp


