; This program displays heart on screen, and waits for user to press any key
;----------------File Contents Start After This Line----------------

.model tiny
.code
org 100h

Start: 	

POS		= 160 * 2 + 80
		mov ax, 0B800h
		mov es, ax
		xor bx, bx
		mov word ptr es:[bx + POS], 0403h

		mov ax, 0100h
		int 21h

		mov ax, 4c00h
		int 21h 


end 			Start


