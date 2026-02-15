; This program clears screen by replacing all symbols in video page by blank symbols
;----------------File Contents Start After This Line----------------

.model tiny
.code
org 100h

Start:

		mov bx, 0
		mov ax, 0b800h
		mov es, ax						; es = 0b800h

		mov cx, 80 * 25					; repeat 80 * 25 times (whole video page)

LineClear:
		mov word ptr es:[bx], 0000h		; replaces current symbol with blank symbol
		inc bx
		inc bx
		loop LineClear

		mov ax, 0100h					; wait for any key to be pressed
		int 21h	

		mov ax, 4c00h					; quits the program
		int 21h 


end 			Start
