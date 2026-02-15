.model tiny
.code
org 100h

Start:

		mov bx, 0
		mov ax, 0b800h
		mov es, ax
		mov word ptr es[bx], 0000h

		mov ax, 0100h
		int 21h

		mov ax, 4c00h
		int 21h 


end 			Start
