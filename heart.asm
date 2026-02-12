.model tiny
.code
org 100h

Start: 	mov ax, 0B800h
		mov es, ax
		xor bx, bx
		mov word ptr es:[bx + 160 * 2 + 80], 0bc03h
		; mov byte ptr es:[bx + 1], (4eh or 80h)

		mov ax, 4c00h
		int 21h 


end 			Start


