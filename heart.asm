.model tiny
.code
org 100h

Start: 			mov ax, B800
				mov es, ax
				xor bx, bx
				mov word ptr es:[bx], 4e03h

				mov ax, 4c00h
				int 21h 

end 			Start


